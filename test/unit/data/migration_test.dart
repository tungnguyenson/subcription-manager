import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/domain/model.dart';

import '../../fixtures/schema_v1.dart';

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

  // The two old columns said overlapping things, and neither one alone is
  // enough: `kind` is the only place a document is named, `categoryId` is the
  // only place insurance is. Folding them wrong reclassifies real items.
  test('kind and categoryId fold into one category', () async {
    final db = SubdockDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final byId = {for (final row in await db.selectAll().get()) row.id: row};

    expect(byId['netflix']?.category, Category.subscription.wireName);
    expect(byId['hsd']?.category, Category.subscription.wireName);
    expect(
      byId['pvi']?.category,
      Category.insurance.wireName,
      reason: 'a RECURRING row filed under insurance is insurance',
    );
  });

  test(
    'the migrated file has dropped every column the product removed',
    () async {
      final db = SubdockDatabase(NativeDatabase(file));
      await db.selectAll().get(); // opening is lazy; force the migration
      await db.close();

      final raw = sqlite3.open(file.path);
      addTearDown(raw.close);

      expect(raw.select('PRAGMA user_version;').single['user_version'], 3);

      final columns = raw
          .select('PRAGMA table_info(itemRow);')
          .map((r) => r['name'] as String);
      expect(columns, containsAll(['category', 'repeatCount', 'iconName']));
      expect(columns, isNot(contains('stake')));
      expect(columns, isNot(contains('kind')));
      expect(columns, isNot(contains('categoryId')));
      expect(columns, isNot(contains('groupId')));

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((r) => r['name'] as String);
      expect(tables, isNot(contains('itemGroupRow')));
      // A failed rebuild leaves this behind; a clean one never does.
      expect(tables.where((name) => name.startsWith('tmp_for_copy')), isEmpty);
    },
  );
}
