import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/backup.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  late SubdockDatabase db;
  late ItemRepository repo;
  late SettingsStore settings;
  late BackupStore backups;

  LocalDate d(String iso) => LocalDate.parse(iso);

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
    settings = SettingsStore(db);
    backups = BackupStore(db, repo, settings);
  });

  tearDown(() => db.close());

  TrackedItem item({
    String id = 'netflix',
    String name = 'Netflix',
    String categoryId = 'STREAMING',
    String? paymentSourceId,
  }) => TrackedItem(
    id: id,
    name: name,
    categoryId: categoryId,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-01-01'),
    cycle: Cycle.monthly,
    amountMinor: 260000,
    currency: 'VND',
    paymentSourceId: paymentSourceId,
  );

  /// Export, wipe, import. The path a user actually walks, and the only one
  /// worth asserting: a read that is right and a restore that is right can
  /// still fail to meet in the middle.
  Future<Backup> exportThenWipe() async {
    final taken = await backups.read();
    await db.delete(db.handledEventRow).go();
    await db.delete(db.itemRow).go();
    await db.delete(db.paymentSourceRow).go();
    return taken;
  }

  test('a list survives export, wipe and import', () async {
    await repo.upsertSource(
      const PaymentSource(id: 'visa', name: 'Techcombank Visa'),
      1690000000,
    );
    await repo.upsert(item(paymentSourceId: 'visa'), 1700000000);
    await repo.upsert(item(id: 'sim', name: 'Viettel', categoryId: 'PHONE'), 2);
    await repo.recordHandled(
      HandledEvent(
        id: 'e1',
        itemId: 'netflix',
        handledAtEpochSeconds: 1756000000,
        forDueDate: d('2026-08-01'),
        amountMinor: 260000,
        currency: 'VND',
      ),
    );

    final taken = await exportThenWipe();
    await backups.restore(taken);

    final items = await db.selectAll().get();
    expect(items.map((r) => r.name).toList()..sort(), ['Netflix', 'Viettel']);
    expect(
      items.firstWhere((r) => r.id == 'netflix').paymentSourceId,
      'visa',
      reason: 'the card an item pays from is part of the item',
    );
    expect((await db.select(db.handledEventRow).get()).single.id, 'e1');
    expect((await db.selectAllSources().get()).single.name, 'Techcombank Visa');
  });

  // Nothing on screen shows when a card was added, but the sources list is
  // ordered by it.
  test('creation timestamps come back, so ordering does', () async {
    await repo.upsertSource(const PaymentSource(id: 'b', name: 'Second'), 200);
    await repo.upsertSource(const PaymentSource(id: 'a', name: 'First'), 100);

    final taken = await exportThenWipe();
    await backups.restore(taken);

    expect((await db.selectAllSources().get()).map((r) => r.name), [
      'First',
      'Second',
    ]);
  });

  test('the app-wide reminder defaults come back', () async {
    await settings.save(
      const AppSettings(defaultLeadDays: [14, 2], remindAt: LocalTime(6, 45)),
    );

    final taken = await backups.read();
    await settings.save(const AppSettings(defaultLeadDays: [1]));
    await backups.restore(taken);

    final out = await settings.read();
    expect(out.defaultLeadDays, [14, 2]);
    expect(out.remindAt, const LocalTime(6, 45));
  });

  // Replace, not merge. Someone restoring after losing a phone has to get the
  // list they had, not that list mixed with whatever they typed since.
  test('restoring replaces rather than merging', () async {
    await repo.upsert(item(), 1);
    final taken = await backups.read();

    await repo.upsert(item(id: 'added-later', name: 'Added later'), 2);
    await backups.restore(taken);

    expect((await db.selectAll().get()).map((r) => r.id), ['netflix']);
  });

  // The user edits shelves, so the shelves are theirs and go in the file. A
  // restore that kept the fresh install's seeded rows would put their items on
  // shelves with labels they never chose.
  test('a renamed shelf comes back renamed', () async {
    final shelves = await repo.allCategories();
    final streaming = shelves.firstWhere((c) => c.id == 'STREAMING');
    await repo.upsertCategory(
      Category(
        id: streaming.id,
        label: 'Phim ảnh',
        wording: streaming.wording,
        nag: streaming.nag,
        leadDays: streaming.leadDays,
        countsTowardSpend: streaming.countsTowardSpend,
        builtIn: streaming.builtIn,
        sortOrder: streaming.sortOrder,
      ),
    );

    final taken = await backups.read();
    await backups.restore(taken);

    final out = await repo.allCategories();
    expect(out.firstWhere((c) => c.id == 'STREAMING').label, 'Phim ảnh');
  });

  // A hand-edited file, or one written when a shelf was deleted mid-export.
  // The foreign key would abort the whole restore, and the user's own data is
  // already gone by then.
  test('an item on a shelf the file does not carry still lands', () async {
    await repo.upsert(item(), 1);
    final taken = await backups.read();

    final stripped = Backup(
      categories: taken.categories.where((c) => c.id != 'STREAMING').toList(),
      sources: taken.sources,
      items: taken.items,
      history: taken.history,
      exportedAt: taken.exportedAt,
    );

    await backups.restore(stripped);

    final rows = await db.selectAll().get();
    expect(rows.single.id, 'netflix');
    expect(
      taken.categories.map((c) => c.id),
      contains(rows.single.category),
      reason: 'landed on a shelf that exists',
    );
  });

  // The foreign key would refuse it, and nothing could display it anyway.
  test('a payment whose item is gone is dropped, not fatal', () async {
    await repo.upsert(item(), 1);
    final taken = await backups.read();

    final orphaned = Backup(
      categories: taken.categories,
      sources: taken.sources,
      items: const [],
      history: [
        HandledEvent(
          id: 'e1',
          itemId: 'netflix',
          handledAtEpochSeconds: 1,
          forDueDate: d('2026-08-01'),
        ),
      ],
      exportedAt: taken.exportedAt,
    );

    await backups.restore(orphaned);

    expect(await db.select(db.handledEventRow).get(), isEmpty);
    expect(await db.selectAll().get(), isEmpty);
  });

  group('the file name', () {
    // Local, not UTC. Someone in Vietnam taking a backup at 1am picks it out of
    // a folder by the day they remember, and UTC files it under the day before.
    test('is dated on the user\'s own calendar', () {
      expect(
        BackupStore.fileNameFor(DateTime(2026, 8, 25, 1, 5)),
        'subdock-2026-08-25-0105.json',
      );
    });
  });
}
