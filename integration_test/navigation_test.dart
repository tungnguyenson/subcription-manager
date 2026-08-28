import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/cloud_store.dart';
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
    // Onboarding is the first screen an empty database lands on, and two of
    // its cards animate on a loop. `pumpAndSettle` waits for the tree to go
    // quiet, so pointed at that screen it waits forever. Turning animations
    // off at the system level is the same road a phone with Reduce Motion
    // takes, which is the road trap 42 says these tests must go down.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

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
        cloud: const NoCloud(),
        clouds: CloudStore(db),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls something into view before tapping it.
  ///
  /// The add form is taller than a phone, so most of what these tests reach
  /// for starts off the bottom of it.
  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Dismisses the notification sheet the first save raises.
  ///
  /// It did not exist when these tests were written, so they went on asserting
  /// against a list that was sitting behind it. Declining is the right answer
  /// here: what is under test is the route into the form and out again, not
  /// whether reminders get switched on.
  Future<void> declineReminders(WidgetTester tester) async {
    if (find.text('Not now').evaluate().isEmpty) return;
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  }

  /// Opens the add form and gets past the catalogue browser.
  ///
  /// Step one of adding anything is now picking from the catalogue, and the
  /// way past it for something the catalogue does not know is the row that
  /// keeps whatever was typed. These tests predate that step and used to tap
  /// straight into the name field.
  Future<void> openBlankForm(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Enter manually'));
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
    // Not `iOS allows`. The budget is an iOS figure applied to both platforms
    // because no published Android number exists that the app dares quote, so
    // the wording names no platform at all -- see trap 11.
    expect(
      find.textContaining('reminder slots this app schedules'),
      findsOneWidget,
    );
  });

  testWidgets('every tab opens', (tester) async {
    await seed();
    await launch(tester);

    // `Spending`, not `Money`. The tab was renamed and this test went on
    // tapping a label that is not on the screen.
    await tester.tap(find.text('Spending'));
    await tester.pumpAndSettle();
    expect(find.text('THIS MONTH'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    // One row per channel now, and the file one is called `Import/Export`.
    expect(find.text('Import/Export'), findsOneWidget);

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

    await openBlankForm(tester);

    await tester.enterText(find.byType(TextField).first, 'Vehicle inspection');
    await tester.pumpAndSettle();
    // `+7`, not `In 7 days`: the date shortcuts are written as offsets now.
    await tapVisible(tester, find.text('+7'));
    await tapVisible(tester, find.text('Save item'));
    await declineReminders(tester);

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

    await openBlankForm(tester);
    await tester.enterText(find.byType(TextField).first, 'Vehicle inspection');
    await tester.pumpAndSettle();
    // The furthest shortcut the form offers, which is the one that lands
    // outside the folds the list opens with.
    await tapVisible(tester, find.text('+30'));
    await tapVisible(tester, find.text('Save item'));
    await declineReminders(tester);

    expect(find.textContaining('Next 30 days'), findsWidgets);
    expect(await repo.observeAll().first, hasLength(4));
  });
}
