/// Settings, About, and the four screens reached from them: services, payment
/// sources, history, and the reminder defaults.
abstract class SettingsStrings {
  // ---- settings ----

  String get rowCurrency;
  String get rowLanguage;
  String get rowWidget;
  String get widgetNotYet;
  String get rowAppearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get themeSystemBody;
  String get themeLightBody;
  String get themeDarkBody;
  String get sectionBackup;
  String get sectionApp;
  String get rowAbout;
  String get rowICloud;
  String get rowFile;
  String get rowReminders;
  String get rowPaymentSources;
  String get exportABackup;

  /// The banner that says the app could not schedule everything it was asked
  /// to. Surfaced, never buried: the phone drops the furthest-out reminders
  /// silently, and there is no other way to find out.
  String droppedRemindersTitle(int count);
  String droppedRemindersBody(int budget, String names);

  // ---- about ----

  String get aboutTitle;
  String get aboutLead;
  String get aboutThisBuild;
  String get aboutVersion;
  String get aboutBuild;
  String get aboutWhatItDoes;
  String get aboutAccount;
  String get aboutServer;
  String get aboutNone;
  String get aboutYourList;
  String get aboutOnThisPhone;
  String get aboutPrices;

  // ---- payment sources ----

  String get sourcesTitle;
  String get sourcesLead;
  String get sourcesNewItems;
  String get sourcesStartsOn;
  String get sourcesYours;
  String get sourcesEmpty;
  String get sourcesAddOne;
  String get sourcesAddTitle;
  String get sourcesAddLead;
  String get sourcesNameHint;
  String sourcesDefaultUsage(String usage);
  String get sourcesRemove;
  String get sourcesNotUsedYet;
  String sourcesItemCount(int count);

  // ---- all services ----

  String get servicesLead;
  String get servicesEmpty;
  String get servicesAdd;
  String servicesRemindersFor(String name);
  String get servicesOff;
  String servicesTrialEnds(String date);
  String servicesNext(String date);

  // ---- history ----

  String get historyTitle;
  String get historyAll;
  String get historyPaid;
  String get historyMissed;

  /// `July 2025` once the year stops being this one. A bare month name on a
  /// two-year-old row reads as this year's.
  String historyMonthWithYear(String month, int year);

  String historyClosedClean(int count);
  String historyClosedWithMissed(int count, int missed);
  String historyClosedOnTime(int count);
  String historyClosedLate(int count);
  String get historyEmptyAll;
  String get historyEmptyPaid;

  /// An empty Missed list is the one result on this screen that is good news,
  /// so it says what it means rather than "nothing here".
  String get historyEmptyMissed;

  String get historyVerbMissed;
  String get historyVerbHandled;
  String get historyVerbPaid;
  String get historyVerbRenewed;

  // ---- reminders, for one item and by default ----

  String get remindersDefaultSchedule;
  String get remindersSchedule;
  String get remindersTimeOfDay;
  String get remindersSendAt;
  String get remindersChannels;
  String get remindersPush;
  String get remindersSendTest;
  String get remindersTurnOffForItem;
  String get remindersNotificationsOff;

  /// Said out loud when the phone will not give the app an exact alarm: the
  /// reminders still arrive, but when the system next wakes rather than at the
  /// minute set above.
  String get remindersInexact;
}
