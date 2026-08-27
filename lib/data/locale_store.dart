import 'package:drift/drift.dart';

import 'package:subdock/i18n.dart';

import 'database.dart';

/// Remembers which language the user picked, between launches.
///
/// Its own store rather than a field on `AppSettings`, for the reason
/// [ThemeStore] is one: this is a property of the screen being read, not a
/// decision about how the app behaves, and it must not travel in a backup. A
/// list restored onto someone else's phone should read in that phone owner's
/// language, not in the language of the phone it came from.
///
/// Null until the user answers. That is not the same as "English": onboarding
/// has to know whether it has ever asked, and a store that defaulted to a
/// language would tell it the question was already settled.
class LocaleStore {
  static const String _key = 'app_locale';

  final SubdockDatabase _db;

  LocaleStore(this._db);

  Future<AppLocale?> read() async {
    final rows = await _db.selectAllSettings().get();
    for (final row in rows) {
      if (row.settingKey == _key) return AppLocale.tryParse(row.value);
    }
    return null;
  }

  Future<void> save(AppLocale locale) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_key),
          value: Value(locale.code),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
