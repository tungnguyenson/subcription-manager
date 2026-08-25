import 'local_date.dart';
import 'instalments.dart';
import 'model.dart';
import 'recurrence.dart';

/// What "paid", "snoozed" and "stopped" do to an item.
///
/// Pure, and deliberately not on the screen that has the buttons: the same
/// three things happen from a notification action with no UI running at all,
/// and two implementations of "mark as paid" would drift the moment one of
/// them learned about instalments.
abstract final class ItemActions {
  /// The row written when an occurrence is closed.
  ///
  /// Keyed by the due date, not by the moment of tapping, so recording the
  /// same payment twice replaces one row instead of adding a second.
  static HandledEvent handledEvent(TrackedItem item, int nowEpochSeconds) =>
      HandledEvent(
        id: '${item.id}-${item.expiresOn}',
        itemId: item.id,
        handledAtEpochSeconds: nowEpochSeconds,
        forDueDate: item.expiresOn,
        amountMinor: item.amountMinor,
        currency: item.currency,
        baseAmountMinor: item.amountMinor,
      );

  /// The item as it stands after this occurrence is closed.
  ///
  /// A limited series that has just had its last payment is archived rather
  /// than rolled forward. Rolling it forward would invent a seventh instalment
  /// on a six-instalment plan, and then remind the user to pay it.
  static TrackedItem advanced(TrackedItem item) {
    final cycle = item.cycle;
    if (cycle == null) return item.copyWith(state: ItemState.archived);

    final position = Instalments.of(item);
    if (position != null && position.isLast) {
      return item.copyWith(state: ItemState.archived);
    }

    final next = Recurrence.nextDue(item.anchorDate, cycle, item.expiresOn);
    if (next == null) return item.copyWith(state: ItemState.archived);

    return item.copyWith(
      expiresOn: next,
      // The new date was computed, not told to us by the provider.
      dateSource: DateSource.computed,
      // The snooze was postponing the occurrence that just closed. Carrying it
      // into the next one would fire a reminder about a payment already made.
      snoozedUntil: () => null,
      // The occurrence that just closed *was* the first charge, so the trial
      // is over. Leaving the start date on would keep the item out of the
      // spending total forever and keep labelling a paid subscription "free".
      trialStart: () => null,
    );
  }

  /// Postpones this item's nudge to [until].
  ///
  /// Replaces any snooze already set rather than queueing a second one: asking
  /// twice means "not now" twice, not "twice as many reminders".
  static TrackedItem snoozed(TrackedItem item, LocalDate until) =>
      item.copyWith(snoozedUntil: () => until);

  /// Ends the series after the payment that is currently due.
  ///
  /// For an open-ended subscription that is a state change; for a limited plan
  /// it pins the count to where the user already is, which is the same thing
  /// said in the plan's own terms.
  static TrackedItem stopped(TrackedItem item) {
    final position = Instalments.of(item);
    return position == null
        ? item.copyWith(state: ItemState.cancelledStillActive)
        : item.copyWith(repeatCount: () => position.index);
  }
}
