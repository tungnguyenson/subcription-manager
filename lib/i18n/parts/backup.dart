/// What a backup file can be wrong about.
///
/// These reach the user through a toast on the restore path, at the one moment
/// where the app has been handed a file and cannot use it. Each names the
/// specific thing that was missing, because "could not restore" tells someone
/// staring at a file they have kept for a year exactly nothing.
abstract class BackupStrings {
  String get backupNotOurs;
  String get backupTooNew;

  /// `The file contains a category with no id.`
  String backupFileContains(String what);
  String get backupWhatCategoryNoId;
  String get backupWhatCategory;
  String get backupWhatSourceNoId;
  String get backupWhatItemNoId;
  String get backupWhatPaymentNoId;
  String get backupWhatPaymentNoItem;

  String backupItemHasNoDate(String name);
  String get backupPaymentHasNoDate;

  /// The shelf a book falls back to when the user has deleted every one, which
  /// the manager does not allow. It is here rather than in the category table
  /// because it is not a shipped row — it never reaches the database.
  /// What the file says on the tin: `12 items, 30 payments, 2 payment
  /// sources`. Shown on the sheet that asks before a restore, and again in the
  /// toast afterwards.
  String backupSummaryItems(int count);
  String backupSummaryPayments(int count);
  String backupSummarySources(int count);

  /// What joins those three. A comma in English, and a comma in Vietnamese
  /// too — but it is a translation decision either way, not a punctuation
  /// constant.
  String get listJoin;

  String get fallbackShelf;
}
