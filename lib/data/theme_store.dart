import 'package:drift/drift.dart';

import 'database.dart';

/// Which of the two Glass variants to paint in.
///
/// Three values rather than a switch, because [system] is a real answer and
/// not the absence of one: a phone that turns dark at sunset is telling the
/// app something, and an on/off switch can only ignore it or fight it.
enum ThemeChoice {
  /// Follow the phone. The default, and the only value that can change what
  /// the app looks like while it is open.
  system,
  light,
  dark;

  /// What is written to the settings row. Spelled out rather than stored as an
  /// index: an index reorders itself the day someone adds a fourth value, and
  /// silently repaints everyone's app.
  String get key => name;

  static ThemeChoice? tryParse(String raw) {
    for (final choice in values) {
      if (choice.key == raw) return choice;
    }
    return null;
  }
}

/// Remembers which variant the user picked, between launches.
///
/// Its own store rather than a field on `AppSettings`, for the same reason
/// [FilterStore] is: this is not a preference about how the app *behaves*, it
/// is a property of the screen it is being read on. It also must not travel in
/// a backup — a list restored onto a second phone should look like that phone,
/// not like the one it came from.
///
/// Both directions are lenient. A row written by a newer build, or half
/// overwritten, reads back as [ThemeChoice.system] — the worst outcome of that
/// is an app that follows the phone, and the worst outcome of throwing here is
/// an app that cannot open.
class ThemeStore {
  static const String _key = 'theme_choice';

  final SubdockDatabase _db;

  ThemeStore(this._db);

  Future<ThemeChoice> read() async {
    final rows = await _db.selectAllSettings().get();
    for (final row in rows) {
      if (row.settingKey == _key) {
        return ThemeChoice.tryParse(row.value) ?? ThemeChoice.system;
      }
    }
    return ThemeChoice.system;
  }

  Future<void> save(ThemeChoice choice) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_key),
          value: Value(choice.key),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
