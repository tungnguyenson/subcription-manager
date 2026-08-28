import 'package:meta/meta.dart';

import 'package:subdock/data/backup_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/i18n.dart';

/// Where a copy of the list ends up without the user doing anything.
///
/// The answer genuinely differs between the two platforms, and so does its
/// catch, which is why this is an enum rather than one sentence. iOS keeps the
/// file but will only give it back with the whole phone; Android hands it to
/// the next phone on its own but will not say whether it ever ran.
///
/// This is not the same case as the reminder budget, where the app prints one
/// number on both platforms because it has no figure it can stand behind for
/// the second one. Here the app knows two different true things, and saying
/// only one of them would be the inaccurate choice.
enum DeviceBackup {
  /// In the iPhone's own backup. Restoring it means restoring the whole phone.
  wholeDeviceOnly,

  /// In the phone's Google backup, and it moves to a new phone by itself. The
  /// app cannot check whether it has actually run.
  perAppUnverifiable,

  /// Nothing is known. Anywhere that is not iOS or Android.
  unknown,
}

/// Everything the screen needs to know about the cloud channel at once.
///
/// One parameter rather than four, because they are always read together and
/// three of them are meaningless without the first. Passing them separately
/// invites a call site that names the state and forgets the account, which
/// would print a page about a copy without saying whose it is.
@immutable
class CloudChannel {
  final CloudKind kind;

  /// How the last attempt went.
  final CloudResult result;

  /// Whether the user still has to attach an account.
  final bool needsAccount;

  /// The account copies go to, where there is one to name.
  final String? account;

  /// Whether a write is in the air right now.
  ///
  /// Only ever reaches the screen in one situation, and that situation used to
  /// read as a lie: the seconds between connecting an account and the first
  /// copy landing. The row said `Never` throughout, which is the same thing it
  /// says to somebody whose backup is not happening at all.
  final bool writing;

  const CloudChannel({
    this.kind = CloudKind.none,
    this.result = CloudResult.unsupported,
    this.needsAccount = false,
    this.account,
    this.writing = false,
  });

  /// A platform the app writes no cloud copy for.
  static const none = CloudChannel();
}

/// One backup channel, opened from Settings.
///
/// Wording lives here rather than on the screen so the two channels can be
/// read side by side and told apart in a test. They are genuinely different
/// promises -- one the app keeps by itself, one the user keeps by hand -- and
/// the copy is most of what says so.
@immutable
class BackupPage {
  final String title;

  /// What this channel is, in one sentence.
  final String intro;

  /// Label and value rows: what it is doing, when it last worked.
  final List<(String, String)> facts;

  /// The label on the button that writes a copy, or null where the user does
  /// not write one by hand.
  final String? backUpLabel;

  /// The label on the button that writes the list out as a spreadsheet, or
  /// null on a channel that has no such thing. Separate from [backUpLabel]
  /// because the two files are not versions of each other: one comes back and
  /// one does not.
  final String? exportCsvLabel;

  final String? restoreLabel;

  /// The label that attaches an account, on a channel that needs one and does
  /// not have one yet. Null on iCloud, which never asks.
  final String? connectLabel;

  /// The label that detaches it again. Null until one is attached: an app that
  /// offers to disconnect an account nobody connected is describing machinery
  /// rather than answering a question.
  final String? disconnectLabel;

  /// The caveat under the actions, where this channel has one.
  final String? note;

  const BackupPage({
    required this.title,
    required this.intro,
    this.facts = const [],
    this.backUpLabel,
    this.exportCsvLabel,
    this.restoreLabel,
    this.connectLabel,
    this.disconnectLabel,
    this.note,
  });
}

/// What the Settings screen shows about backups.
@immutable
class BackupView {
  /// `Never`, or the date of the newest copy on either channel.
  final String lastBackup;

  /// Whether Settings carries an iCloud row at all.
  ///
  /// False on Android, where the system already carries the database to the
  /// next phone and the app adds nothing. A row reading `Not available` there
  /// would report a gap that does not exist. What the row then *says* is
  /// [cloudLine], the same as the file row: one place decides the wording, so
  /// the two rows cannot drift into describing themselves differently.
  final bool hasCloud;

  /// What that row is called.
  ///
  /// Here rather than hardcoded on the Settings screen: the row said `iCloud`
  /// on an Android phone the moment Drive started reporting itself as
  /// supported, which named a service that does not exist on the device and
  /// cannot be signed in to from it.
  final String cloudLabel;

  /// What the two Settings rows say on their right-hand side.
  ///
  /// A date when there is one, and the problem instead when there is one of
  /// those: `Sign in to iCloud` beside a date from June would be the app
  /// reporting a copy it is no longer keeping.
  final String cloudLine;
  final String fileLine;

