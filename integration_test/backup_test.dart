import 'dart:ui' show Rect;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/cloud_store.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/data/currency_store.dart';
import 'package:subdock/data/locale_store.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/notification_scheduler.dart';

/// Export and restore, driven through the real app on a device.
///
/// The codec and the store each have their own unit tests, and both can be
/// right while the two never meet: the tap that produces a file and the tap
/// that reads one back are wired in `app.dart` and are invisible to any test
/// that builds a single screen. This walks the path the user walks.
///
/// Only the system sheets are faked. There is no way to drive a share sheet or
/// a document picker from a test, and nothing worth testing on the other side
/// of them -- what matters is that the bytes handed out come back as the same
/// list.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  LocalDate d(String iso) => LocalDate.parse(iso);

  late SubdockDatabase db;
  late ItemRepository repo;
  late _FakeFiles files;
  late _FakeCloud cloud;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
    files = _FakeFiles();
    cloud = _FakeCloud();
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    await repo.upsertSource(
      const PaymentSource(id: 'visa', name: 'Techcombank Visa'),
      1690000000,
    );
    await repo.upsert(
      TrackedItem(
        id: 'claude',
        name: 'Claude Pro',
        categoryId: 'STREAMING',
        expiresOn: LocalDate.today().plusDays(2),
        anchorDate: LocalDate.today().plusDays(2),
        cycle: Cycle.monthly,
        amountMinor: 2000,
        currency: 'USD',
        paymentSourceId: 'visa',
      ),
      1700000000,
    );
    await repo.upsert(
      TrackedItem(
        id: 'passport',
        name: 'Passport',
        categoryId: 'DOCUMENTS',
        expiresOn: d('2027-02-02'),
        anchorDate: d('2027-02-02'),
      ),
      1700000001,
    );
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(
      SubdockApp(
        repository: repo,
        settings: SettingsStore(db),
        filters: FilterStore(db),
        themes: ThemeStore(db),
        locales: LocaleStore(db),
        currencies: CurrencyStore(db),
        scheduler: NotificationScheduler(),
        catalog: ServiceCatalog(const []),
        backups: BackupStore(db, repo, SettingsStore(db)),
        files: files,
        cloud: cloud,
        clouds: CloudStore(db),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unwinds to the Settings tab from wherever the test is standing.
  ///
  /// `.last` because the word appears twice once the screen is up: the tab
  /// label and the screen's own title. The tab bar is built after the content,
  /// so the last of the two is the one that navigates. Without it, calling
  /// this while already on Settings throws on an ambiguous finder.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
  }

  /// Scrolls a Settings row into view before tapping it.
  ///
  /// The backup card sits at the bottom of a list that is taller than a phone,
  /// and every row added to it pushes the last one further under the fold.
  ///
  /// `.last` because the warning banner reuses `Export a backup` as its own
  /// action label, and the banner sits above the card.
  Future<void> tapRow(WidgetTester tester, String label) async {
    final row = find.text(label).last;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  /// Opens the File page from Settings, then taps one of its rows.
  ///
  /// Two taps rather than one, because that is the app. Settings used to carry
  /// every backup action directly; it now carries one row per channel and the
  /// actions live on the page behind it. These tests went on tapping the old
  /// layout and had been red ever since, which is worse than having no test:
  /// the suite was reporting on a path nobody was walking.
  Future<void> tapFileRow(WidgetTester tester, String label) async {
    if (find.text('Restore from a file').evaluate().isEmpty) {
      // Not already on the page. Back to Settings first, from wherever we
      // are: sub-screens keep the tab bar, and tapping Settings on it unwinds
      // to the root rather than stacking another screen on top.
      await openSettings(tester);
      await tapRow(tester, 'Import/Export');
    }
    await tapRow(tester, label);
  }

  /// The same, for the cloud channel.
  Future<void> tapCloudRow(WidgetTester tester, String label) async {
    if (find.text('Restore from iCloud').evaluate().isEmpty) {
      await openSettings(tester);
      await tapRow(tester, 'iCloud');
    }
    await tapRow(tester, label);
  }

  /// Pumps a fixed number of frames instead of waiting for the tree to go
  /// quiet.
  ///
  /// Onboarding is the one screen `pumpAndSettle` must never be pointed at.
  /// Two of its three cards animate on a loop -- the strip of items sliding
  /// across, the notifications dropping in -- so the tree never goes quiet and
  /// the wait never returns. Trap 42 wrote this down; this helper is what
  /// following it looks like from a test that has to walk through the screen
  /// rather than photograph it.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Walks out of onboarding, which is what stands between a wiped database
  /// and every other screen.
  ///
  /// Two pages: three cards and a Continue, then language and currency and a
  /// Get started. Nothing here offers to restore a backup, and that is the
  /// design rather than an oversight -- see trap 42. It is also the reason
  /// these tests changed shape: they used to tap `I already have a backup` on
  /// the first onboarding screen, and that button no longer exists.
  Future<void> passOnboarding(WidgetTester tester) async {
    // Onboarding replaces the root screen, so a test standing on a pushed
    // page never sees it however empty the database gets. Unwind first.
    await tester.tap(find.text('Upcoming').last);
    await settle(tester);

    // Proves the wipe actually took, and that a database with nothing in it
    // lands on the explanation rather than on an empty Upcoming.
    expect(find.text('Never miss a due date again.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Get started'));
    await settle(tester);
  }

  /// Waits out the confirmation snackbar.
  ///
  /// It floats over the bottom of the screen, which is where the rows this
  /// test taps next happen to be. In the app the two never collide, because
  /// nobody exports and restores in the same three seconds.
  Future<void> settleSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('a list survives being exported and restored', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tapFileRow(tester, 'Export a backup');

    expect(files.saved, isNotNull, reason: 'the share sheet got a file');
    expect(files.savedAs, endsWith('.json'));
    expect(
      find.textContaining('Backed up 2 items'),
      findsOneWidget,
      reason: 'the app says what went into the file, not just that it worked',
    );

    // Everything changes between the export and the restore: one item gone,
    // one added. Both have to be undone.
    await repo.delete('passport');
    await repo.upsert(
      TrackedItem(
        id: 'later',
        name: 'Added later',
        categoryId: 'STREAMING',
        expiresOn: d('2027-05-05'),
        anchorDate: d('2027-05-05'),
      ),
      1,
    );
    await tester.pumpAndSettle();

    await settleSnackBar(tester);
    files.toPick = files.saved;
    await tapFileRow(tester, 'Restore from a file');

    // The sheet has to name what is about to go, and the filled button is the
    // one that keeps it.
    expect(find.text('Replace everything with this backup?'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);

    await tester.tap(find.text('Replace everything'));
    await tester.pumpAndSettle();

    final rows = await db.selectAll().get();
    expect(rows.map((r) => r.name).toList()..sort(), [
      'Claude Pro',
      'Passport',
    ], reason: 'the deleted one is back and the later one is gone');
    expect(
      rows.firstWhere((r) => r.id == 'claude').paymentSourceId,
      'visa',
      reason: 'the card an item pays from came back with it',
    );
  });

  // The loop that no widget test can see: an export writes a date, the date
  // rides a stream back through the presenter, and the banner it was raising
  // goes away. Every piece of that is wired in app.dart.
  testWidgets('exporting answers the warning it was raising', (tester) async {
    await repo.upsert(
      TrackedItem(
        id: 'sim',
        name: 'Viettel',
        categoryId: 'PHONE',
        expiresOn: d('2027-01-01'),
        anchorDate: d('2027-01-01'),
        // The expensive kind: this date cost a call to a hotline.
        dateSource: DateSource.userConfirmed,
      ),
      1,
    );
    await launch(tester);
    await openSettings(tester);

    expect(find.text('Nothing has been backed up'), findsOneWidget);
    // One per channel: the card carries a row for the cloud and a row for the
    // file, and neither has anything in it yet.
    expect(find.text('Never'), findsNWidgets(2));

    // The banner's own action, not the row below it. Someone who reads the
    // warning must be able to answer it without hunting for the card.
    await tester.tap(find.text('Export a backup').first);
    await tester.pumpAndSettle();

    expect(find.text('Nothing has been backed up'), findsNothing);
    // The file row has a date now. The cloud row has not, because nothing was
    // written up there, and it says so rather than borrowing the file's date.
    expect(find.text('Never'), findsOneWidget);
  });

  // Dates typed from memory are annoying to retype. Dates read off a
  // provider's own record are phone calls. Only the second raises the banner.
  testWidgets('a list nobody had to phone for raises nothing', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    expect(find.text('Nothing has been backed up'), findsNothing);
    expect(find.text('Never'), findsNWidgets(2), reason: 'one per channel');
  });

  // The moment a backup is worth having is the moment someone reinstalls.
  //
  // That person now has further to walk than they used to: onboarding no
  // longer offers to restore one, so the only way back is through it and into
  // Settings. Trap 42 records that as a deliberate loss rather than a gap, and
  // this test walks the whole of it -- if the route were ever broken, the
  // person who found out would be the person with nothing left.
  testWidgets('a fresh install can restore before it has anything', (
    tester,
  ) async {
    await seed();
    await launch(tester);
    await openSettings(tester);
    await tapFileRow(tester, 'Export a backup');

    await settleSnackBar(tester);

    // Wipe it the way an uninstall does, then reopen on an empty database.
    await db.delete(db.handledEventRow).go();
    await db.delete(db.itemRow).go();
    await tester.pumpAndSettle();

    await passOnboarding(tester);
    files.toPick = files.saved;
    await tapFileRow(tester, 'Restore from a file');
    // `Restore`, not `Replace everything`. There is nothing on this phone to
    // replace, and the sheet does not talk about losing what does not exist.
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect((await db.selectAll().get()).length, 2);
  });

  // The question the user asked out loud: it says Saved, so how do I get it
  // back. One row, one tap, same confirmation as any other restore.
  testWidgets('the copy in the cloud restores in one tap', (tester) async {
    await seed();
    await launch(tester);

    // Whatever the app last wrote up there is what comes back down.
    cloud.holds = null;
    await openSettings(tester);
    await tapFileRow(tester, 'Export a backup');
    cloud.holds = files.saved;
    await settleSnackBar(tester);

    await repo.delete('passport');
    await tester.pumpAndSettle();

    await tapCloudRow(tester, 'Restore from iCloud');

    // The same sheet a file restore raises. Both destroy the same rows, so
    // both have to ask the same question.
    expect(find.text('Replace everything with this backup?'), findsOneWidget);
    await tester.tap(find.text('Replace everything'));
    await tester.pumpAndSettle();

    expect((await db.selectAll().get()).length, 2);
  });

  // Two dates, two channels, and nothing in the app tells them apart at a
  // glance: `markSaved` takes the channel as an optional argument that
  // defaults to the file. Leaving it off compiles, uploads, and reports
  // `Saved` on the iCloud screen with `Last copy — Never` right underneath,
  // while the File row grows a date for a file the user never exported.
  testWidgets('a cloud write stamps the cloud row, not the file row', (
    tester,
  ) async {
    await seed();
    await launch(tester);

    // Launching subscribes to the item stream, which queues the write. The
    // debounce is the only thing between here and the upload.
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(cloud.written, isNotNull, reason: 'the upload actually ran');

    await openSettings(tester);
    await tapRow(tester, 'iCloud');

    expect(find.text('Last saved'), findsOneWidget);
    expect(
      find.text('Never'),
      findsNothing,
      reason: 'the write that just landed is the last copy',
    );

    // And the other channel is untouched: no file has been exported.
    final saved = await BackupStore(db, repo, SettingsStore(db)).lastSaved();
    expect(saved.cloudAt, isNotNull);
    expect(saved.fileAt, isNull, reason: 'nothing was ever written to a file');
  });

  // The bug this exists for: connecting an account changed nothing on screen.
  // The page went on offering `Connect` and only told the truth after the user
  // went back and opened it again.
  //
  // The cause is the one trap 34 already wrote down for colours. A pushed
  // route builds its page exactly once and keeps it, so `setState` in the
  // shell rebuilds everything except the screen the user is looking at. The
  // only way in is a subscription the pushed widget makes for itself.
  testWidgets('connecting an account shows on the page you are on', (
    tester,
  ) async {
    cloud.wantsAccount = true;
    await seed();
    await launch(tester);
    await openSettings(tester);
    await tapRow(tester, 'iCloud');

    expect(find.text('Connect a Google account'), findsOneWidget);

    await tester.tap(find.text('Connect a Google account'));
    await tester.pumpAndSettle();

    // Still on the same route. Nothing was popped and nothing re-pushed.
    expect(
      find.text('Connect a Google account'),
      findsNothing,
      reason: 'the offer is gone once it has been taken up',
    );
    expect(find.text('someone@gmail.com'), findsOneWidget);

    // And the copy the connection triggered lands on the same screen.
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(cloud.written, isNotNull, reason: 'connecting writes a copy');
    expect(
      find.text('Never'),
      findsNothing,
      reason: 'a copy exists, so the row must not report that none does',
    );
  });

  // Silence here would read as a tap that did nothing.
  testWidgets('an empty container says so rather than nothing', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    cloud.holds = null;
    await tapCloudRow(tester, 'Restore from iCloud');

    expect(find.textContaining('no copy in iCloud yet'), findsOneWidget);
    expect(find.text('Replace everything'), findsNothing);
  });

  // The same walk on the other channel, and the one that matters most: whoever
  // changed phone has no file to pick, only whatever the app wrote up there by
  // itself while they still had the old one.
  testWidgets('a wiped install can pull its list back out of the cloud', (
    tester,
  ) async {
    await seed();
    await launch(tester);
    await openSettings(tester);
    await tapFileRow(tester, 'Export a backup');
    cloud.holds = files.saved;
    await settleSnackBar(tester);

    await db.delete(db.handledEventRow).go();
    await db.delete(db.itemRow).go();
    await tester.pumpAndSettle();

    // Nothing is offered to the file picker, so anything that comes back came
    // out of the cloud.
    files.toPick = null;
    await passOnboarding(tester);
    await tapCloudRow(tester, 'Restore from iCloud');
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect((await db.selectAll().get()).length, 2);
  });

  // The user can walk away at the sheet, and walking away has to be free.
  testWidgets('declining the sheet changes nothing', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tapFileRow(tester, 'Export a backup');

    await repo.delete('passport');
    await tester.pumpAndSettle();

    await settleSnackBar(tester);
    files.toPick = files.saved;
    await tapFileRow(tester, 'Restore from a file');
    await tester.tap(find.text('Keep what I have'));
    await tester.pumpAndSettle();

    expect((await db.selectAll().get()).map((r) => r.id), ['claude']);
  });

  // Someone will eventually pick the wrong file out of a folder of them.
  testWidgets('a file that is not a backup is refused by name', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    files.toPick = '{"hello": "world"}';
    await tapFileRow(tester, 'Restore from a file');

    expect(find.textContaining('not a Subdock backup'), findsOneWidget);
    expect(find.text('Replace everything'), findsNothing);
    expect((await db.selectAll().get()).length, 2);
  });

  // Cancelling the picker is not an error and must not say anything.
  testWidgets('cancelling the picker is silent', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tapFileRow(tester, 'Restore from a file');

    expect(find.textContaining('Replace everything'), findsNothing);
    expect(find.textContaining('Could not'), findsNothing);
  });
}

