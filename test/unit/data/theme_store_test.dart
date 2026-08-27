import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/theme_store.dart';

void main() {
  late SubdockDatabase db;
  late ThemeStore store;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    store = ThemeStore(db);
  });

  tearDown(() => db.close());

  test('nothing stored follows the phone', () async {
    expect(await store.read(), ThemeChoice.system);
  });

  test('every choice survives the round trip', () async {
    for (final choice in ThemeChoice.values) {
      await store.save(choice);
      expect(await store.read(), choice);
    }
  });

  // Written by a newer build, or half overwritten. The worst outcome of
  // falling back is an app that follows the phone; the worst outcome of
  // throwing is an app that cannot open.
  test('a value this build does not know follows the phone', () async {
    await db
        .into(db.settingRow)
        .insert(
          SettingRowCompanion(
            settingKey: const Value('theme_choice'),
            value: const Value('solarized'),
          ),
          mode: InsertMode.insertOrReplace,
        );

    expect(await store.read(), ThemeChoice.system);
  });

  // The stored value is the name, not the index. An index reorders itself the
  // day someone adds a fourth choice, and silently repaints everyone's app.
  test('the choice is stored by name, not by position', () async {
    await store.save(ThemeChoice.dark);

    final rows = await db.selectAllSettings().get();
    final row = rows.firstWhere((r) => r.settingKey == 'theme_choice');
    expect(row.value, 'dark');
  });
}
