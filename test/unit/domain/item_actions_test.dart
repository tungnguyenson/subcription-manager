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
  final now = LocalDateTime(today, const LocalTime(0, 0));

  TrackedItem item({
    String expiresOn = '2026-08-21',
    String? anchorDate,
    Cycle? cycle = Cycle.monthly,
    int? repeatCount,
    String? snoozedUntil,
    bool inTrial = false,
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
    inTrial: inTrial,
    paused: paused,
    yearlyChoice: yearlyChoice,
  );

  group('snooze', () {
    test('the postponed date is what gets scheduled', () {
      final plan = NotificationPlanner.plan(
        [item(snoozedUntil: '2026-08-18')],
        CategoryBook.shipped,
        now,
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
        now,
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
    // The flag alone is not the answer: the free period ends when the charge
    // date arrives, whether or not anyone came back to the app to say so, and
    // a row still badged FREE TRIAL a week after the money left is the app
    // claiming to know something it does not.
    test('runs until the first charge date, then stops on its own', () {
      final trial = item(expiresOn: '2026-08-21', inTrial: true);

      expect(trial.isTrialOn(d('2026-08-20')), isTrue);
      expect(trial.isTrialOn(d('2026-08-21')), isFalse);
      expect(trial.isTrialOn(d('2026-08-22')), isFalse);
    });

    test('an item without the flag is never in one', () {
      expect(item(expiresOn: '2026-08-21').isTrialOn(d('2026-08-01')), isFalse);
    });

    // The flag says the months *before* the first charge were free, and that
    // never stops being true. Whether it is a trial today is a separate
    // question -- see isTrialOn -- and the two must not be folded together.
    test('the flag outlives the free period', () {
      final trial = item(expiresOn: '2026-08-21', inTrial: true);

      expect(trial.isTrialOn(d('2026-09-01')), isFalse);
      expect(trial.inTrial, isTrue);
    });

    // Whether an amount lands in a spending total is a question about the
    // month it lands in, not about the item. The months a trial covered carry
    // no money; the ones after its first charge carry the full amount.
    test('does not change whether the item counts toward spend', () {
      final trial = TrackedItem(
        id: 'x',
        name: 'Claude Pro',
        categoryId: 'STREAMING',
        expiresOn: d('2026-08-21'),
        anchorDate: d('2026-08-21'),
        cycle: Cycle.monthly,
        amountMinor: 520000,
        currency: 'VND',
        inTrial: true,
      );

      expect(
        trial.countsTowardSpend(CategoryBook.shipped[trial.categoryId]),
        isTrue,
      );
    });

    // The occurrence that just closed *was* the first charge, so the trial is
    // over for good. expiresOn has just moved to next month, so a flag left on
    // would read as "free until then" all over again.
    test('the flag is cleared once the first charge is recorded', () {
      final advanced = ItemActions.advanced(
        item(expiresOn: '2026-08-21', inTrial: true),
      );

      expect(advanced.inTrial, isFalse);
      expect(advanced.isTrialOn(d('2026-08-22')), isFalse);
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
        now,
      );
      expect(plan.alerts, isEmpty);

      final on = NotificationPlanner.plan([item()], CategoryBook.shipped, now);
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
        now,
      );
      final nudged = NotificationPlanner.plan(
        [item(yearlyChoice: YearlyChoice.remind)],
        CategoryBook.shipped,
        now,
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
        now,
      );

      final nags = nudged.alerts.where((a) => a.reason == AlertReason.nag);
      expect(nags, isNotEmpty);
      expect(nags.every((a) => a.note == null), isTrue);
    });

    test('says nothing extra when the user has not asked', () {
      final plain = NotificationPlanner.plan(
        [item()],
        CategoryBook.shipped,
        now,
      );
      expect(plain.alerts.every((a) => a.note == null), isTrue);
      expect(plain.alerts.first.body, 'Course');
    });
  });
}
