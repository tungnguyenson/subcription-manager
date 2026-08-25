import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/domain/default_categories.dart';

import '../../fixtures/schema_v1.dart';
import '../../fixtures/schema_v4.dart';
import '../../fixtures/schema_v6.dart';

/// Opening a v1 file is the one code path no unit test can fake convincingly,
/// because the v1 schema exists nowhere in the tree any more — the migration
/// is written against a shape that only lives on already-installed devices.
///
/// The v1 DDL lives in `test/fixtures/schema_v1.dart`, dumped verbatim off a
/// real device file and shared with the on-device test in `integration_test/`.
void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('subdock_migration');
    file = File('${dir.path}/db.sqlite');

    final v1 = sqlite3.open(file.path);
    v1.execute(schemaV1);
    v1.execute(seedV1);
    v1.execute('PRAGMA user_version = 1');
    v1.close();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a v1 file opens at the current version and keeps its rows', () async {
    final db = SubdockDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db.selectAll().get();
    expect(rows, hasLength(3));
    expect(rows.map((r) => r.name), contains('Netflix'));
    // Existing rows have no end to their repetition; that is what NULL means.
    expect(rows.every((r) => r.repeatCount == null), isTrue);
    // And nobody has overridden an icon yet.
    expect(rows.every((r) => r.iconName == null), isTrue);

    // The settings table arrives with v2, so it must exist and be writable.
    await db
        .into(db.settingRow)
        .insert(SettingRowCompanion.insert(settingKey: 'base', value: 'VND'));
    expect(await db.selectAllSettings().get(), hasLength(1));
  });

  // The two old columns said overlapping things, and neither one alone was
  // enough: `kind` was the only place a document was named, `categoryId` the
  // only place insurance was. v3 folded them into one classification; v6 turns
  // that classification into a shelf id.
  //
  // Without the catalogue, `SUBSCRIPTION` and `BILL` cannot say *which* shelf
  // -- they spanned seventeen and four -- so they land somewhere honest rather
  // than somewhere guessed. The paperwork ones each had exactly one shelf they
  // could mean and keep it.
  test('the old classification becomes a shelf', () async {
    final db = SubdockDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final byId = {for (final row in await db.selectAll().get()) row.id: row};

    expect(byId['netflix']?.category, 'OTHER');
    expect(byId['hsd']?.category, 'OTHER');
    expect(
      byId['pvi']?.category,
      'INSURANCE',
      reason: 'a RECURRING row filed under insurance is insurance',
    );
  });

  // The app hands in a resolver backed by the service catalogue, which does
  // know that Netflix is streaming. Same file, same migration, a better answer
  // -- and the one the user actually gets.
  test('a resolver that knows the name shelves it properly', () async {
    final db = SubdockDatabase(
      NativeDatabase(file),
      reshelve: (name, legacy) =>
          name == 'Netflix' ? 'STREAMING' : legacyCategoryByCode(name, legacy),
    );
    addTearDown(db.close);

    final byId = {for (final row in await db.selectAll().get()) row.id: row};

    expect(byId['netflix']?.category, 'STREAMING');
  });

  // Every shipped shelf is written on the way up, so an item moved onto one
  // has somewhere to land and the foreign key holds.
  test('the shipped shelves are seeded by the upgrade', () async {
    final db = SubdockDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final shelves = await db.selectAllCategories().get();
    expect(shelves.map((c) => c.id), contains('STREAMING'));
    expect(shelves, hasLength(defaultCategories.length));
    expect(shelves.every((c) => c.builtIn), isTrue);
  });

  test(
    'the migrated file has dropped every column the product removed',
    () async {
      final db = SubdockDatabase(NativeDatabase(file));
      await db.selectAll().get(); // opening is lazy; force the migration
      await db.close();

      final raw = sqlite3.open(file.path);
      addTearDown(raw.close);

      expect(raw.select('PRAGMA user_version;').single['user_version'], 7);

      final columns = raw
          .select('PRAGMA table_info(itemRow);')
          .map((r) => r['name'] as String);
      expect(
        columns,
        containsAll([
          'category',
          'repeatCount',
          'iconName',
          // Added in v4, and reached from v1 through the v3 rebuild rather
          // than through its own step. The rebuild copies the current schema
          // out of the old table, so a column missing from this list makes the
          // whole upgrade fail on a name the old file never had.
          'purchaseChannel',
          // Same again for v5. Every one of these reaches a v1 file through
          // the rebuild, not through its own addColumn step.
          'inTrial',
          'paymentSourceId',
          'paused',
          'yearlyChoice',
        ]),
      );
      expect(columns, isNot(contains('stake')));
      // v7 replaced the trial start date with a flag. A v1 file never had the
      // column, but the rebuild recreates the table at the current schema, so
      // this also catches a schema that quietly kept it.
      expect(columns, isNot(contains('trialStart')));
      expect(columns, isNot(contains('kind')));
      expect(columns, isNot(contains('categoryId')));
      expect(columns, isNot(contains('groupId')));

      // Rows that predate the question read as UNKNOWN, which is what is true
      // of them: nobody was ever asked where they bought it.
      expect(
        raw
            .select('SELECT purchaseChannel FROM itemRow;')
            .map((r) => r['purchaseChannel'] as String)
            .toSet(),
        {'UNKNOWN'},
      );

      // Nothing was paused before the switch existed, which is what the
      // default says about every row that predates it.
      expect(
        raw
            .select('SELECT paused FROM itemRow;')
            .map((r) => r['paused'] as int)
            .toSet(),
        {0},
      );

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((r) => r['name'] as String);
      expect(tables, isNot(contains('itemGroupRow')));
      // The v5 table has to exist on every upgrade path, not just the short
      // one: paymentSourceId carries a REFERENCES clause pointing at it.
      expect(tables, contains('paymentSourceRow'));
      // A failed rebuild leaves this behind; a clean one never does.
      expect(tables.where((name) => name.startsWith('tmp_for_copy')), isEmpty);
    },
  );

  // The path every already-installed copy takes, and the one the v1 tests
  // above cannot cover: a v1 file goes through the v3 rebuild, which recreates
  // itemRow at the current schema and so picks up every later column for free.
  // A v4 file takes the `addColumn` branch instead, one statement per column,
  // and a column listed in the rebuild but forgotten there fails on a real
  // device and nowhere else.
  group('a v4 file', () {
    late Directory v4dir;
    late File v4file;

    setUp(() {
      v4dir = Directory.systemTemp.createTempSync('subdock_v4');
      v4file = File('${v4dir.path}/db.sqlite');

      final raw = sqlite3.open(v4file.path);
      raw.execute(schemaV4);
      raw.execute(seedV4);
      raw.execute('PRAGMA user_version = 4');
      raw.close();
    });

    tearDown(() => v4dir.deleteSync(recursive: true));

    test('gains the v5 columns without losing a row', () async {
      final db = SubdockDatabase(NativeDatabase(v4file));
      addTearDown(db.close);

      final rows = await db.selectAll().get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.name), contains('Netflix Premium'));

      // Every existing row reads as what is true of it: not in a trial, no
      // source named, not paused, and never asked about the yearly plan.
      expect(rows.every((r) => r.inTrial == false), isTrue);
      expect(rows.every((r) => r.paymentSourceId == null), isTrue);
      expect(rows.every((r) => r.paused == false), isTrue);
      expect(rows.every((r) => r.yearlyChoice == null), isTrue);

      // The history the foreign key hangs off survives too.
      expect(await db.selectForItem('netflix').get(), hasLength(1));
    });

    test('gains the sources table, writable and linked', () async {
      final db = SubdockDatabase(NativeDatabase(v4file));
      addTearDown(db.close);

      await db
          .into(db.paymentSourceRow)
          .insert(
            PaymentSourceRowCompanion.insert(
              id: 's1',
              name: 'VCB 4412',
              glyph: 'CARD',
              createdAt: 1,
            ),
          );
      await (db.update(db.itemRow)..where((t) => t.id.equals('netflix'))).write(
        const ItemRowCompanion(paymentSourceId: Value('s1')),
      );

      expect(
        (await db.selectById('netflix').getSingle()).paymentSourceId,
        's1',
      );

      // ON DELETE SET NULL, which only holds with the foreign-key pragma
      // beforeOpen sets. Without it the item would keep pointing at a row that
      // no longer exists.
      await (db.delete(
        db.paymentSourceRow,
      )..where((t) => t.id.equals('s1'))).go();
      expect(
        (await db.selectById('netflix').getSingle()).paymentSourceId,
        isNull,
      );
    });

    test('reaches the current version', () async {
      final db = SubdockDatabase(NativeDatabase(v4file));
      await db.selectAll().get();
      await db.close();

      final raw = sqlite3.open(v4file.path);
      addTearDown(raw.close);
      expect(raw.select('PRAGMA user_version;').single['user_version'], 7);
      // A second open must be a no-op rather than a second round of
      // addColumn, which would fail on a duplicate name.
      final again = SubdockDatabase(NativeDatabase(v4file));
      expect(await again.selectAll().get(), hasLength(2));
      await again.close();
    });
  });

  // The version every installed copy is on, and the only one that has a trial
  // to carry. v7 replaces `trialStart` with `inTrial`, which is the first
  // migration in this file that reads an old column and writes its meaning
  // into a new one -- a step the other two fixtures cannot exercise, because
  // in both of them every row is correctly not in a trial whatever the
  // backfill does.
  group('a v6 file', () {
    late Directory v6dir;
    late File v6file;

    setUp(() {
      v6dir = Directory.systemTemp.createTempSync('subdock_v6');
      v6file = File('${v6dir.path}/db.sqlite');

      final raw = sqlite3.open(v6file.path);
      raw.execute(schemaV6);
      raw.execute(seedV6);
      raw.execute('PRAGMA user_version = 6');
      raw.close();
    });

    tearDown(() => v6dir.deleteSync(recursive: true));

    test('turns a trial start date into the flag', () async {
      final db = SubdockDatabase(NativeDatabase(v6file));
      addTearDown(db.close);

      final rows = await db.selectAll().get();
      expect(rows, hasLength(2));

      final byId = {for (final row in rows) row.id: row};
      // The row that had a start date was in a trial; the one that did not was
      // being paid for. Both halves matter: a backfill that set every row, or
      // no row, would still pass one of these two expectations.
      expect(byId['claude']!.inTrial, isTrue);
      expect(byId['netflix']!.inTrial, isFalse);
    });

    test('drops the column it replaced, and keeps the history', () async {
      final db = SubdockDatabase(NativeDatabase(v6file));
      await db.selectAll().get();
      // The rebuild that drops the column copies the whole table. A foreign key
      // pointing into it is the thing most likely to be left dangling.
      expect(await db.selectForItem('claude').get(), hasLength(1));
      await db.close();

      final raw = sqlite3.open(v6file.path);
      addTearDown(raw.close);

      expect(raw.select('PRAGMA user_version;').single['user_version'], 7);

      final columns = raw
          .select('PRAGMA table_info(itemRow);')
          .map((r) => r['name'] as String);
      expect(columns, contains('inTrial'));
      expect(columns, isNot(contains('trialStart')));

      // A failed rebuild leaves this behind; a clean one never does.
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((r) => r['name'] as String);
      expect(tables.where((name) => name.startsWith('tmp_for_copy')), isEmpty);

      expect(raw.select('PRAGMA foreign_key_check;'), isEmpty);
    });

    test('a second open is a no-op', () async {
      final first = SubdockDatabase(NativeDatabase(v6file));
      await first.selectAll().get();
      await first.close();

      final again = SubdockDatabase(NativeDatabase(v6file));
      addTearDown(again.close);
      expect(await again.selectAll().get(), hasLength(2));
    });
  });
}
