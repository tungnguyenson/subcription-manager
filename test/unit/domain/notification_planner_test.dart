import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/reminders.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');

  // Midnight, so nothing has fired yet and every alert dated today is still
  // ahead. Tests about the clock set their own time; see the group at the end.
  final now = LocalDateTime(today, const LocalTime(0, 0));
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
    LocalTime remindAt = Reminders.defaultRemindAt,
    ItemState state = ItemState.active,
  }) {
    return TrackedItem(
      id: id,
      name: name ?? id,
      categoryId: category.id,
      expiresOn: d(expiresOn),
      actByOffsetDays: actByOffsetDays,
      anchorDate: d(expiresOn),
      leadDays: leadDays ?? category.leadDays,
      nagAfterDue: nag ?? category.nag,
      // Left unset unless a test asks for one, so an unspecified verify
      // interval means "none" rather than the shelf's default. Verify alerts
      // are exercised in their own tests.
      verifyEveryDays: verifyEveryDays,
      lastVerifiedAt: lastVerifiedAt == null ? null : d(lastVerifiedAt),
      remindAt: remindAt,
      state: state,
    );
  }

  test('lead alerts land the right number of days before the act-by date', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          't',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-20',
          leadDays: [3, 1, 0],
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );

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
    final plan = NotificationPlanner.plan(
      [
        item(
          'sim',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-14',
          actByOffsetDays: 7,
          leadDays: [0],
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    // act-by is 7 days before 14 Sep.
    expect(plan.alerts.map((a) => a.date), [d('2026-09-07')]);
  });

  test('alerts in the past are not scheduled', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'old',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-16',
          leadDays: [30, 1],
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    expect(plan.alerts.every((a) => a.date >= today), isTrue);
  });

  // The whole point of the change that removed the sixty-day ceiling from lead
  // rungs. A passport eighteen months out used to produce an empty plan, and
  // the detail screen then told the user every step of its ladder had already
  // passed -- for a ladder that had not started. Both platforms take a trigger
  // dated any distance ahead, so the app asks for it now rather than promising
  // to ask later.
  test('a rung far past the horizon is still scheduled', () {
    final plan = NotificationPlanner.plan(
      [item('far', CategoryBook.shipped['DOCUMENTS'], expiresOn: '2027-06-01')],
      CategoryBook.shipped,
      now,
    );

    final leads =
        plan.alerts
            .where((a) => a.reason == AlertReason.lead)
            .map((a) => a.date)
            .toList()
          ..sort();

    // DOCUMENTS ships `leadDays: [30, 7]`, both of them roughly ten months out.
    expect(leads, [d('2027-05-02'), d('2027-05-25')]);
  });

  // A nag has no last step -- it repeats for as long as the thing stays
  // undone -- so it is the one kind that still needs a ceiling. Countable
  // alerts do not, and mixing the two jobs into one constant is what put the
  // ceiling on the rungs.
  //
  // Two ceilings, each with its own job. The horizon says a nag for a deadline
  // still far off is not worth scheduling; the count says the fortieth repeat
  // of one that is near is not worth a slot.
  test('a nag is bounded by a count, not just by the horizon', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'bill',
          CategoryBook.shipped['UTILITIES'],
          expiresOn: '2026-08-14',
          leadDays: const [],
          nag: NagPolicy.daily,
        ),
      ],
      CategoryBook.shipped,
      now,
      budget: 1000,
    );

    final nags =
        plan.alerts
            .where((a) => a.reason == AlertReason.nag)
            .map((a) => a.date)
            .toList()
          ..sort();

    // Daily from the day after the deadline, and then it stops. The budget is
    // raised well above it here so the ceiling under test is the count and not
    // the fifty slots.
    expect(nags.first, d('2026-08-15'));
    expect(nags.length, NotificationPlanner.maxNagsPerItem);
    expect(
      nags.last,
      d('2026-08-15').plusDays(NotificationPlanner.maxNagsPerItem - 1),
    );
  });

  // What the app is for. A lead rung lands while the thing can still be
  // prevented; a nag lands after the fact, on a day the provider is already
  // sending its own message and the service is already being cut. Ordering a
  // round by date alone handed the slot to whichever alert was nearest, and a
  // nag is always nearest -- it starts the day after a deadline that has gone
  // by, while the rung it displaces belongs to one still weeks out.
  test('a rung still ahead of its deadline outranks a nag behind one', () {
    final overdue = item(
      'overdue',
      CategoryBook.shipped['UTILITIES'],
      expiresOn: '2026-08-10',
      leadDays: const [],
      nag: NagPolicy.daily,
    );
    final coming = item(
      'coming',
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-09-20',
      leadDays: [30, 7],
      nag: NagPolicy.none,
    );

    // Two slots: one for each item's first alert, and then one contested
    // between the overdue item's second nag (tomorrow) and the coming item's
    // second rung (five weeks out).
    final plan = NotificationPlanner.plan(
      [overdue, coming],
      CategoryBook.shipped,
      now,
      budget: 3,
    );

    expect(
      plan.alerts.map((a) => '${a.itemId}/${a.reason.name}'),
      containsAll(['overdue/nag', 'coming/lead']),
      reason: 'round zero still covers both items',
    );
    expect(
      plan.alerts.where((a) => a.reason == AlertReason.lead).length,
      2,
      reason: 'the contested third slot goes to the rung, not the second nag',
    );
  });

  // One overdue item nagging daily used to generate sixty near dates. Sorted
  // by date alone it took every slot and the rest of the list went silent,
  // with nothing on any screen saying so. Round zero is one alert per item, so
  // a list of fewer items than the budget can never have an item hear nothing.
  test('every item gets a slot before any item gets a second', () {
    final noisy = item(
      'overdue',
      CategoryBook.shipped['UTILITIES'],
      expiresOn: '2026-08-14',
      leadDays: const [],
      nag: NagPolicy.daily,
    );
    final quiet = [
      for (var i = 0; i < 20; i++)
        item(
          'q$i',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-${(i + 1).toString().padLeft(2, '0')}',
          leadDays: const [3],
          nag: NagPolicy.none,
        ),
    ];

    final plan = NotificationPlanner.plan(
      [noisy, ...quiet],
      CategoryBook.shipped,
      now,
    );

    for (final q in quiet) {
      expect(plan.alerts.any((a) => a.itemId == q.id), isTrue, reason: q.id);
    }
  });

  test('archived items are skipped', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'gone',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-20',
          state: ItemState.inactive,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    expect(plan.alerts, isEmpty);
  });

  test('daily nag repeats after the deadline', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'bill',
          CategoryBook.shipped['UTILITIES'],
          expiresOn: '2026-08-18',
          leadDays: const [],
          nag: NagPolicy.daily,
        ),
      ],
      CategoryBook.shipped,
      now,
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
    final plan = NotificationPlanner.plan(
      [
        item(
          'nf',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-18',
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    expect(plan.alerts.any((a) => a.reason == AlertReason.nag), isFalse);
  });

  test('verify alert fires once the re-check interval has elapsed', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'sim',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2027-01-01',
          leadDays: const [],
          nag: NagPolicy.none,
          verifyEveryDays: 60,
          lastVerifiedAt: '2026-07-01',
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    // 1 Jul + 60 days = 30 Aug.
    expect(
      plan.alerts
          .where((a) => a.reason == AlertReason.verify)
          .map((a) => a.date),
      [d('2026-08-30')],
    );
  });

  test('an overdue verify alert fires today rather than in the past', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'sim',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2027-01-01',
          leadDays: const [],
          nag: NagPolicy.none,
          verifyEveryDays: 60,
          lastVerifiedAt: '2026-01-01',
        ),
      ],
      CategoryBook.shipped,
      now,
    );
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
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-09-10',
      leadDays: [20, 15, 10],
      nag: NagPolicy.none,
    );
    final netflix = item(
      'netflix',
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-08-16',
      leadDays: [1],
      nag: NagPolicy.none,
    );

    final plan = NotificationPlanner.plan(
      [netflix, sim],
      CategoryBook.shipped,
      now,
      budget: 2,
    );

    // 15/08 (netflix, lead 1) and 21/08 (sim, lead 20) come first.
    expect(plan.alerts.map((a) => a.itemId), ['netflix', 'sim']);
    expect(plan.dropped.map((a) => a.itemId), ['sim', 'sim']);
  });

  test('the soonest wins', () {
    final a = item(
      'a',
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-09-01',
      leadDays: [0],
      nag: NagPolicy.none,
    );
    final b = item(
      'b',
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-08-20',
      leadDays: [0],
      nag: NagPolicy.none,
    );

    final plan = NotificationPlanner.plan(
      [a, b],
      CategoryBook.shipped,
      now,
      budget: 1,
    );
    expect(plan.alerts.map((e) => e.itemId), ['b']);
  });

  test('the budget is never exceeded', () {
    final many = [
      for (var i = 1; i <= 40; i++)
        item(
          'i$i',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-01',
          nag: NagPolicy.daily,
        ),
    ];
    final plan = NotificationPlanner.plan(many, CategoryBook.shipped, now);
    expect(plan.alerts.length, lessThanOrEqualTo(NotificationPlanner.budget));
  });

  // Truncation must be visible. iOS drops the overflow silently and never says
  // which, which is the failure this planner exists to replace.
  test('truncation is reported rather than hidden', () {
    final many = [
      for (var i = 1; i <= 40; i++)
        item(
          'i$i',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-01',
          nag: NagPolicy.daily,
        ),
    ];
    final plan = NotificationPlanner.plan(many, CategoryBook.shipped, now);
    expect(plan.isTruncated, isTrue);
    expect(plan.dropped, isNotEmpty);
  });

  test('a small plan is not marked truncated', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'one',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-20',
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
    expect(plan.isTruncated, isFalse);
  });

  // A subscription renewing is news; everything else on this list is a
  // deadline with a consequence.
  test('interruption level follows the category', () {
    final plan = NotificationPlanner.plan(
      [
        item(
          'power',
          CategoryBook.shipped['UTILITIES'],
          expiresOn: '2026-08-20',
          nag: NagPolicy.none,
        ),
        item(
          'nf',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-08-20',
          nag: NagPolicy.none,
        ),
      ],
      CategoryBook.shipped,
      now,
    );
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
        CategoryBook.shipped['STREAMING'],
        expiresOn: '2026-09-01',
        verifyEveryDays: 60,
      ),
      item('bill', CategoryBook.shipped['UTILITIES'], expiresOn: '2026-08-25'),
    ];
    final first = NotificationPlanner.plan(items, CategoryBook.shipped, now);
    final second = NotificationPlanner.plan(items, CategoryBook.shipped, now);

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
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-01',
          verifyEveryDays: 60,
        ),
        item(
          'bill',
          CategoryBook.shipped['UTILITIES'],
          expiresOn: '2026-08-25',
        ),
      ];
      final plan = NotificationPlanner.plan(items, CategoryBook.shipped, now);

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

  test('a shelf that nags is a shelf that gets past Focus', () {
    // The two are one setting read twice, and the point of reading it twice is
    // that they cannot drift apart: a shelf set to keep asking after the date
    // is a shelf with a consequence, and a consequence delivered silently
    // during Focus was not delivered.
    for (final category in CategoryBook.shipped.all) {
      expect(
        category.isTimeSensitive,
        category.nag != NagPolicy.none,
        reason: category.id,
      );
    }
  });

  test('the shipped shelves let subscriptions arrive quietly', () {
    expect(CategoryBook.shipped['STREAMING'].isTimeSensitive, isFalse);
    expect(CategoryBook.shipped['UTILITIES'].isTimeSensitive, isTrue);
    expect(CategoryBook.shipped['PHONE'].isTimeSensitive, isTrue);
    expect(CategoryBook.shipped['DOCUMENTS'].isTimeSensitive, isTrue);
  });

  test('documents stay out of spend totals even when they cost money', () {
    final passport = TrackedItem(
      id: 'p',
      name: 'Hộ chiếu',
      categoryId: 'DOCUMENTS',
      expiresOn: d('2027-01-01'),
      anchorDate: d('2027-01-01'),
      amountMinor: 200000,
      currency: 'VND',
    );
    expect(
      passport.countsTowardSpend(CategoryBook.shipped[passport.categoryId]),
      isFalse,
    );

    final netflix = TrackedItem(
      id: 'n',
      name: 'Netflix',
      categoryId: 'STREAMING',
      expiresOn: d('2026-09-01'),
      anchorDate: d('2026-09-01'),
      amountMinor: 260000,
      currency: 'VND',
    );
    expect(
      netflix.countsTowardSpend(CategoryBook.shipped[netflix.categoryId]),
      isTrue,
    );
  });

  // The time of day is an input to the plan, not decoration on it. Before
  // this, an item that sent at 08:30 kept offering that alert all day: the
  // detail screen read "Next reminder 25/08 at 08:30" at half past six in the
  // evening, and the scheduler was handed a trigger iOS never fires and
  // Android fires on the spot.
  group('the clock, not just the calendar day', () {
    TrackedItem dueToday({
      String id = 't',
      LocalTime remindAt = Reminders.defaultRemindAt,
    }) => item(
      id,
      CategoryBook.shipped['STREAMING'],
      expiresOn: '2026-08-15',
      leadDays: const [0],
      nag: NagPolicy.none,
      remindAt: remindAt,
    );

    test('an alert whose send time has passed is not planned', () {
      final plan = NotificationPlanner.plan(
        [dueToday()],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(18, 40)),
      );

      expect(plan.alerts, isEmpty);
    });

    test('the same alert an hour before its send time still is', () {
      final plan = NotificationPlanner.plan(
        [dueToday()],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(7, 30)),
      );

      expect(plan.alerts.map((a) => a.date), [today]);
    });

    // Per item, because the send time is per item. One clock reading splits
    // the list in two.
    test('an item that sends later in the day is untouched', () {
      final plan = NotificationPlanner.plan(
        [
          dueToday(id: 'morning'),
          dueToday(id: 'evening', remindAt: const LocalTime(21, 0)),
        ],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(18, 40)),
      );

      expect(plan.alerts.map((a) => a.itemId), ['evening']);
    });

    // A lead rung names a day relative to the deadline. Sliding today's to
    // tomorrow would say "3 days before" on the day that is two days before,
    // so a rung that has passed is gone rather than moved.
    test('a lead rung that has passed drops instead of sliding', () {
      final plan = NotificationPlanner.plan(
        [
          item(
            't',
            CategoryBook.shipped['STREAMING'],
            expiresOn: '2026-08-18',
            leadDays: [3, 0],
            nag: NagPolicy.none,
          ),
        ],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(18, 40)),
      );

      expect(plan.alerts.map((a) => (a.date, a.leadDays)), [
        (d('2026-08-18'), 0),
      ], reason: 'the 3-day rung was today and is not re-dated to tomorrow');
    });

    // Unlike a lead rung. "This is still not done" is as true tomorrow as it
    // was at 08:30 today, so the one that passed slides rather than vanishing
    // -- otherwise an overdue item goes quiet for the rest of the day it went
    // overdue on.
    test('a nag slides to the next day it can still be sent', () {
      final plan = NotificationPlanner.plan(
        [
          item(
            't',
            CategoryBook.shipped['STREAMING'],
            expiresOn: '2026-08-10',
            leadDays: const [],
            nag: NagPolicy.daily,
          ),
        ],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(18, 40)),
      );

      final nags = plan.alerts
          .where((a) => a.reason == AlertReason.nag)
          .map((a) => a.date)
          .toList();
      expect(nags.first, d('2026-08-16'));
      expect(nags, isNot(contains(today)));
    });

    test('an overdue verify slides for the same reason', () {
      final plan = NotificationPlanner.plan(
        [
          item(
            't',
            CategoryBook.shipped['STREAMING'],
            expiresOn: '2027-01-01',
            leadDays: const [],
            nag: NagPolicy.none,
            verifyEveryDays: 60,
            lastVerifiedAt: '2026-01-01',
          ),
        ],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(18, 40)),
      );

      expect(
        plan.alerts
            .where((a) => a.reason == AlertReason.verify)
            .map((a) => a.date),
        [d('2026-08-16')],
      );
    });

    // [LocalTime] has no seconds, so an alert whose minute is the current
    // minute may have fired forty seconds ago. Re-scheduling it would fire a
    // second copy on the spot.
    test('the current minute counts as already sent', () {
      final plan = NotificationPlanner.plan(
        [dueToday()],
        CategoryBook.shipped,
        LocalDateTime(today, const LocalTime(8, 30)),
      );

      expect(plan.alerts, isEmpty);
    });
  });

  // Whether a rung can be handed over as a standing rule.
  //
  // The whole reason this exists: an alert that only fires once, on an app
  // that only ever computes the next occurrence, means a user who stops
  // opening the app goes silent after one cycle -- with three services or with
  // thirty-three. A repeating request costs the same single slot and fires
  // for ever.
  group('which rungs repeat', () {
    TrackedItem monthlyDue(String due, {int? repeatCount, ItemState? state}) =>
        TrackedItem(
          id: 'm',
          name: 'Netflix',
          categoryId: 'STREAMING',
          expiresOn: d(due),
          anchorDate: d(due),
          cycle: Cycle.monthly,
          repeatCount: repeatCount,
          state: state ?? ItemState.active,
          leadDays: const [3],
          nagAfterDue: NagPolicy.none,
          remindAt: Reminders.defaultRemindAt,
        );

    // Due on the 20th, three days' notice, so the reminder is the 17th of
    // every month for ever. Nothing drifts.
    test('a monthly plan whose notice stays inside the month', () {
      expect(
        NotificationPlanner.repeatFor(monthlyDue('2026-09-20'), 3),
        AlertRepeat.monthly,
      );
    });

    // The trap the arithmetic hides. Due on the 5th with a week's notice, the
    // reminder is 29 Dec, 29 Jan, then 26 Feb, because February is short.
    // There is no day of the month to repeat on.
    test('a monthly plan whose notice crosses into the short month', () {
      expect(
        NotificationPlanner.repeatFor(monthlyDue('2026-09-05'), 7),
        AlertRepeat.none,
      );
    });

    // Due on the 31st. The deadline itself skips the months that have no 31st,
    // so a fixed-day repeat would fire in months with no charge behind it.
    test('a monthly plan due past the 28th', () {
      expect(
        NotificationPlanner.repeatFor(monthlyDue('2026-10-31'), 3),
        AlertRepeat.none,
      );
    });

    // A standing rule outlives the thing it is about. Both of these end on a
    // date that only something running inside the app can notice.
    test('a counted plan never repeats', () {
      expect(
        NotificationPlanner.repeatFor(
          monthlyDue('2026-09-20', repeatCount: 6),
          3,
        ),
        AlertRepeat.none,
      );
    });

    test('a cancelled plan never repeats', () {
      expect(
        NotificationPlanner.repeatFor(
          monthlyDue('2026-09-20', state: ItemState.cancelledStillActive),
          3,
        ),
        AlertRepeat.none,
      );
    });

    // No shape the platform can match on, so it stays one-shot and stays
    // silent after one cycle. Worth a test because it is the part the calendar
    // mirror still has to cover.
    test('quarterly and a hand-typed cycle do not repeat', () {
      for (final cycle in [Cycle.quarterly, Cycle.every(10, CycleField.day)]) {
        final it = item(
          'q',
          CategoryBook.shipped['STREAMING'],
          expiresOn: '2026-09-20',
          leadDays: const [3],
          nag: NagPolicy.none,
        ).copyWith(cycle: () => cycle);
        expect(
          NotificationPlanner.repeatFor(it, 3),
          AlertRepeat.none,
          reason: '$cycle',
        );
      }
    });

    test('an item with no cycle does not repeat', () {
      expect(
        NotificationPlanner.repeatFor(
          item(
            'passport',
            CategoryBook.shipped['DOCUMENTS'],
            expiresOn: '2028-02-01',
          ),
          30,
        ),
        AlertRepeat.none,
      );
    });

    // Only the rung. A nag has to be able to say something different each
    // firing and to stop the moment the thing is handled; a verify prompt runs
    // on its own interval, which matches no calendar shape.
    test('only a lead rung is marked repeating', () {
      final plan = NotificationPlanner.plan(
        [
          item(
            'bill',
            CategoryBook.shipped['UTILITIES'],
            expiresOn: '2026-08-14',
            leadDays: const [],
            nag: NagPolicy.daily,
            verifyEveryDays: 30,
          ).copyWith(cycle: () => Cycle.monthly),
        ],
        CategoryBook.shipped,
        now,
      );

      expect(plan.alerts, isNotEmpty);
      expect(
        plan.alerts.every((a) => a.repeat == AlertRepeat.none),
        isTrue,
        reason: plan.alerts
            .map((a) => '${a.reason.name}:${a.repeat.name}')
            .join(' '),
      );
    });
  });
}
