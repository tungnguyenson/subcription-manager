import 'dart:ui' show Rect;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/platform/backup_files.dart';
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

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
    files = _FakeFiles();
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
        scheduler: NotificationScheduler(),
        catalog: ServiceCatalog(const []),
        backups: BackupStore(db, repo, SettingsStore(db)),
        files: files,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('a list survives being exported and restored', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Export a backup'));
    await tester.pumpAndSettle();

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

    files.toPick = files.saved;
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();

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
    expect(find.text('Never'), findsOneWidget);

    // The banner carries the fix, so this taps the banner's own action.
    await tester.tap(find.text('Export a backup').first);
    await tester.pumpAndSettle();

    expect(find.text('Nothing has been backed up'), findsNothing);
    expect(find.text('Never'), findsNothing);
  });

  // Dates typed from memory are annoying to retype. Dates read off a
  // provider's own record are phone calls. Only the second raises the banner.
  testWidgets('a list nobody had to phone for raises nothing', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    expect(find.text('Nothing has been backed up'), findsNothing);
    expect(find.text('Never'), findsOneWidget);
  });

  // The moment a backup is worth having is the moment someone reinstalls, and
  // that person is looking at the onboarding screen, not at Settings.
  testWidgets('a fresh install can restore before it has anything', (
    tester,
  ) async {
    await seed();
    await launch(tester);
    await openSettings(tester);
    await tester.tap(find.text('Export a backup'));
    await tester.pumpAndSettle();

    // Let the confirmation snackbar expire. It floats over the bottom of the
    // screen, which is where the onboarding buttons live; in the app the two
    // never meet, because reaching onboarding again means reinstalling.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Wipe it the way an uninstall does, then reopen on an empty database.
    await db.delete(db.handledEventRow).go();
    await db.delete(db.itemRow).go();
    await tester.pumpAndSettle();
    expect(find.text('Never miss a due date again.'), findsOneWidget);

    files.toPick = files.saved;
    await tester.tap(find.text('I already have a backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect((await db.selectAll().get()).length, 2);
  });

  // The user can walk away at the sheet, and walking away has to be free.
  testWidgets('declining the sheet changes nothing', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Export a backup'));
    await tester.pumpAndSettle();

    await repo.delete('passport');
    await tester.pumpAndSettle();

    files.toPick = files.saved;
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not a Subdock backup'), findsOneWidget);
    expect(find.text('Replace everything'), findsNothing);
    expect((await db.selectAll().get()).length, 2);
  });

  // Cancelling the picker is not an error and must not say anything.
  testWidgets('cancelling the picker is silent', (tester) async {
    await seed();
    await launch(tester);
    await openSettings(tester);

    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Replace everything'), findsNothing);
    expect(find.textContaining('Could not'), findsNothing);
  });
}

/// Stands in for the system share sheet and document picker.
class _FakeFiles extends BackupFiles {
  String? saved;
  String? savedAs;

  /// What [pick] returns. Null is the user cancelling, which is the default.
  String? toPick;

  @override
  Future<bool> save(String contents, String fileName, {Rect? origin}) async {
    saved = contents;
    savedAs = fileName;
    return true;
  }

  @override
  Future<String?> pick() async => toPick;
}