  /// The sentence under the backup card. Never null: that the app has no
  /// account and no server is true on every platform, and it is the fact the
  /// user cannot learn from any other screen.
  final String note;

  /// Title and body for the banner, or null when there is nothing to warn
  /// about. Both are set together or neither is.
  final String? warningTitle;
  final String? warningBody;

  const BackupView({
    required this.lastBackup,
    required this.note,
    this.hasCloud = false,
    this.cloudLabel = '',
    this.cloudLine = '',
    this.fileLine = '',
    this.warningTitle,
    this.warningBody,
  });

  bool get hasWarning => warningTitle != null;
}

/// Turns the list and the last export into what Settings puts on screen.
///
/// Pure, so the wording and the threshold are testable without a database or a
/// device. The platform arrives as a [DeviceBackup] rather than being read
/// here, for the same reason.
abstract final class BackupPresenter {
  static BackupView build({
    required List<TrackedItem> items,
    required LastBackups saved,
    required DeviceBackup device,
    CloudChannel cloud = CloudChannel.none,
  }) {
    final newest = _newest(saved);
    final problem = _cloudProblem(cloud);
    final exposed = unsavedDates(items, saved);

    return BackupView(
      lastBackup: newest == null ? S.t.backupNever : MoneyFormat.date(newest),
      note: _note(device),
      hasCloud: cloud.result.state != CloudState.unsupported,
      cloudLabel: cloud.kind == CloudKind.drive
          ? S.t.backupDriveTitle
          : S.t.rowICloud,
      // The problem outranks the date. A row reading `25/06/2026` beside an
      // iCloud that has been signed out since July is the app reporting a copy
      // it stopped keeping.
      cloudLine: problem ?? _date(saved.cloud),
      fileLine: _date(saved.file),
      // Only when there is something to lose that no copy is holding. A
      // warning that fires on an empty list is a warning the user learns to
      // scroll past before the day it means something.
      //
      // Two wordings, because the reader is in two different situations. With
      // no copy at all the answer is to make one; with a copy that predates
      // these dates the answer is to take a fresh one, and saying "nothing has
      // been backed up" to someone holding a file from May would be false.
      warningTitle: exposed == 0
          ? null
          : (saved.any ? S.t.backupStale : S.t.backupNothingSaved),
      warningBody: exposed == 0
          ? null
          : (saved.any
                ? S.t.backupStaleBody(exposed)
                : S.t.backupNothingSavedBody(exposed)),
    );
  }

  /// The iCloud page, or null where iCloud is not a thing on this device.
  static BackupPage? cloudPage({
    required LastBackups saved,
    required CloudChannel cloud,
  }) {
    if (cloud.result.state == CloudState.unsupported) return null;

    final drive = cloud.kind == CloudKind.drive;

    // Nothing to report about a copy nobody has agreed to keep yet. The page
    // is one sentence and one button at this point, because a `Last saved:
    // Never` row would answer a question the user has not been allowed to ask.
    if (cloud.needsAccount) {
      return BackupPage(
        title: S.t.backupDriveTitle,
        intro: S.t.backupDriveIntro,
        connectLabel: S.t.backupDriveConnect,
        note: S.t.backupDriveConnectNote,
      );
    }

    return BackupPage(
      title: drive ? S.t.backupDriveTitle : S.t.backupCloudTitle,
      intro: drive ? S.t.backupDriveIntro : S.t.backupCloudIntro,
      // One row, not a status over a date. `Saved` and a date underneath say
      // the same thing twice, and the date says it with evidence: a moment the
      // user can check against what they remember doing. The status word only
      // earned its place while it could contradict the row below it, which is
      // exactly the pairing that has to stop happening.
      //
      // The failures keep the row instead of the date, because they are not a
      // state the date could describe. `27/08/2026 at 14:08` beside an iCloud
      // signed out since then is the app reporting a copy it stopped keeping.
      facts: [
        // Whose copy, before when. A user with two Google accounts has two
        // different backups, and no date tells them which one they are
        // looking at.
        if (cloud.account case final name?) (S.t.backupDriveAccount, name),
        (
          S.t.backupLastSaved,
          // A problem outranks everything: a date beside an account that has
          // been revoked is the app reporting a copy it stopped keeping.
          // Then the copy's own moment, and only where there is neither does
          // the write in flight get to speak, which is the first copy after
          // connecting and nothing else.
          _cloudProblem(cloud) ??
              (saved.cloudAt == null && cloud.writing
                  ? S.t.backupFirstCopy
                  : _moment(saved.cloudAt)),
        ),
      ],
      // Nothing to press for the copy itself. The app writes on its own, and a
      // button here would suggest it does not.
      restoreLabel: drive
          ? S.t.backupRestoreFromDrive
          : S.t.backupRestoreFromCloud,
      disconnectLabel: drive ? S.t.backupDriveDisconnect : null,
      note: drive ? S.t.backupDriveRestoreNote : S.t.backupCloudRestoreNote,
    );
  }

