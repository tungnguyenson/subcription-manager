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

  /// The record keeps the hour; these cases are about the day, so they all
  /// share one. The hour only reaches the screen on the iCloud page, which has
  /// its own group below.
  LocalDateTime? at(LocalDate? on) =>
      on == null ? null : LocalDateTime(on, const LocalTime(9, 30));

  BackupView build({
    List<TrackedItem> items = const [],
    LocalDate? lastSavedOn,
    LocalDate? lastCloudOn,
    Set<String>? fileCovered,
    Set<String>? cloudCovered,
    DeviceBackup device = DeviceBackup.wholeDeviceOnly,
    CloudResult cloud = CloudResult.unsupported,
    CloudKind kind = CloudKind.icloud,
  }) => BackupPresenter.build(
    items: items,
    saved: LastBackups(
      fileAt: at(lastSavedOn),
      cloudAt: at(lastCloudOn),
      fileCovered: fileCovered,
      cloudCovered: cloudCovered,
    ),
    device: device,
    cloud: CloudChannel(kind: kind, result: cloud),
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

    // A copy written by a build that did not record what it held. The app
    // cannot tell whether that copy covers this date, so it says nothing
    // rather than accusing a file that may well be complete.
    test('quiet beside a copy that never said what it held', () {
      final view = build(
        items: [item(dateSource: DateSource.userConfirmed)],
        lastSavedOn: d('2020-01-01'),
      );

      expect(view.hasWarning, isFalse);
    });

    test('quiet once a copy is known to hold the date', () {
      final view = build(
        items: [item(id: 'a', dateSource: DateSource.userConfirmed)],
        lastSavedOn: d('2026-08-25'),
        fileCovered: {'a'},
      );

      expect(view.hasWarning, isFalse);
    });

    // The point of the whole record. A backup from before the date exists is
    // a backup that cannot give it back, however recent it looks.
    test('speaks up for a date added after the newest copy', () {
      final view = build(
        items: [
          item(id: 'a', dateSource: DateSource.userConfirmed),
          item(id: 'b', dateSource: DateSource.userConfirmed),
        ],
        lastSavedOn: d('2026-08-25'),
        fileCovered: {'a'},
      );

      expect(view.hasWarning, isTrue);
      expect(view.warningTitle, 'Newer dates are not backed up');
      expect(view.warningBody, contains('One date'));
    });

    // The case a count cannot see: one out, one in, total unchanged.
    test('a swap that keeps the count still leaves a date exposed', () {
      final view = build(
        items: [item(id: 'b', dateSource: DateSource.userConfirmed)],
        lastSavedOn: d('2026-08-25'),
        fileCovered: {'a'},
      );

      expect(view.hasWarning, isTrue);
    });

    // A file from May still holds what it held, whatever iCloud has done
    // since. Asking only the newest copy would warn about a date the user is
    // holding in their hand.
    test('a date in either copy counts as covered', () {
      final view = build(
        items: [
          item(id: 'a', dateSource: DateSource.userConfirmed),
          item(id: 'b', dateSource: DateSource.userConfirmed),
        ],
        lastSavedOn: d('2026-05-01'),
        lastCloudOn: d('2026-08-25'),
        fileCovered: {'a'},
        cloudCovered: {'b'},
      );

      expect(view.hasWarning, isFalse);
    });

    // Two situations, two answers. Telling someone holding a file from May
    // that nothing has been backed up is false.
    test('with no copy at all it says so, rather than calling one stale', () {
      final view = build(items: [item(dateSource: DateSource.userConfirmed)]);

      expect(view.warningTitle, 'Nothing has been backed up');
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
          item(dateSource: DateSource.userConfirmed, state: ItemState.inactive),
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
      expect(build().hasCloud, isFalse);
    });

    test('is there wherever the app writes to a cloud at all', () {
      expect(build(cloud: CloudResult.idle).hasCloud, isTrue);
    });

    // The row said `iCloud` on an Android phone the moment Drive started
    // reporting itself as supported, naming a service that is not on the
    // device and cannot be signed in to from it.
    test('the row is named after the cloud this platform actually uses', () {
      expect(build(cloud: CloudResult.idle).cloudLabel, 'iCloud');
      expect(
        build(cloud: CloudResult.idle, kind: CloudKind.drive).cloudLabel,
        'Google Drive',
      );
    });

    test('carries the date of the last write that landed', () {
      expect(
        build(
          lastCloudOn: d('2026-08-25'),
          cloud: const CloudResult(CloudState.saved),
        ).cloudLine,
        '25/08/2026',
      );
    });

    // The fix is the user's and it lives in system settings, so the row sends
    // them there. "Failed" would send them hunting for a bug in the app.
    test('a signed-out account is named as the thing to fix', () {
      expect(
        build(cloud: const CloudResult(CloudState.signedOut)).cloudLine,
        'Sign in to iCloud',
      );
    });

    test('an unexplained failure still says something went wrong', () {
      expect(
        build(cloud: const CloudResult(CloudState.failed, detail: 'x'))
            .cloudLine,
        'Could not save',
      );
    });

    // Nothing is up there yet, and that is a plain answer rather than a state
    // of the machinery. `Waiting for a change` used to sit here and it answered
    // a question nobody asked.
    test('before the first attempt it does not claim to have saved', () {
      expect(build(cloud: CloudResult.idle).cloudLine, 'Never');
    });

    // The problem outranks the date: a date from June beside an iCloud signed
    // out since July is the app reporting a copy it stopped keeping.
    test('a failure hides a date the app can no longer stand behind', () {
      final view = build(
        lastCloudOn: d('2026-06-25'),
        cloud: const CloudResult(CloudState.signedOut),
      );

      expect(view.cloudLine, 'Sign in to iCloud');
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

    // The note used to end on the app not being able to check whether the
    // system backup ever ran. That was the honest answer while there was
    // nothing better; now the Drive row above it carries a real date, and a
    // second, vaguer backup story competing with it just makes the reader
    // trust the worse one. It still says the system copy exists, because it
    // does, and that the app has no hand in it.
    test('Android separates its own copies from the system one', () {
      final note = build(device: DeviceBackup.perAppUnverifiable).note;

      expect(note, contains('to a new phone'));
      expect(
        note,
        contains('no say'),
        reason: 'Auto Backup is not a channel the app manages',
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

  group('the iCloud page', () {
    BackupPage page({
      LocalDateTime? copiedAt,
      CloudResult cloud = const CloudResult(CloudState.saved),
      CloudKind kind = CloudKind.icloud,
      bool needsAccount = false,
      String? account,
    }) => BackupPresenter.cloudPage(
      saved: LastBackups(cloudAt: copiedAt),
      cloud: CloudChannel(
        kind: kind,
        result: cloud,
        needsAccount: needsAccount,
        account: account,
      ),
    )!;

    final copied = LocalDateTime(d('2026-08-27'), const LocalTime(12, 52));

    // One row, not a status over a date. The pair used to be able to contradict
    // each other -- `Saved` above `Never` -- and even when they agreed the
    // status word only repeated what the date already proved.
    test('there is one row about the copy, and it is the date', () {
      expect(page(copiedAt: copied).facts, [
        ('Last saved', '27/08/2026 at 12:52'),
      ]);
    });

    // Nobody presses anything to make this write happen, so a bare day cannot
    // tell the copy written after the edit just made from the one written at
    // breakfast.
    test('the row names the hour, not just the day', () {
      expect(page(copiedAt: copied).facts.single.$2, contains('12:52'));
    });

    // Before the first write lands there is genuinely nothing up there.
    test('a run that has not written yet says Never', () {
      expect(page(cloud: CloudResult.idle).facts.single.$2, 'Never');
    });

    // The one thing a date cannot describe. A moment from this morning beside
    // an account signed out since then reports a copy the app stopped keeping.
    test('a signed-out account takes the row instead of the date', () {
      expect(
        page(
          copiedAt: copied,
          cloud: const CloudResult(CloudState.signedOut),
        ).facts.single.$2,
        'Sign in to iCloud',
      );
    });

    // A platform the app writes no cloud copy for has no row and no page.
    test('there is no page where the app writes to no cloud', () {
      expect(
        BackupPresenter.cloudPage(
          saved: LastBackups.none,
          cloud: CloudChannel.none,
        ),
        isNull,
      );
    });
  });

  // Drive is the same channel with one thing iCloud does not have: an account
  // the user attaches, and can attach the wrong one.
  group('the Drive page', () {
    BackupPage page({
      LocalDateTime? copiedAt,
      CloudResult cloud = const CloudResult(CloudState.saved),
      bool needsAccount = false,
      String? account,
      bool writing = false,
    }) => BackupPresenter.cloudPage(
      saved: LastBackups(cloudAt: copiedAt),
      cloud: CloudChannel(
        kind: CloudKind.drive,
        result: cloud,
        needsAccount: needsAccount,
        account: account,
        writing: writing,
      ),
    )!;

    // Before anyone has said yes there is nothing to report. `Last saved:
    // Never` would answer a question the user has not been allowed to ask.
    test('with no account it is one sentence and one button', () {
      final view = page(needsAccount: true);

      expect(view.facts, isEmpty);
      expect(view.connectLabel, 'Connect a Google account');
      expect(view.restoreLabel, isNull);
      expect(view.disconnectLabel, isNull);
    });

    // Two Google accounts are two different backups, and no date says which.
    test('once connected it names the account above the date', () {
      final view = page(
        account: 'someone@gmail.com',
        copiedAt: LocalDateTime(d('2026-08-27'), const LocalTime(12, 52)),
      );

      expect(view.facts.first, ('Account', 'someone@gmail.com'));
      expect(view.connectLabel, isNull);
      expect(view.disconnectLabel, 'Disconnect this account');
    });

    // `Sign in to iCloud` on an Android phone sends the user to a settings
    // page that does not exist there.
    test('a revoked account is named in Drive terms, not iCloud terms', () {
      expect(
        page(cloud: const CloudResult(CloudState.signedOut)).facts.single.$2,
        'Reconnect your account',
      );
    });

    // Reachable only after an account was attached and has gone since. It
    // reads the same as never having connected, which is what it is.
    test('an account that has gone says so instead of showing a date', () {
      expect(
        page(
          copiedAt: LocalDateTime(d('2026-08-27'), const LocalTime(12, 52)),
          cloud: const CloudResult(CloudState.disconnected),
        ).facts.single.$2,
        'Not connected',
      );
    });

    // The seconds between connecting and the first copy landing. `Never` is
    // what this row says to somebody whose backup is not happening at all, so
    // saying it here reads as the connection having achieved nothing.
    test('the first copy says it is being written, not that none exists', () {
      expect(
        page(account: 'a@b.c', writing: true).facts.last.$2,
        'Saving the first copy',
      );
    });

    // Only for the first. A later write has a real moment to show, and
    // swapping it for a progress word every time the user edits an item takes
    // away the one fact the row exists to report.
    test('a later write leaves the moment of the last one standing', () {
      expect(
        page(
          account: 'a@b.c',
          copiedAt: LocalDateTime(d('2026-08-27'), const LocalTime(12, 52)),
          writing: true,
        ).facts.last.$2,
        '27/08/2026 at 12:52',
      );
    });

    // A write that is failing must not read as a write that is working.
    test('a problem outranks the write in flight', () {
      expect(
        page(
          account: 'a@b.c',
          cloud: const CloudResult(CloudState.signedOut),
          writing: true,
        ).facts.last.$2,
        'Reconnect your account',
      );
    });

    test('the footnote says the copy survives disconnecting', () {
      expect(page(account: 'a@b.c').note, contains('leaves the copy'));
    });
  });
}
