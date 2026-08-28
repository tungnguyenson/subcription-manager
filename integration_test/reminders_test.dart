import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:subdock/ui/widgets/primitives.dart';

import 'scroll_reach.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
        id: 'vps',
        name: 'OVH VPS',
        categoryId: 'STREAMING',
        expiresOn: LocalDate.today().plusDays(120),
        anchorDate: LocalDate.today().plusDays(120),
        cycle: Cycle.yearly,
        amountMinor: 2000,
        currency: 'USD',
        leadDays: const [3],
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

  Future<List<int>> leadsOf(String id) async =>
      (await repo.observeAll().first).firstWhere((i) => i.id == id).leadDays;

  Future<void> openReminders(WidgetTester tester) async {
    await tester.tap(find.text('OVH VPS'));
    await tester.pumpAndSettle();
    await tapPastTabBar(tester, find.text('Edit reminders'));
  }

  /// The toggle on the row carrying [label], read straight off the widget.
  AppToggle toggleFor(WidgetTester tester, String label) =>
      tester.widget<AppToggle>(
        find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Row))
              .last,
          matching: find.byType(AppToggle),
        ),
      );

  testWidgets('turning a rung on shows it on', (tester) async {
    await seed();
    await launch(tester);
    await openReminders(tester);

    expect(await leadsOf('vps'), [3], reason: 'seeded');
    expect(toggleFor(tester, '7 days before').value, isFalse);

    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('7 days before'),
              matching: find.byType(Row),
            )
            .last,
        matching: find.byType(AppToggle),
      ),
    );
    await tester.pumpAndSettle();

    expect(await leadsOf('vps'), [7, 3], reason: 'the write happened');
    expect(
      toggleFor(tester, '7 days before').value,
      isTrue,
      reason: 'and the screen says so',
    );
  });

  // The worse half. The callback closes over the item the route was pushed
  // with, so a second toggle recomputes the ladder from the original list and
  // drops whatever the first one added.
  testWidgets('a second rung does not undo the first', (tester) async {
    await seed();
    await launch(tester);
    await openReminders(tester);

    Future<void> flip(String label) async {
      await tester.tap(
        find.descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Row))
              .last,
          matching: find.byType(AppToggle),
        ),
      );
      await tester.pumpAndSettle();
    }

    await flip('7 days before');
    await flip('1 day before');

    expect(await leadsOf('vps'), [7, 3, 1]);
  });

  // The other end of the same freeze. The detail screen is the route this one
  // was pushed from, and it was handed its own snapshot -- so coming back from
  // a change made here left it reporting the ladder as it stood before.
  testWidgets('the screen behind it hears about the change', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.text('OVH VPS'));
    await tester.pumpAndSettle();
    expect(find.text('3 days before'), findsOneWidget, reason: 'Remind me row');

    await tapPastTabBar(tester, find.text('Edit reminders'));
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('7 days before'),
              matching: find.byType(Row),
            )
            .last,
        matching: find.byType(AppToggle),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('‹ Back'));
    await tester.pumpAndSettle();

    // The soonest rung is the one the row names, and 7 is now sooner than 3.
    expect(find.text('7 days before'), findsOneWidget);
    expect(find.text('3 days before'), findsNothing);
  });
}