  static BackupPage filePage({required LastBackups saved}) => BackupPage(
    title: S.t.backupFileTitle,
    intro: S.t.backupFileIntro,
    facts: [(S.t.backupLastExport, _date(saved.file))],
    backUpLabel: S.t.exportABackup,
    exportCsvLabel: S.t.backupExportCsv,
    restoreLabel: S.t.backupRestoreFromFile,
    note: S.t.backupFileRestoreNote,
  );

  static String _date(LocalDate? on) =>
      on == null ? S.t.backupNever : MoneyFormat.date(on);

  /// The day and the hour, joined by the language rather than by a comma:
  /// English puts `at` between them and Vietnamese puts `lúc`.
  static String _moment(LocalDateTime? at) => at == null
      ? S.t.backupNever
      : S.t.backupCopyAt(MoneyFormat.date(at.date), at.time.toString());

  static LocalDate? _newest(LastBackups saved) =>
      switch ((saved.file, saved.cloud)) {
        (final LocalDate f, final LocalDate c) => LocalDate.max(f, c),
        (final LocalDate f, null) => f,
        (null, final LocalDate c) => c,
        _ => null,
      };

  /// The cloud states worth showing instead of a date, and null for the rest.
  ///
  /// Only the two the user can act on. A run that has not written yet says
  /// `Never`, which is what it is: nothing is up there. `Waiting for a change`
  /// used to sit here and it answered a question nobody asked, since the row
  /// is read to find out whether a copy exists.
  /// The wording differs by cloud because the fix does. `Sign in to iCloud`
  /// sends an Android user to a settings page that does not exist on their
  /// phone.
  static String? _cloudProblem(
    CloudChannel cloud,
  ) => switch (cloud.result.state) {
    // Named so the user knows the fix is theirs and where it lives. "Failed"
    // would send them looking for a bug in the app.
    CloudState.signedOut =>
      cloud.kind == CloudKind.drive
          ? S.t.backupStateReconnect
          : S.t.backupStateSignedOut,
    CloudState.failed => S.t.backupStateFailed,
    // Only reachable on a page that is not the connect page: the account was
    // there and has gone since. Reads the same as never having connected,
    // which is what it is.
    CloudState.disconnected => S.t.backupStateDisconnected,
    _ => null,
  };

  /// How many dates in the list cost the user a phone call to obtain.
  ///
  /// The threshold for warning at all, and the number the warning quotes. Not
  /// a count of items: a list of thirty things typed from memory is annoying
  /// to retype, while three dates read off a provider's own record mean three
  /// calls to a hotline. [DateSource] already records which is which, so the
  /// app can measure the cost of losing the list rather than its length.
  ///
  /// Archived items do not count. They are out of the user's way already, and
  /// counting them would keep a warning alive over a list nobody is using.
  static int confirmedDates(List<TrackedItem> items) =>
      items.where((item) => item.isCostlyToRebuild).length;

  /// How many of those dates are in no copy anywhere.
  ///
  /// This is the number the warning quotes, and it is a set difference rather
  /// than a comparison of counts. Someone who backs up five dates, deletes one
  /// and confirms another still has five, while one of the five is in nothing.
  /// Counts cannot see that.
  ///
  /// Returns zero while [LastBackups.coverageKnown] is false. A copy written
  /// before the app kept this record might well hold every one of these dates,
  /// and accusing it of being short is the same overclaiming the rest of this
  /// screen exists to avoid. The next write settles it.
  static int unsavedDates(List<TrackedItem> items, LastBackups saved) {
    if (saved.any && !saved.coverageKnown) return 0;
    final covered = saved.covered;
    return items
        .where((item) => item.isCostlyToRebuild && !covered.contains(item.id))
        .length;
  }

  /// Answers section 11.2 of the product spec: say in the interface whether
  /// the database is in the device's own backup, so the user knows what they
  /// are trusting.
  static String _note(DeviceBackup device) => switch (device) {
    DeviceBackup.wholeDeviceOnly => S.t.backupNoteWholeDevice,
    DeviceBackup.perAppUnverifiable => S.t.backupNotePerApp,
    DeviceBackup.unknown => S.t.backupNoteUnknown,
  };
}
