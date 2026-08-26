import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/ui/backup_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item({
    String id = 'netflix',
    DateSource dateSource = DateSource.userEstimated,
    ItemState state = ItemState.active,
  }) => TrackedItem(
    id: id,
    name: id,
    categoryId: 'STREAMING',
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-09-01'),
    dateSource: dateSource,
    state: state,
  );

  BackupView build({
    List<TrackedItem> items = const [],
    LocalDate? lastSavedOn,
    LocalDate? lastCloudOn,
    DeviceBackup device = DeviceBackup.wholeDeviceOnly,
    CloudResult cloud = CloudResult.unsupported,
  }) => BackupPresenter.build(
    items: items,
    saved: LastBackups(file: lastSavedOn, cloud: lastCloudOn),
    device: device,
    cloud: cloud,
  );

  group('the last backup row', () {
    test('says Never rather than leaving the row blank', () {
      expect(build().lastBackup, 'Never');
    });

    test('shows the date once one has been taken', () {
      expect(build(lastSavedOn: d('2026-08-25')).lastBackup, '25/08/2026');
    });
  });

  // The threshold is the cost of rebuilding the list, not its length. A date
  // read off a provider's own record cost a phone call; thirty typed from
  // memory did not.
  group('when the banner fires', () {
    test('not on an empty list', () {
      expect(build().hasWarning, isFalse);
    });

    test('not on a list of dates the user typed from memory', () {
      expect(
        build(
          items: [
            item(),
            item(id: 'spotify'),
          ],
        ).hasWarning,
        isFalse,
      );
    });

    test('on a single date that was confirmed with a provider', () {
      final view = build(items: [item(dateSource: DateSource.userConfirmed)]);

      expect(view.hasWarning, isTrue);
      expect(view.warningBody, contains('one of its dates was'));
    });

    test('never once a backup exists, however old', () {
      final view = build(
        items: [item(dateSource: DateSource.userConfirmed)],
        lastSavedOn: d('2020-01-01'),
      );

      expect(view.hasWarning, isFalse);
    });

    // The number is what makes the warning mean something. "Your list is only
    // on this phone" is a shrug; "three of these cost you a phone call" is not.
    test('it counts the confirmed dates, not the items', () {
      final view = build(
        items: [
          item(id: 'a', dateSource: DateSource.userConfirmed),
          item(id: 'b', dateSource: DateSource.userConfirmed),
          item(id: 'c'),
          item(id: 'd', dateSource: DateSource.extracted),
        ],
      );

      expect(view.warningBody, contains('2 of its dates were'));
    });

    // They are out of the user's way already. Counting them keeps a warning
    // alive over a list nobody is looking at.
    test('an archived item does not keep the warning alive', () {
      final view = build(
        items: [
          item(dateSource: DateSource.userConfirmed, state: ItemState.archived),
        ],
      );

      expect(view.hasWarning, isFalse);
    });

    // A cancelled subscription still running is still on the list, and its
    // date still cost a call.
    test('a cancelled but still running item does count', () {
      final view = build(
        items: [
          item(
            dateSource: DateSource.userConfirmed,
            state: ItemState.cancelledStillActive,
          ),
        ],
      );

      expect(view.hasWarning, isTrue);
    });
  });

  // There is no switch to report here. The app writes to iCloud whenever it
  // can, so the only thing worth putting on screen is whether that worked.
  group('the iCloud row', () {
    test('is absent where the app writes to no cloud at all', () {
      expect(build().cloud, isNull);
    });

    test('says it saved once a write landed', () {
      expect(build(cloud: const CloudResult(CloudState.saved)).cloud, 'Saved');
    });

    // The fix is the user's and it lives in system settings, so the row sends
    // them there. "Failed" would send them hunting for a bug in the app.
    test('a signed-out account is named as the thing to fix', () {
      expect(
        build(cloud: const CloudResult(CloudState.signedOut)).cloud,
        'Sign in to iCloud',
      );
    });

    test('an unexplained failure still says something went wrong', () {
      expect(
        build(cloud: const CloudResult(CloudState.failed, detail: 'x')).cloud,
        'Could not save',
      );
    });

    test('before the first attempt it does not claim to have saved', () {
      final cloud = build(cloud: CloudResult.idle).cloud;

      expect(cloud, isNotNull);
      expect(cloud, isNot('Saved'));
    });

    // The date belongs to a file that exists. A cloud write that failed must
    // not leave one behind, which is enforced in app.dart; here the row simply
    // has to be able to say both things at once.
    test('a failed write can sit beside a date from an earlier one', () {
      final view = build(
        lastSavedOn: d('2026-08-25'),
        cloud: const CloudResult(CloudState.signedOut),
      );

      expect(view.lastBackup, '25/08/2026');
      expect(view.cloud, 'Sign in to iCloud');
    });
  });

  // Section 11.2 of the product spec: say in the interface whether the
  // database is in the device's own backup, so the user knows what they are
  // trusting.
  group('what the device does on its own', () {
    test('every platform says there is no account and no server', () {
      for (final device in DeviceBackup.values) {
        expect(
          build(device: device).note,
          contains('no account and no server'),
          reason: '$device',
        );
      }
    });

    // The catch is the point. Saying only "it is backed up" would leave the
    // user believing they can get this one app back, which is the belief that
    // cost thirty phone calls on 25/08/2026.
    test('iOS names the catch: only the whole phone comes back', () {
      final note = build(device: DeviceBackup.wholeDeviceOnly).note;

      expect(note, contains("iPhone's own backup"));
      expect(note, contains('restoring the whole phone'));
    });

    test('Android names its own, different catch', () {
      final note = build(device: DeviceBackup.perAppUnverifiable).note;

      expect(note, contains('moves to a new phone by itself'));
      expect(
        note,
        contains('cannot check'),
        reason: 'Auto Backup gives the app no way to know it ran',
      );
    });

    // Two platforms, two different true answers, so two different sentences.
    // This is deliberately unlike the reminder budget, which prints one number
    // everywhere because the app has no second figure it can stand behind.
    test('the two platforms do not share a sentence', () {
      expect(
        build(device: DeviceBackup.wholeDeviceOnly).note,
        isNot(build(device: DeviceBackup.perAppUnverifiable).note),
      );
    });

    // Anywhere that is not iOS or Android, the app knows nothing about a
    // device backup and must not imply one.
    test('an unknown platform claims no device backup at all', () {
      final note = build(device: DeviceBackup.unknown).note;

      expect(note, contains('only copy'));
      expect(note, isNot(contains('backup and moves')));
    });
  });
}
