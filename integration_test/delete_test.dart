import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

/// Deleting an item, driven through the real app.
///
/// The ask lives in `app.dart`, between the button and the repository, so no
/// test that builds the detail screen on its own can see it: that screen's
/// `onDelete` is a callback the test supplies, and it fires either way. This
/// walks the path the user walks.
///
/// Worth walking because the loss is total. `handledEventRow` carries
/// `ON DELETE CASCADE`, the app has no server and no undo, and the button sits
/// on the same scrolling screen as `Mark as paid`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  LocalDate d(String iso) => LocalDate.parse(iso);

  late SubdockDatabase db;
  late ItemRepository repo;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seed() async {
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
      ),
      1,
    );
    await repo.upsert(
      TrackedItem(
        id: 'passport',
        name: 'Passport',
        categoryId: 'DOCUMENTS',
        expiresOn: d('2027-02-02'),
        anchorDate: d('2027-02-02'),
      ),
      1,
    );
    await repo.recordHandled(
      HandledEvent(
        id: 'paid-1',
        itemId: 'claude',
        handledAtEpochSeconds: 1700000000,
        forDueDate: d('2026-07-15'),
        amountMinor: 2000,
        currency: 'USD',
      ),
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
        files: BackupFiles(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(find.text('Claude Pro'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete this item'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete this item'));
    await tester.pumpAndSettle();
  }

  Future<List<String>> ids() async =>
      (await db.selectAll().get()).map((r) => r.id).toList()..sort();

  testWidgets('the delete button asks before anything is gone', (tester) async {
    await seed();
    await launch(tester);
    await openDelete(tester);

    // Named, and counted. The name is how the user checks they tapped the right
    // row; the counts are the only place the pending reminders are visible at
    // all.
    expect(find.text('Delete Claude Pro?'), findsOneWidget);
    expect(find.text('1 recorded payment'), findsOneWidget);
    expect(await ids(), ['claude', 'passport'], reason: 'nothing yet');
  });

  testWidgets('keeping it leaves the item and its payments alone', (
    tester,
  ) async {
    await seed();
    await launch(tester);
    await openDelete(tester);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(await ids(), ['claude', 'passport']);
    expect((await db.select(db.handledEventRow).get()).length, 1);
  });

  testWidgets('confirming takes the item and its payments', (tester) async {
    await seed();
    await launch(tester);
    await openDelete(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await ids(), ['passport']);
    expect(
      (await db.select(db.handledEventRow).get()),
      isEmpty,
      reason: 'ON DELETE CASCADE takes the history, and the sheet said so',
    );
    expect(
      find.text('Claude Pro'),
      findsNothing,
      reason: 'the detail screen popped back to a list without it',
    );
  });
}