/// Stands in for the user's iCloud.
///
/// There is no container on a simulator, so the real class would answer
/// `signedOut` to everything. What is worth testing is the wiring above it:
/// which row reads which source, and that both ask the same question first.
class _FakeCloud extends CloudBackup {
  /// Whether this stands in for a channel the user has to attach an account
  /// to, the way Drive does, rather than one the phone is already signed in
  /// to.
  bool wantsAccount = false;

  String? _account;

  @override
  bool get needsAccount => wantsAccount && _account == null;

  @override
  String? get account => _account;

  @override
  void resume(String? account) => _account = account;

  @override
  Future<CloudResult> connect() async {
    _account = 'someone@gmail.com';
    return const CloudResult(CloudState.saved);
  }

  /// What [latest] finds. Null is an empty container.
  String? holds;

  String? written;

  @override
  bool get isSupported => true;

  @override
  Future<CloudResult> save(String contents) async {
    written = contents;
    holds = contents;
    return const CloudResult(CloudState.saved);
  }

  @override
  Future<CloudFetch> latest() async => holds == null
      ? const CloudFetch(CloudState.missing)
      : CloudFetch(
          CloudState.saved,
          copy: CloudCopy(
            contents: holds!,
            changedAt: DateTime.utc(2026, 8, 26),
          ),
        );
}

/// Stands in for the system share sheet and document picker.
class _FakeFiles extends BackupFiles {
  String? saved;
  String? savedAs;

  /// What [pick] returns. Null is the user cancelling, which is the default.
  String? toPick;

  @override
  Future<bool> save(
    String contents,
    String fileName, {
    String mimeType = 'application/json',
    Rect? origin,
  }) async {
    saved = contents;
    savedAs = fileName;
    return true;
  }

  @override
  Future<String?> pick() async => toPick;
}
