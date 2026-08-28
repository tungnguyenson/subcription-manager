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

import 'scroll_reach.dart';

/// Cancelling a subscription, driven through the real app.
///
/// Same reason `delete_test.dart` exists: the ask lives in `app.dart`, between
/// the button and the repository, so no test that builds the detail screen on
/// its own can see it. That screen's `onStop` is a callback the test supplies
/// and it fires either way.
///
/// The last case here is the one that cannot be reached from anywhere else.
/// `_sweepLapsed` closes a cancelled item once its paid-up period runs out, and
/// it is wired to the item stream and to app resume rather than to any button.
/// A unit test can prove the rule; only this can prove it is called.
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

  /// [expiresOn] defaults to two days out, which is the ordinary case: a plan
  /// with time left on it.
  Future<void> seed({LocalDate? expiresOn, int? repeatCount}) async {
    final due = expiresOn ?? LocalDate.today().plusDays(2);
    await repo.upsert(
      TrackedItem(
        id: 'claude',
        name: 'Claude Pro',
        categoryId: 'STREAMING',
        expiresOn: due,
        // Back far enough that the instalment case is partway through its plan
        // rather than on its first payment.
        anchorDate: repeatCount == null ? due : due.minusDays(90),
        cycle: Cycle.monthly,
        repeatCount: repeatCount,
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
        files: BackupFiles(),
        cloud: const NoCloud(),
        clouds: CloudStore(db),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCancel(WidgetTester tester, String label) async {
    await tester.tap(find.text('Claude Pro'));
    await tester.pumpAndSettle();

    await tapPastTabBar(tester, find.text(label));
  }

  Future<ItemState?> stateOf(String id) async {
    final row = (await db.selectAll().get())
        .where((r) => r.id == id)
        .firstOrNull;
    if (row == null) return null;
    return ItemState.values.where((s) => s.wireName == row.state).firstOrNull;
  }

  testWidgets('the button asks before the reminders go', (tester) async {
    await seed();
    await launch(tester);
    await openCancel(tester, 'Cancel this subscription');

    // Named, so the user can check they tapped the right row, and dated, so
    // they know the app is not about to forget the item today.
    expect(find.text('Cancel Claude Pro?'), findsOneWidget);
    expect(find.textContaining('then it closes itself'), findsOneWidget);
    expect(
      await stateOf('claude'),
      ItemState.active,
      reason: 'nothing written until the sheet is answered',
    );
  });

  testWidgets('keeping it leaves the subscription running', (tester) async {
    await seed();
    await launch(tester);
    await openCancel(tester, 'Cancel this subscription');

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(await stateOf('claude'), ItemState.active);
  });

  testWidgets('confirming cancels it and leaves it on the list', (
    tester,
  ) async {
    await seed();
    await launch(tester);
    await openCancel(tester, 'Cancel this subscription');

    await tester.tap(find.text('Cancel it'));
    await tester.pumpAndSettle();

    expect(await stateOf('claude'), ItemState.cancelledStillActive);
    expect(
      find.text('Claude Pro'),
      findsOneWidget,
      reason: 'still paid up, so still on the list -- with a badge on it',
    );
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  // Shortening a counted plan touches no reminders and is undone by editing the
  // count, so it gets its own words rather than the cancellation's.
  testWidgets('a counted plan is asked about in its own terms', (tester) async {
    await seed(repeatCount: 6);
    await launch(tester);
    await openCancel(tester, 'Stop after this payment');

    expect(find.textContaining('Stop after payment'), findsOneWidget);
    expect(find.text('They run on to the last payment'), findsOneWidget);
  });

  // The period a cancellation names has to end somewhere, and no button ends
  // it. Nothing here taps anything: launching the app is the whole test.
  testWidgets('a cancelled period that has run out closes on its own', (
    tester,
  ) async {
    await seed(expiresOn: LocalDate.today().minusDays(1));
    await repo.setState('claude', ItemState.cancelledStillActive);

    await launch(tester);

    expect(await stateOf('claude'), ItemState.inactive);
    expect(
      find.text('Claude Pro'),
      findsNothing,
      reason: 'closed items are off every list',
    );
  });

  testWidgets('one still inside its period is left alone', (tester) async {
    await seed(expiresOn: LocalDate.today().plusDays(2));
    await repo.setState('claude', ItemState.cancelledStillActive);

    await launch(tester);

    expect(await stateOf('claude'), ItemState.cancelledStillActive);
    expect(find.text('Claude Pro'), findsOneWidget);
  });
}
