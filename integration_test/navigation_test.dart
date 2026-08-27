import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/data/currency_store.dart';
import 'package:subdock/data/locale_store.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/platform/notification_scheduler.dart';

/// Runs the real app on a device against a real database.
///
/// Widget tests build one screen in isolation, so they cannot see the two
/// things most likely to make the app unusable: a push that has no Navigator
/// above it, and a screen that only exists once something is tapped. Both are
/// invisible until the app runs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  LocalDate d(String iso) => LocalDate.parse(iso);

  late SubdockDatabase db;
  late ItemRepository repo;

  Future<void> seed() async {
    await repo.upsert(
      TrackedItem(
        id: 'hsd',
        name: 'SIM validity',
        categoryId: 'STREAMING',
        expiresOn: d('2026-08-12'),
        anchorDate: d('2026-08-12'),
        note: 'Text TK to 191 to check.',
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
    await repo.upsert(
      TrackedItem(
        id: 'claude',
        name: 'Claude Pro',
        categoryId: 'STREAMING',
        expiresOn: LocalDate.today().plusDays(2),
        actByOffsetDays: 1,
        anchorDate: LocalDate.today().plusDays(2),
        cycle: Cycle.monthly,
        amountMinor: 2000,
        currency: 'USD',
        actionUrl: 'https://claude.ai/settings/billing',
        actionLabel: 'Cancel Claude',
      ),
      1,
    );
  }

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

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
        files: BackupFiles(),
        // Off in tests: the host has no iCloud container, and a timer
        // uploading in the background is not what any of these are about.
        cloud: CloudBackup(TargetPlatform.android),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an empty database opens on the explanation, not on a blank list',
    (tester) async {
      await launch(tester);
      expect(find.text('Never miss a due date again.'), findsOneWidget);
    },
  );

  testWidgets('the list appears once there is something to list', (
    tester,
  ) async {
    await seed();
    await launch(tester);

    expect(find.text('Upcoming'), findsWidgets);
    expect(find.text('Claude Pro'), findsOneWidget);
    // Every date is its own row now; nothing collapses into anything.
    expect(find.text('SIM validity'), findsOneWidget);
  });

  testWidgets('tapping an item opens its detail and comes back', (
    tester,
  ) async {
    await seed();
    await launch(tester);

    await tester.tap(find.text('Claude Pro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Due in'), findsOneWidget);

    await tester.tap(find.text('‹ Back'));
    await tester.pumpAndSettle();
    expect(find.text('Claude Pro'), findsOneWidget);
  });

  testWidgets('the reminder ladder is reachable from an item', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.text('Claude Pro'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Edit reminders'), 200);
    await tester.tap(find.textContaining('Edit reminders'));
    await tester.pumpAndSettle();

    expect(find.text('Reminders'), findsOneWidget);
    expect(find.textContaining('reminder slots iOS allows'), findsOneWidget);
  });

  testWidgets('every tab opens', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('THIS MONTH'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Export data'), findsOneWidget);

    await tester.tap(find.text('Upcoming').last);
    await tester.pumpAndSettle();
    expect(find.text('Claude Pro'), findsOneWidget);
  });

  testWidgets('the done log is reachable from settings', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(find.text('History'), findsWidgets);
  });

  // The add form is the only way into the app for a new user, so a broken
  // route here is a broken product.
  testWidgets('the add form opens and writes an item', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Vehicle inspection');
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle inspection'), findsOneWidget);
    expect(await repo.observeAll().first, hasLength(4));
  });

  // A date a month out lands in a collapsed fold, so the list looks unchanged
  // and the save reads as a failure. The confirmation is the only thing that
  // says otherwise.
  testWidgets('saving into a collapsed fold still confirms itself', (
    tester,
  ) async {
    await seed();
    await launch(tester);

    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Vehicle inspection');
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 1 month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Next 30 days'), findsWidgets);
    expect(await repo.observeAll().first, hasLength(4));
  });
}
