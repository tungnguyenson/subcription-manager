/// What the operating system shows: the two channels, the buttons on a post,
/// and the title of each kind of alert.
///
/// This is the only text in the app the user reads without opening it, so it
/// has to stand alone. `Overdue` on a lock screen is the whole message; there
/// is no screen around it to give it context.
abstract class NotificationStrings {
  /// Android names its channels once, when they are created. A language
  /// changed while the app is running does not rename a channel already on
  /// the system — the new name lands on the next launch, when `initialise`
  /// creates them again with the same ids.
  String get channelDeadlines;
  String get channelDeadlinesBody;
  String get channelReminders;
  String get channelRemindersBody;

  String get actionMarkAsPaid;
  String get actionRemindTomorrow;
  String get actionOpen;
  String get actionGotIt;

  String get testReminderTitle;
  String get testReminderBody;

  String get notifDueToday;
  String get notifDueTomorrow;
  String notifDueInDays(int days);
  String get notifOverdue;
  String get notifVerify;
  String get notifSnoozed;

  /// The note a planned alert carries under its own title: the yearly-plan
  /// nudge that rides on a renewal reminder.
  String get notifYearlyCostsLess;
}
