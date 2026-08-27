/// The sentences the app itself speaks: the toasts after an action, the banner
/// when notifications are off, and the two questions it asks after a save.
abstract class AppStrings {
  String get notificationsOffTitle;
  String get notificationsOffBody;

  /// The button on that banner. One word, because it sits at the end of a
  /// row that is already a full sentence.
  String get turnOn;

  /// The teaser on the Spending screen, and only when there is something
  /// behind it. `Cut 0 ₫ a year` teaches the reader that the Savings screen
  /// has nothing on it.
  String cutAYear(String amount);
  String plansCostLessYearly(int count);

  /// The count beside `Payment sources` when there are none.
  String get none;

  // ---- after a save ----

  String savedNamed(String name);
  String savedUnderLater(String name);
  String savedUnderNext30(String name);
  String get askTrialEnds;
  String askBeforeCharges(String name);

  /// The sentence inside the permission sheet: the reminder, with real dates
  /// in it. This is what earns the tap, so it names the money and the card
  /// as well as the day.
  String askLineOnTheDay(String fireOn, String money, String from);
  String askLineBefore(
    String fireOn,
    String lead,
    String actBy,
    String money,
    String from,
  );
  String askMoneyThen(String amount);
  String askMoney(String amount);
  String askFrom(String source);
  String reminderSetOn(String date);

  // ---- the renewal-date nudge ----

  String get sawRenewalDate;
  String get enterDate;
  String savedConfirmedDate(String date);
  String get yearlyMentionedInReminder;
  String remindingAgainOn(String date);

  // ---- backup and restore ----

  String backedUp(String summary);
  String couldNotExport(String error);
  String restored(String summary);
  String couldNotRestore(String error);
  String couldNotOpenFile(String error);
  String get noCopyInICloud;
  String get signInToICloud;
  String couldNotReadICloud(String detail);
  String get unknownError;
  String takenOn(String date);

  // ---- things that can simply fail ----

  String get couldNotOpenPage;
  String couldNotScheduleTest(String error);
  String testSetInexact(String at, String zone);
  String testSet(String at, String zone);
}
