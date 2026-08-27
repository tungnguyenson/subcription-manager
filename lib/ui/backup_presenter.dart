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

  final String? restoreLabel;

  /// The caveat under the actions, where this channel has one.
  final String? note;

  const BackupPage({
    required this.title,
    required this.intro,
    this.facts = const [],
    this.backUpLabel,
    this.restoreLabel,
    this.note,
  });
}

/// What the Settings screen shows about backups.
@immutable
class BackupView {
  /// `Never`, or the date of the newest copy on either channel.
  final String lastBackup;

  /// What the iCloud row says, or null where there is no such row.
  ///
  /// Null on Android, where the system already carries the database to the
  /// next phone and the app adds nothing. A row reading `Not available` there
  /// would report a gap that does not exist.
  final String? cloud;

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
    this.cloud,
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
    CloudResult cloud = CloudResult.unsupported,
  }) {
    final confirmed = confirmedDates(items);
    final newest = _newest(saved);
    final problem = _cloudProblem(cloud);

    return BackupView(
      lastBackup: newest == null ? S.t.backupNever : MoneyFormat.date(newest),
      note: _note(device),
      cloud: _cloud(cloud),
      // The problem outranks the date. A row reading `25/06/2026` beside an
      // iCloud that has been signed out since July is the app reporting a copy
      // it stopped keeping.
      cloudLine: problem ?? _date(saved.cloud),
      fileLine: _date(saved.file),
      // Only when there is something to lose *and* nothing has been saved
      // anywhere. A warning that fires on an empty list is a warning the user
      // learns to scroll past before the day it means something.
      warningTitle: !saved.any && confirmed > 0 ? S.t.backupNothingSaved : null,
      warningBody: !saved.any && confirmed > 0
          ? S.t.backupNothingSavedBody(confirmed)
          : null,
    );
  }

  /// The iCloud page, or null where iCloud is not a thing on this device.
  static BackupPage? cloudPage({
    required LastBackups saved,
    required CloudResult cloud,
  }) {
    final state = _cloud(cloud);
    if (state == null) return null;

    return BackupPage(
      title: S.t.backupCloudTitle,
      intro: S.t.backupCloudIntro,
      facts: [
        (S.t.backupStatus, state),
        (S.t.backupLastCopy, _date(saved.cloud)),
      ],
      // Nothing to press for the copy itself. The app writes on its own, and a
      // button here would suggest it does not.
      restoreLabel: S.t.backupRestoreFromCloud,
      note: S.t.backupCloudRestoreNote,
    );
  }

  static BackupPage filePage({required LastBackups saved}) => BackupPage(
    title: S.t.backupFileTitle,
    intro: S.t.backupFileIntro,
    facts: [(S.t.backupLastExport, _date(saved.file))],
    backUpLabel: S.t.exportABackup,
    restoreLabel: S.t.backupRestoreFromFile,
    note: S.t.backupFileRestoreNote,
  );

  static String _date(LocalDate? on) =>
      on == null ? S.t.backupNever : MoneyFormat.date(on);

  static LocalDate? _newest(LastBackups saved) =>
      switch ((saved.file, saved.cloud)) {
        (final LocalDate f, final LocalDate c) => LocalDate.max(f, c),
        (final LocalDate f, null) => f,
        (null, final LocalDate c) => c,
        _ => null,
      };

  /// The cloud states worth showing instead of a date, and null for the rest.
  static String? _cloudProblem(CloudResult result) => switch (result.state) {
    CloudState.signedOut => S.t.backupStateSignedOut,
    CloudState.failed => S.t.backupStateFailed,
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
  static int confirmedDates(List<TrackedItem> items) => items
      .where(
        (item) =>
            item.dateSource == DateSource.userConfirmed &&
            item.state != ItemState.archived,
      )
      .length;

  /// What the iCloud row reads.
  ///
  /// Says what is true right now rather than what the setting is. There is no
  /// switch here to report: the app writes to iCloud whenever it can, and the
  /// only thing worth putting on screen is whether that is working. `On` beside
  /// an account that is signed out would be the exact lie this app is built to
  /// avoid.
  static String? _cloud(CloudResult result) => switch (result.state) {
    CloudState.unsupported => null,
    CloudState.saved => S.t.backupStateSaved,
    // Named so the user knows the fix is theirs and where it lives. "Failed"
    // would send them looking for a bug in the app.
    CloudState.signedOut => S.t.backupStateSignedOut,
    CloudState.failed => S.t.backupStateFailed,
    CloudState.idle => S.t.backupStateWaiting,
    // Only ever comes back from a read, and this row reports the last write.
    // Left explicit rather than folded into a wildcard so that adding a state
    // to [CloudState] stays a compile error here.
    CloudState.missing => S.t.backupStateWaiting,
  };

  /// Answers section 11.2 of the product spec: say in the interface whether
  /// the database is in the device's own backup, so the user knows what they
  /// are trusting.
  static String _note(DeviceBackup device) => switch (device) {
    DeviceBackup.wholeDeviceOnly => S.t.backupNoteWholeDevice,
    DeviceBackup.perAppUnverifiable => S.t.backupNotePerApp,
    DeviceBackup.unknown => S.t.backupNoteUnknown,
  };
}
