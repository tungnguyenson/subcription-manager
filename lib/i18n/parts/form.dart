/// The Add and Edit form, the service picker in front of it, the icon gallery,
/// and the two sheets that ask before replacing a list.
abstract class FormStrings {
  // ---- the picker, step one ----

  String get newItem;
  String get pickerStep;
  String get searchServices;
  String get pickerNoMatch;
  String get pickerNotInList;
  String get enterManually;
  String get scan;

  // ---- the form, step two ----

  String editingName(String name);
  String get editItem;
  String get untitledItem;

  String get fieldName;
  String get fieldNameHint;
  String get fieldCategory;
  String get fieldPickCategory;
  String get fieldPlan;
  String get fieldRepeats;
  String get fieldBillingCycle;
  String get fieldFreeTrial;
  String get fieldInFreeTrialNow;
  String get fieldRemindMe;
  String get fieldCost;
  String get fieldCostOptional;
  String get fieldNextPaymentDate;
  String get fieldLastPaymentOn;
  String get fieldChooseADate;
  String get fieldTapToOpenCalendar;
  String get fieldOpenSubscriptionPage;

  String get saveChanges;
  String get saveItem;

  /// The row offered under the search box when nothing in the catalogue
  /// matches: the user's own words, kept.
  String useCustomName(String typed);

  // ---- how long it repeats ----

  String get repeatsForever;
  String get stopsAfter;
  String get afterANumberOfPayments;
  String get onADate;
  String paymentsCount(int count);
  String get paymentsUnit;

  // ---- the cycle tray ----

  String get cycleOther;
  String get cycleEveryEllipsis;
  String get cycleOneOff;
  String get unitDays;
  String get unitWeeks;
  String get unitMonths;
  String get unitYears;
  String get every;

  /// The line under the interval chips, which stay open after a choice.
  /// Without it, the only way back to the list of intervals is to tap the
  /// answer you just gave, and nothing on screen says so.
  String currentlyCycle(String cycle);

  // ---- the plan grid ----

  String get planOtherAmount;
  String get planTypeItYourself;

  // ---- payment source ----

  String get paysFrom;
  String get optionalSuffix;
  String get sourceNotSet;
  String get sourceNew;
  String get sourceClearName;
  String get sourceHelp;

  // ---- the summary under the form ----

  String get summaryAmountNotSet;
  String get summaryNoDate;
  String summaryTrial(String date, String money);
  String summaryCharge(String money, String date);
  String summaryReminderOnTheDay(String date);
  String summaryReminderBefore(String lead, String date);

  // ---- the icon gallery ----

  String get searchIcons;
  String get galleryCategories;
  String get galleryServices;
  String galleryNoIcon(String query);
  String get galleryClearSearch;
  String get customEllipsis;

  // ---- the permission sheet ----

  String get addedToSubdock;
  String get turnOnReminders;
  String get notNow;
  String get onlyDueDateReminders;

  // ---- restoring ----

  String get restoreAskTitle;
  String get restoreAskReplaceTitle;
  String get restoreAskFrom;
  String restoreAskSummary(String incoming, String takenOn);
  String get restoreAskLost;
  String get restoreAskKeep;
  String get restoreAskConfirm;
  String get restoreAskReplace;

  // ---- the backup pages ----

  String get backupNow;
  String get backupActions;
  String get backupNever;
  String get backupCloudTitle;
  String get backupCloudIntro;
  String get backupStatus;
  String get backupLastCopy;
  String get backupLastExport;
  String get backupRestoreFromCloud;
  String get backupCloudRestoreNote;
  String get backupFileTitle;
  String get backupFileIntro;
  String get backupRestoreFromFile;
  String get backupFileRestoreNote;
  String get backupNothingSaved;
  String backupNothingSavedBody(int confirmed);
  String get backupStateSaved;
  String get backupStateSignedOut;
  String get backupStateFailed;
  String get backupStateWaiting;
  String get backupNoteWholeDevice;
  String get backupNotePerApp;
  String get backupNoteUnknown;
}
