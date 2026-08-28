import 'package:drift/drift.dart' show Value;
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

  /// A moment on the device's own clock. The record is kept to the minute,
  /// so every write has to name one.
  DateTime t(String iso) => DateTime.parse(iso);

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

  // The date under `Last backup` in Settings. It has to stand for a file that
  // actually left the phone, which is why the caller writes it and not `read`.
  group('the last backup date', () {
    test('starts as never on both channels', () async {
      final saved = await backups.lastSaved();
      expect(saved.file, isNull);
      expect(saved.cloud, isNull);
      expect(saved.any, isFalse);
    });

    test('comes back once recorded, and survives being overwritten', () async {
      await backups.markSaved(t('2026-08-25 09:30'));
      expect((await backups.lastSaved()).file, d('2026-08-25'));

      await backups.markSaved(t('2026-08-26 09:30'));
      expect((await backups.lastSaved()).file, d('2026-08-26'));
    });

    // A file the user exported in May sits where they put it whatever happens
    // afterwards; the copy in iCloud is only as recent as the last write that
    // landed. One date covering both would report the newer of the two beside
    // whichever row the reader looked at.
    test('the two channels are recorded apart', () async {
      await backups.markSaved(t('2026-08-25 09:30'), BackupChannel.file);
      await backups.markSaved(t('2026-05-01 09:30'), BackupChannel.cloud);

      final saved = await backups.lastSaved();
      expect(saved.file, d('2026-08-25'));
      expect(saved.cloud, d('2026-05-01'));
    });

    // Nobody presses anything to make the cloud write happen, so the day on
    // its own cannot tell this morning's copy from the one written after the
    // edit the user just made. That distinction is the whole reason someone
    // opens the iCloud screen.
    test('the cloud copy is remembered to the minute', () async {
      await backups.markSaved(t('2026-08-27 12:52'), BackupChannel.cloud);

      final at = (await backups.lastSaved()).cloudAt;
      expect(at?.date, d('2026-08-27'));
      expect(at?.time, const LocalTime(12, 52));
    });

    // Installs from before the record kept the hour hold a bare date under the
    // same key. Refusing to read it would report `Never` to someone who has a
    // copy, which is the one answer this screen must never give wrongly.
    test('a date written by an older build still reads', () async {
      await db
          .into(db.settingRow)
          .insert(
            SettingRowCompanion(
              settingKey: const Value('last_cloud_backup_on'),
              value: const Value('2026-08-27'),
            ),
          );

      final at = (await backups.lastSaved()).cloudAt;
      expect(at?.date, d('2026-08-27'));
      expect(at?.time, const LocalTime(0, 0), reason: 'midnight, not a guess');
    });

    // Reading the whole database out is not a backup. Nothing has left the
    // phone until the share sheet says it did, and putting a date on screen
    // for a file that went nowhere is the one thing this row must never do.
    test('reading a backup does not count as taking one', () async {
      await repo.upsert(item(), 1);
      await backups.read();

      expect((await backups.lastSaved()).any, isFalse);
    });

    // Not today. Someone pulling back a copy taken three months ago has a
    // three-month-old backup, and the row has to say so at the one moment they
    // are thinking about it.
    test('a restore takes the date off the file, not off the clock', () async {
      await repo.upsert(item(), 1);
      final taken = await backups.read(clock: DateTime.utc(2026, 5, 25, 4));

      await backups.markSaved(t('2026-08-25 09:30'));
      await backups.restore(taken);

      expect((await backups.lastSaved()).file, d('2026-05-25'));
    });

    // A copy pulled out of iCloud says iCloud is up to date, not that a file
    // exists on disk.
    test('a restore stamps the channel it came off', () async {
      await repo.upsert(item(), 1);
      final taken = await backups.read(clock: DateTime.utc(2026, 5, 25, 4));

      await backups.restore(taken, from: BackupChannel.cloud);

      final saved = await backups.lastSaved();
      expect(saved.cloud, d('2026-05-25'));
      expect(saved.file, isNull);
    });

    // A hand-written file, or one from a build older than this field.
    test('a restore from a file with no date reads as never', () async {
      await backups.markSaved(t('2026-08-25 09:30'));

      await backups.restore(
        const Backup(
          categories: [],
          sources: [],
          items: [],
          history: [],
          exportedAt: '',
        ),
      );

      expect((await backups.lastSaved()).file, isNull);
    });

    test('the stream carries the change to whoever is watching', () async {
      // `emitsThrough` rather than a fixed sequence: drift decides for itself
      // how many times a watched query re-runs, and pinning that would make
      // this test about drift instead of about the date.
      final done = expectLater(
        backups.observeLastSaved(),
        emitsThrough(
          predicate<LastBackups>((saved) => saved.file == d('2026-08-25')),
        ),
      );
      await backups.markSaved(t('2026-08-25 09:30'));
      await done;
    });
  });

  // What a copy holds, beside when it was taken. Without this the app can only
  // ask whether *a* backup exists, which goes quiet for someone who backed up
  // in May and has confirmed four dates since.
  group('what the last copy covered', () {
    TrackedItem costly(String id) => TrackedItem(
      id: id,
      name: id,
      categoryId: 'STREAMING',
      expiresOn: d('2026-09-01'),
      anchorDate: d('2026-09-01'),
      dateSource: DateSource.userConfirmed,
    );

    test('starts unknown rather than empty on a fresh install', () async {
      final saved = await backups.lastSaved();
      expect(saved.fileCovered, isNull);
      expect(saved.cloudCovered, isNull);
      expect(saved.coverageKnown, isTrue, reason: 'no copy, nothing unknown');
    });

    // The whole reason the set is read inside `markSaved` rather than passed
    // in. An optional argument is the shape that has already gone wrong twice
    // here, and its failure is silent: the copy lands, the record says it
    // holds nothing.
    test('a write records the costly dates in the database', () async {
      await repo.upsert(costly('a'), 1);
      await repo.upsert(costly('b'), 2);
      await backups.markSaved(t('2026-08-25 09:30'));

      expect((await backups.lastSaved()).fileCovered, {'a', 'b'});
    });

    // The set answers "is anything expensive missing"; a date typed from
    // memory can be typed again, and carrying it would grow the row without
    // changing an answer.
    test('a date typed from memory is not recorded', () async {
      await repo.upsert(costly('a'), 1);
      await repo.upsert(
        TrackedItem(
          id: 'guess',
          name: 'guess',
          categoryId: 'STREAMING',
          expiresOn: d('2026-09-01'),
          anchorDate: d('2026-09-01'),
        ),
        2,
      );
      await backups.markSaved(t('2026-08-25 09:30'));

      expect((await backups.lastSaved()).fileCovered, {'a'});
    });

    test('the two channels record their own copies apart', () async {
      await repo.upsert(costly('a'), 1);
      await backups.markSaved(t('2026-08-25 09:30'));

      await repo.upsert(costly('b'), 2);
      await backups.markSaved(t('2026-08-26 09:30'), BackupChannel.cloud);

      final saved = await backups.lastSaved();
      expect(saved.fileCovered, {'a'});
      expect(saved.cloudCovered, {'a', 'b'});
    });

    // An install written by a build that kept only the date. Reading that as
    // "covers nothing" would fire the warning at every existing user the
    // moment they upgrade, over copies that are perfectly good.
    test('a date from an older build reads as unknown, not as empty', () async {
      await db
          .into(db.settingRow)
          .insert(
            SettingRowCompanion(
              settingKey: const Value('last_backup_on'),
              value: const Value('2026-08-25'),
            ),
          );

      final saved = await backups.lastSaved();
      expect(saved.file, d('2026-08-25'));
      expect(saved.fileCovered, isNull);
      expect(saved.coverageKnown, isFalse);
    });

    // Both halves go together. A date left without its set would read as a
    // copy holding nothing; a set without its date, as a copy that never was.
    test('a restore with no date in it clears the set too', () async {
      await repo.upsert(costly('a'), 1);
      await backups.markSaved(t('2026-08-25 09:30'));

      final taken = await backups.read();
      await backups.restore(
        Backup(
          categories: taken.categories,
          sources: taken.sources,
          items: taken.items,
          history: taken.history,
          defaultLeadDays: taken.defaultLeadDays,
          remindAt: taken.remindAt,
          exportedAt: 'not a date',
        ),
      );

      final saved = await backups.lastSaved();
      expect(saved.file, isNull);
      expect(saved.fileCovered, isNull);
    });
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
