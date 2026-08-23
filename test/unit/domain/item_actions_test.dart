import 'package:flutter_test/flutter_test.dart';
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
  }) => TrackedItem(
    id: 'x',
    name: 'Course',
    category: Category.bill,
    expiresOn: d(expiresOn),
    anchorDate: d(anchorDate ?? expiresOn),
    cycle: cycle,
    repeatCount: repeatCount,
    snoozedUntil: snoozedUntil == null ? null : d(snoozedUntil),
  );

  group('snooze', () {
    test('the postponed date is what gets scheduled', () {
      final plan = NotificationPlanner.plan([
        item(snoozedUntil: '2026-08-18'),
      ], today);

      final snoozed = plan.alerts.where((a) => a.reason == AlertReason.snoozed);
      expect(snoozed, hasLength(1));
      expect(snoozed.single.date, d('2026-08-18'));
    });

    // A snooze in the past is a snooze that already fired. Scheduling it would
    // ask iOS for a notification with a date behind it.
    test('a snooze that has already passed is not scheduled', () {
      final plan = NotificationPlanner.plan([
        item(snoozedUntil: '2026-08-01'),
      ], today);

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
}
