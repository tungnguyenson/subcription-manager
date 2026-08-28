import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/cloud_store.dart';
import 'package:subdock/data/currency_store.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/locale_store.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';

/// What the app puts on screen between the first frame and the first row of
/// data, on a database that has never held anything.
///
/// It used to put up an empty Upcoming: tab bar, header, `Nothing due`. The
/// gate asked `_loaded && _items.isEmpty`, and `_loaded` cannot be true until
/// the drift stream has ticked, so for those frames the other branch ran and a
/// brand new user was told "you have nothing" from a screen they are only
/// meant to reach after the explanation.
///
/// An integration test rather than a widget test, and for the reason traps 28
/// and 45 give: the gate is in `app.dart`, which no widget test reaches -- and
/// `HomePage` re-plans notifications on its first stream event, which needs a
/// real platform to answer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SubdockDatabase db;
  late ItemRepository repo;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

  Widget app() => SubdockApp(
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
  );

  /// Frame by frame rather than `pumpAndSettle`, which is the whole point:
  /// settling jumps over every frame between the first one and the one the
  /// data lands on, and the flash lives in exactly those frames.
  Future<int> pumpUntil(WidgetTester tester, Finder target) async {
    for (var frame = 0; frame < 120; frame++) {
      expect(
        find.byType(UpcomingScreen),
        findsNothing,
        reason: 'the list showed on frame $frame, before onboarding did',
      );
      if (target.evaluate().isNotEmpty) return frame;
      await tester.pump(const Duration(milliseconds: 16));
    }
    return -1;
  }

  testWidgets('a first launch never flashes the empty list', (tester) async {
    await tester.pumpWidget(app());

    // Not `pumpAndSettle` at any point here: the first onboarding page runs
    // animations that never stop, so it would never return.
    final frame = await pumpUntil(
      tester,
      find.text('Never miss a due date again.'),
    );
    expect(frame, isNot(-1), reason: 'onboarding never arrived');
  });

  testWidgets('a returning list never flashes onboarding', (tester) async {
    await repo.upsert(
      TrackedItem(
        id: 'passport',
        name: 'Passport',
        categoryId: 'DOCUMENTS',
        expiresOn: LocalDate.parse('2027-02-02'),
        anchorDate: LocalDate.parse('2027-02-02'),
      ),
      1,
    );

    await tester.pumpWidget(app());

    // The blank gradient is held for both, and that is deliberate: guessing
    // onboarding while the data is in flight would trade this flash for the
    // opposite one, on the users who have most to lose from it.
    for (var frame = 0; frame < 120; frame++) {
      expect(
        find.text('Never miss a due date again.'),
        findsNothing,
        reason: 'onboarding showed on frame $frame',
      );
      if (find.byType(UpcomingScreen).evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 16));
    }
    fail('the list never arrived');
  });
}
