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
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/ui/screens/add_item_screen.dart';

/// Saving a new item, driven through the real app.
///
/// The form hands a `DraftItem` to a callback, so every widget test of it can
/// only prove that the draft came out right. What the app then does with that
/// draft is `_saveDraft` in `app.dart`, and a field left off the
/// `TrackedItem.on` call there compiles, runs, saves, and quietly drops the
/// answer -- exactly the shape of the bug in trap 43, and the reason that one
/// needed an integration test too.
///
/// Three fields have gone missing this way. `note` had no box on the form at
/// all; `inTrial` and `paymentSourceId` had boxes, were carried correctly all
/// the way to the draft, and were then not passed on. The edit path hid the
/// last two, because `DraftItem.applyTo` merges into an existing item and
/// carried them fine -- so the loss showed only on the first save of an item.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SubdockDatabase db;
  late ItemRepository repo;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

  /// One item and one card, so the app opens on the list rather than on
  /// onboarding, and so the payment source row has a chip to offer.
  Future<void> seed() async {
    await repo.upsertSource(
      const PaymentSource(id: 'vcb', name: 'VCB 4412'),
      1,
    );
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

  /// The note box, by its hint. The form holds half a dozen `TextField`s and
  /// index order across them is not something to lean on.
  final noteBox = find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText == 'Anything you want to remember',
  );

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('everything the form asked for reaches the row', (tester) async {
    await seed();
    await launch(tester);

    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();

    // Step one is the catalogue browser. Nothing is in it here, so the way
    // through is the row that keeps whatever was typed into the search box.
    await tapVisible(tester, find.text('Enter manually'));

    await tester.enterText(find.byType(TextField).first, 'Gym Hoang Cau');
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Today'));
    await tapVisible(tester, find.text('In a free trial now'));
    await tapVisible(tester, find.text('VCB 4412'));

    await tester.scrollUntilVisible(
      noteBox,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(noteBox, 'Shared with Minh, he pays half.');
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Save item'));

    final rows = await db.selectAll().get();
    final saved = rows.firstWhere((r) => r.name == 'Gym Hoang Cau');

    expect(saved.note, 'Shared with Minh, he pays half.');
    expect(saved.inTrial, isTrue);
    expect(saved.paymentSourceId, 'vcb');
  });

  /// The form must be gone before the permission sheet is asked for.
  ///
  /// `_saveDraft` used to leave with `maybePop`, which asks the route first
  /// and so pops one microtask later -- after the sheet had already been
  /// pushed. `maybePop` then saw a different route on top and did nothing, so
  /// the form stayed up behind the sheet with its Save button already spent
  /// (trap 30). The item was on the list the whole time and the only way to
  /// find that out was to back out of a form that looked like it had saved
  /// nothing.
  testWidgets('saving leaves the form before anything else is asked', (
    tester,
  ) async {
    await seed();
    await launch(tester);

    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Enter manually'));

    await tester.enterText(find.byType(TextField).first, 'Gym Hoang Cau');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Today'));
    await tapVisible(tester, find.text('Save item'));

    // Whether the permission sheet ever comes depends on what this device
    // already granted. The form leaving does not, and it must have left
    // before anything is put on top of it.
    expect(find.byType(AddItemScreen), findsNothing);
    expect(find.text('Gym Hoang Cau'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(AddItemScreen), findsNothing);
  });
}
