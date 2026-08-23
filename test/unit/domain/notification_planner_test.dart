import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/reminders.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item(
    String id,
    Category category, {
    required String expiresOn,
    String? name,
    int actByOffsetDays = 0,
    List<int>? leadDays,
    NagPolicy? nag,
    int? verifyEveryDays,
    String? lastVerifiedAt,
    ItemState state = ItemState.active,
  }) {
    return TrackedItem(
      id: id,
      name: name ?? id,
      category: category,
      expiresOn: d(expiresOn),
      actByOffsetDays: actByOffsetDays,
      anchorDate: d(expiresOn),
      leadDays: leadDays ?? Reminders.defaultLeadDays(category),
      nagAfterDue: nag ?? Reminders.defaultNagPolicy(category),
      // Explicit so an unspecified verify interval means "none", not the
      // per-category default. Verify alerts are exercised in their own tests.
      verifyEveryDays: verifyEveryDays,
      verifyEveryDaysIsExplicit: true,
      lastVerifiedAt: lastVerifiedAt == null ? null : d(lastVerifiedAt),
      state: state,
    );
  }

  test('lead alerts land the right number of days before the act-by date', () {
    final plan = NotificationPlanner.plan([
      item(
        't',
        Category.subscription,
        expiresOn: '2026-08-20',
        leadDays: [3, 1, 0],
        nag: NagPolicy.none,
      ),
    ], today);

    final leads =
        plan.alerts
            .where((a) => a.reason == AlertReason.lead)
            .map((a) => a.date)
            .toList()
          ..sort();

    expect(leads, [d('2026-08-17'), d('2026-08-19'), d('2026-08-20')]);
  });

  // The act-by offset is what makes an item actionable rather than
  // merely alarming: you must cancel before the charge, not on the day of it.
  test('lead alerts anchor on act-by, not on expiry', () {
    final plan = NotificationPlanner.plan([
      item(
        'sim',
        Category.subscription,
        expiresOn: '2026-09-14',
        actByOffsetDays: 7,
        leadDays: [0],
        nag: NagPolicy.none,
      ),
    ], today);
    // act-by is 7 days before 14 Sep.
    expect(plan.alerts.map((a) => a.date), [d('2026-09-07')]);
  });

  test('alerts in the past are not scheduled', () {
    final plan = NotificationPlanner.plan([
      item(
        'old',
        Category.subscription,
        expiresOn: '2026-08-16',
        leadDays: [30, 1],
        nag: NagPolicy.none,
      ),
    ], today);
    expect(plan.alerts.every((a) => a.date >= today), isTrue);
  });

  test('alerts past the horizon are not scheduled', () {
    final plan = NotificationPlanner.plan([
      item('far', Category.document, expiresOn: '2027-06-01'),
    ], today);
    expect(plan.alerts, isEmpty, reason: 'nothing within 60 days');
  });

  test('archived items are skipped', () {
    final plan = NotificationPlanner.plan([
      item(
        'gone',
        Category.subscription,
        expiresOn: '2026-08-20',
        state: ItemState.archived,
      ),
    ], today);
    expect(plan.alerts, isEmpty);
  });

  test('daily nag repeats after the deadline', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'bill',
          Category.bill,
          expiresOn: '2026-08-18',
          leadDays: const [],
          nag: NagPolicy.daily,
        ),
      ],
      today,
      horizonDays: 5,
    );

    final nags =
        plan.alerts
            .where((a) => a.reason == AlertReason.nag)
            .map((a) => a.date)
            .toList()
          ..sort();

    expect(nags, [d('2026-08-19'), d('2026-08-20')]);
  });

  test('no nag when the policy says none', () {
    final plan = NotificationPlanner.plan([
      item(
        'nf',
        Category.subscription,
        expiresOn: '2026-08-18',
        nag: NagPolicy.none,
      ),
    ], today);
    expect(plan.alerts.any((a) => a.reason == AlertReason.nag), isFalse);
  });

  test('verify alert fires once the re-check interval has elapsed', () {
    final plan = NotificationPlanner.plan([
      item(
        'sim',
        Category.subscription,
        expiresOn: '2027-01-01',
        leadDays: const [],
        nag: NagPolicy.none,
        verifyEveryDays: 60,
        lastVerifiedAt: '2026-07-01',
      ),
    ], today);
    // 1 Jul + 60 days = 30 Aug.
    expect(
      plan.alerts
          .where((a) => a.reason == AlertReason.verify)
          .map((a) => a.date),
      [d('2026-08-30')],
    );
  });

  test('an overdue verify alert fires today rather than in the past', () {
    final plan = NotificationPlanner.plan([
      item(
        'sim',
        Category.subscription,
        expiresOn: '2027-01-01',
        leadDays: const [],
        nag: NagPolicy.none,
        verifyEveryDays: 60,
        lastVerifiedAt: '2026-01-01',
      ),
    ], today);
    expect(
      plan.alerts
          .where((a) => a.reason == AlertReason.verify)
          .map((a) => a.date),
      [today],
    );
  });

  // The core allocation rule. There is no severity axis to rank by, so the
  // budget goes to whatever fires first — and the alerts that get dropped are
  // the ones a later re-plan will pick up anyway.
  test('the budget goes to the alerts that fire soonest', () {
    final sim = item(
      'sim',
      Category.subscription,
      expiresOn: '2026-09-10',
      leadDays: [20, 15, 10],
      nag: NagPolicy.none,
    );
    final netflix = item(
      'netflix',
      Category.subscription,
      expiresOn: '2026-08-16',
      leadDays: [1],
      nag: NagPolicy.none,
    );

    final plan = NotificationPlanner.plan([netflix, sim], today, budget: 2);

    // 15/08 (netflix, lead 1) and 21/08 (sim, lead 20) come first.
    expect(plan.alerts.map((a) => a.itemId), ['netflix', 'sim']);
    expect(plan.dropped.map((a) => a.itemId), ['sim', 'sim']);
  });

  test('the soonest wins', () {
    final a = item(
      'a',
      Category.subscription,
      expiresOn: '2026-09-01',
      leadDays: [0],
      nag: NagPolicy.none,
    );
    final b = item(
      'b',
      Category.subscription,
      expiresOn: '2026-08-20',
      leadDays: [0],
      nag: NagPolicy.none,
    );

    final plan = NotificationPlanner.plan([a, b], today, budget: 1);
    expect(plan.alerts.map((e) => e.itemId), ['b']);
  });

  test('the budget is never exceeded', () {
    final many = [
      for (var i = 1; i <= 40; i++)
        item(
          'i$i',
          Category.subscription,
          expiresOn: '2026-09-01',
          nag: NagPolicy.daily,
        ),
    ];
    final plan = NotificationPlanner.plan(many, today);
    expect(plan.alerts.length, lessThanOrEqualTo(NotificationPlanner.budget));
  });

  // Truncation must be visible. iOS drops the overflow silently and never says
  // which, which is the failure this planner exists to replace.
  test('truncation is reported rather than hidden', () {
    final many = [
      for (var i = 1; i <= 40; i++)
        item(
          'i$i',
          Category.subscription,
          expiresOn: '2026-09-01',
          nag: NagPolicy.daily,
        ),
    ];
    final plan = NotificationPlanner.plan(many, today);
    expect(plan.isTruncated, isTrue);
    expect(plan.dropped, isNotEmpty);
  });

  test('a small plan is not marked truncated', () {
    final plan = NotificationPlanner.plan([
      item(
        'one',
        Category.subscription,
        expiresOn: '2026-08-20',
        nag: NagPolicy.none,
      ),
    ], today);
    expect(plan.isTruncated, isFalse);
  });

  // A subscription renewing is news; everything else on this list is a
  // deadline with a consequence.
  test('interruption level follows the category', () {
    final plan = NotificationPlanner.plan([
      item(
        'power',
        Category.bill,
        expiresOn: '2026-08-20',
        nag: NagPolicy.none,
      ),
      item(
        'nf',
        Category.subscription,
        expiresOn: '2026-08-20',
        nag: NagPolicy.none,
      ),
    ], today);
    expect(
      plan.alerts
          .where((a) => a.itemId == 'power')
          .every((a) => a.timeSensitive),
      isTrue,
    );
    expect(
      plan.alerts.where((a) => a.itemId == 'nf').any((a) => a.timeSensitive),
      isFalse,
    );
  });

  test('identifiers are unique and stable across runs', () {
    final items = [
      item(
        'sim',
        Category.subscription,
        expiresOn: '2026-09-01',
        verifyEveryDays: 60,
      ),
      item('bill', Category.bill, expiresOn: '2026-08-25'),
    ];
    final first = NotificationPlanner.plan(items, today);
    final second = NotificationPlanner.plan(items, today);

    expect(
      first.alerts.map((a) => a.identifier),
      second.alerts.map((a) => a.identifier),
    );
    expect(
      first.alerts.map((a) => a.identifier).toSet().length,
      first.alerts.length,
      reason: 'identifiers must not collide',
    );
  });

  // The scheduler cancels by numeric id across app launches, so this hash has
  // to be a property of the string, not of the process.
  test(
    'numeric ids are positive, collision-free here, and content-derived',
    () {
      final items = [
        item(
          'sim',
          Category.subscription,
          expiresOn: '2026-09-01',
          verifyEveryDays: 60,
        ),
        item('bill', Category.bill, expiresOn: '2026-08-25'),
      ];
      final plan = NotificationPlanner.plan(items, today);

      expect(plan.alerts.every((a) => a.numericId > 0), isTrue);
      expect(
        plan.alerts.map((a) => a.numericId).toSet().length,
        plan.alerts.length,
      );

      const alert = PlannedAlert(
        itemId: 'sim',
        itemName: 'SIM',
        date: LocalDate(2026, 9, 1),
        time: LocalTime(8, 30),
        leadDays: 3,
        reason: AlertReason.lead,
        timeSensitive: true,
      );
      expect(alert.identifier, 'sim|lead|2026-09-01|3');
      // Pinned to a literal, computed independently as FNV-1a over that string.
      // If this number ever changes, every notification already scheduled on a
      // user's device becomes uncancellable and duplicates stack beside it.
      expect(alert.numericId, 2007827225);
    },
  );

  test('only a subscription is allowed to arrive quietly', () {
    expect(Reminders.isTimeSensitive(Category.subscription), isFalse);
    for (final category in Category.values.where(
      (c) => c != Category.subscription,
    )) {
      expect(
        Reminders.isTimeSensitive(category),
        isTrue,
        reason: category.name,
      );
    }
  });

  test('documents stay out of spend totals even when they cost money', () {
    final passport = TrackedItem(
      id: 'p',
      name: 'Hộ chiếu',
      category: Category.document,
      expiresOn: d('2027-01-01'),
      anchorDate: d('2027-01-01'),
      amountMinor: 200000,
      currency: 'VND',
    );
    expect(passport.countsTowardSpend, isFalse);

    final netflix = TrackedItem(
      id: 'n',
      name: 'Netflix',
      category: Category.subscription,
      expiresOn: d('2026-09-01'),
      anchorDate: d('2026-09-01'),
      amountMinor: 260000,
      currency: 'VND',
    );
    expect(netflix.countsTowardSpend, isTrue);
  });
}
