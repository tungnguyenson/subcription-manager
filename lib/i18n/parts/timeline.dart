/// The `What happens next` column on the item screen, and the card that draws
/// it.
abstract class TimelineStrings {
  /// The act-by row, on an item whose deadline is earlier than its date.
  String get timelineActBy;

  /// The three wordings the deadline row takes. Which one is used is the
  /// category's decision — see [ItemStrings] for the same split on the
  /// summary line — except `First payment`, which is a trial's, because on
  /// that item the day is not one charge among many.
  String get timelineExpires;
  String get timelineFirstPayment;
  String get timelinePaymentDue;

  /// Appended to a row whose date is behind us. The app has no idea whether
  /// the charge went through, only that the day is gone — which is why the
  /// verb is dropped along with it.
  String get timelineAlreadyPassed;

  /// `260,000 ₫ charged`, said only where somebody else takes the money on
  /// the day. On an expiring item the price is what renewing costs and nobody
  /// debits it, so the number stands alone.
  String timelineCharged(String amount);

  /// Today's row on an item still inside its free period.
  String timelineFreeForDays(int days);
  String get timelineNothingChargedYet;

  /// The rows the plan itself puts on the column.
  String get timelineSnoozed;
  String get timelineVerify;
  String get timelineNag;

  /// The collapsed nag run: `Then every day until you mark it as paid`.
  String timelineNagEvery(int stepDays);

  /// `Reminder at 08:30`, and the `· next` that marks the one due first.
  String timelineReminderAt(String time);
  String get timelineReminder;
  String timelineNext(String label);

  // ---- the footnote ----

  String get timelineSilentPaused;
  String get timelineSilentClosed;
  String get timelineSilentLadderDone;

  /// What the budget could not fit. Nag rows are deliberately not counted:
  /// an overdue item with a daily nag overflows the budget on its own, and
  /// the planner picks those up again as the nearer alerts pass.
  String timelineDropped(int count, int budget);
}
