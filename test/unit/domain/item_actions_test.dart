import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/item_actions.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-15');

  TrackedItem item({
    String expiresOn = '2026-08-21',
    String? anchorDate,
    Cycle? cycle = Cycle.monthly,
    int? repeatCount,
    String? snoozedUntil,
    String? trialStart,
    bool paused = false,
    YearlyChoice yearlyChoice = YearlyChoice.undecided,
    // `.on` rather than the plain constructor, so the item picks up the
    // shelf's nag policy the way a real one does. Utilities nags daily, which
    // is what the nag tests below need.
  }) => TrackedItem.on(
    CategoryBook.shipped['UTILITIES'],
    id: 'x',
    name: 'Course',
    expiresOn: d(expiresOn),
    anchorDate: d(anchorDate ?? expiresOn),
    cycle: cycle,
    repeatCount: repeatCount,
    snoozedUntil: snoozedUntil == null ? null : d(snoozedUntil),
    trialStart: trialStart == null ? null : d(trialStart),
    paused: paused,
    yearlyChoice: yearlyChoice,
  );

  group('snooze', () {
    test('the postponed date is what gets scheduled', () {
      final plan = NotificationPlanner.plan(
        [item(snoozedUntil: '2026-08-18')],
        CategoryBook.shipped,
        today,
      );

      final snoozed = plan.alerts.where((a) => a.reason == AlertReason.snoozed);
      expect(snoozed, hasLength(1));
      expect(snoozed.single.date, d('2026-08-18'));
    });

    // A snooze in the past is a snooze that already fired. Scheduling it would
    // ask iOS for a notification with a date behind it.
    test('a snooze that has already passed is not scheduled', () {
      final plan = NotificationPlanner.plan(
        [item(snoozedUntil: '2026-08-01')],
        CategoryBook.shipped,
        today,
      );

      expect(
        plan.alerts.where((a) => a.reason == AlertReason.snoozed),
        isEmpty,
      );
    });

    // Asking twice means "not now" twice, not twice as many reminders.
    test('a second snooze replaces the first', () {
      final once = ItemActions.snoozed(item(), d('2026-08-18'));
      final twice = ItemActions.snoozed(once, d('2026-08-20'));

      expect(twice.snoozedUntil, d('2026-08-20'));
    });

    // The snooze was postponing the occurrence that just closed. Carrying it
    // forward would fire a reminder about a payment already made.
    test('closing the occurrence clears the snooze', () {
      final advanced = ItemActions.advanced(
        item(anchorDate: '2026-05-21', snoozedUntil: '2026-08-18'),
      );

      expect(advanced.snoozedUntil, isNull);
      expect(advanced.expiresOn, d('2026-09-21'));
    });
  });

  group('closing an occurrence', () {
    test('the last instalment archives rather than inventing a seventh', () {
      final last = item(
        anchorDate: '2026-03-21',
        expiresOn: '2026-08-21',
        repeatCount: 6,
      );

      expect(ItemActions.advanced(last).state, ItemState.archived);
    });

    test('a one-off is done when it is done', () {
      expect(ItemActions.advanced(item(cycle: null)).state, ItemState.archived);
    });

    // Keyed by the due date, so recording the same payment twice replaces one
    // row instead of adding a second.
    test('the history row is keyed by the occurrence, not by the moment', () {
      final event = ItemActions.handledEvent(item(), 1755000000);

      expect(event.forDueDate, d('2026-08-21'));
      expect(ItemActions.handledEvent(item(), 1799000000).id, event.id);
    });
  });

  group('stopping', () {
    test('a limited plan stops at the payment already due', () {
      final stopped = ItemActions.stopped(
        item(anchorDate: '2026-05-21', repeatCount: 6),
      );

      expect(stopped.repeatCount, 4);
      expect(stopped.state, ItemState.active);
    });

    test('an open-ended item is cancelled but still runs its period', () {
      expect(ItemActions.stopped(item()).state, ItemState.cancelledStillActive);
    });
  });

  group('a free trial', () {
    test('is a trial exactly while it has a start date', () {
      expect(item().isTrial, isFalse);
      expect(item(trialStart: '2026-08-07').isTrial, isTrue);
    });

    // The end of the free period *is* expiresOn. Storing both would let them
    // disagree, and every reminder already fires ahead of expiresOn — which is
    // the promise a trial reminder makes.
    test('its length is the distance to the first charge', () {
      expect(
        item(expiresOn: '2026-08-21', trialStart: '2026-08-07').trialLengthDays,
        14,
      );
    });

    // The amount on a trial is what the user *will* pay. A figure nobody has
    // been charged has no business in a spending total.
    test('does not count toward spend', () {
      final trial = TrackedItem(
        id: 'x',
        name: 'Claude Pro',
        categoryId: 'STREAMING',
        expiresOn: d('2026-08-21'),
        anchorDate: d('2026-08-21'),
        cycle: Cycle.monthly,
        amountMinor: 520000,
        currency: 'VND',
        trialStart: d('2026-08-07'),
      );

      expect(
        trial.countsTowardSpend(CategoryBook.shipped[trial.categoryId]),
        isFalse,
      );
      expect(
        trial
            .copyWith(trialStart: () => null)
            .countsTowardSpend(CategoryBook.shipped[trial.categoryId]),
        isTrue,
      );
    });

    // The occurrence that just closed *was* the first charge, so the trial is
    // over. Leaving the start date on would keep a paid subscription out of the
    // spending total forever and keep labelling it free.
    test('is over once the first charge is recorded', () {
      final advanced = ItemActions.advanced(
        item(expiresOn: '2026-08-21', trialStart: '2026-08-07'),
      );

      expect(advanced.isTrial, isFalse);
      expect(advanced.expiresOn, d('2026-09-21'));
    });
  });

  group('paused', () {
    // One predicate for the list and the planner, so they can never disagree
    // about what the user switched off.
    test('is not live, and neither is archived', () {
      expect(item().isLive, isTrue);
      expect(item(paused: true).isLive, isFalse);
      expect(item().copyWith(state: ItemState.archived).isLive, isFalse);
    });

    // A cancelled-but-still-running subscription can also be paused, which is
    // why this is a flag rather than a fourth ItemState.
    test('is orthogonal to the item state', () {
      final both = item(paused: true)
          .copyWith(state: ItemState.cancelledStillActive);

      expect(both.paused, isTrue);
      expect(both.state, ItemState.cancelledStillActive);
    });

    test('schedules nothing', () {
      final plan = NotificationPlanner.plan(
        [item(paused: true)],
        CategoryBook.shipped,
        today,
      );
      expect(plan.alerts, isEmpty);

      final on = NotificationPlanner.plan(
        [item()],
        CategoryBook.shipped,
        today,
      );
      expect(on.alerts, isNotEmpty);
    });
  });

  group('the yearly nudge', () {
    // A rider on an existing alert, not an alert of its own. The budget here is
    // 50 slots for the whole app, so spending a second one to say one more
    // sentence is the wrong trade.
    test('rides on the lead reminders without costing a slot', () {
      final plain = NotificationPlanner.plan(
        [item()],
        CategoryBook.shipped,
        today,
      );
      final nudged = NotificationPlanner.plan(
        [item(yearlyChoice: YearlyChoice.remind)],
        CategoryBook.shipped,
        today,
      );

      expect(nudged.alerts, hasLength(plain.alerts.length));
      expect(
        nudged.alerts.where((a) => a.reason == AlertReason.lead).first.body,
        'Course · Yearly costs less',
      );
    });

    // A nag fires *after* the money has gone. Telling someone the yearly plan
    // is cheaper at that point is worse than silence.
    test('never rides on a nag', () {
      final nudged = NotificationPlanner.plan(
        [item(expiresOn: '2026-08-10', yearlyChoice: YearlyChoice.remind)],
        CategoryBook.shipped,
        today,
      );

      final nags = nudged.alerts.where((a) => a.reason == AlertReason.nag);
      expect(nags, isNotEmpty);
      expect(nags.every((a) => a.note == null), isTrue);
    });

    test('says nothing extra when the user has not asked', () {
      final plain = NotificationPlanner.plan(
        [item()],
        CategoryBook.shipped,
        today,
      );
      expect(plain.alerts.every((a) => a.note == null), isTrue);
      expect(plain.alerts.first.body, 'Course');
    });
  });
}
