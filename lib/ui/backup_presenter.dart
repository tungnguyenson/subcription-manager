import 'package:meta/meta.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/money_format.dart';

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

/// What the Settings screen shows about backups.
@immutable
class BackupView {
  /// `Never`, or the date of the last export.
  final String lastBackup;

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
    required LocalDate? lastSavedOn,
    required DeviceBackup device,
  }) {
    final confirmed = confirmedDates(items);

    return BackupView(
      lastBackup: lastSavedOn == null ? 'Never' : MoneyFormat.date(lastSavedOn),
      note: _note(device),
      // Only when there is something to lose *and* nothing has been saved.
      // A warning that fires on an empty list is a warning the user learns to
      // scroll past before the day it means something.
      warningTitle: lastSavedOn == null && confirmed > 0
          ? 'Nothing has been backed up'
          : null,
      warningBody: lastSavedOn == null && confirmed > 0
          ? 'Your list is only on this phone, and '
                '${confirmed == 1 ? "one of its dates was" : "$confirmed of "
                          "its dates were"} confirmed with a provider. '
                'Removing the app removes them.'
          : null,
    );
  }

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

  /// Answers section 11.2 of the product spec: say in the interface whether
  /// the database is in the device's own backup, so the user knows what they
  /// are trusting.
  static String _note(DeviceBackup device) => switch (device) {
    DeviceBackup.wholeDeviceOnly =>
      'Subdock has no account and no server. Your list is in this '
          "iPhone's own backup, but iOS restores that only by restoring the "
          'whole phone.',
    DeviceBackup.perAppUnverifiable =>
      'Subdock has no account and no server. Your list is in this '
          "phone's Google backup and moves to a new phone by itself, but "
          'Subdock cannot check whether that backup has ever run.',
    DeviceBackup.unknown =>
      'Subdock has no account and no server. What you see in the app is the '
          'only copy, and removing the app removes it.',
  };
}
