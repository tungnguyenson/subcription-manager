import 'package:drift/drift.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/domain/currency_picks.dart';

import 'database.dart';

/// Remembers which currencies the user is billed in, and which of them the
/// totals are stated in.
///
/// Its own store rather than a field on `AppSettings`, and for a sharper
/// reason than [ThemeStore] has: this one must not travel in a backup either,
/// but it also must never be mistaken for something that changes the data. No
/// amount is ever rewritten when this changes. Every [Money] keeps the
/// currency it was entered under; this only decides which one the sums are
/// restated in.
///
/// Null until the user answers, so onboarding can tell "never asked" from
/// "asked, and they said dong".
class CurrencyStore {
  /// The currency the totals speak. Older builds wrote only this row, and it
  /// still means exactly what it meant then, which is why the key did not
  /// change: a build that knew nothing of a second currency wrote a base here,
  /// and reading that row alone still restores a working single-currency app.
  static const String _baseKey = 'base_currency';

  /// The declared set, comma-joined. Absent on every install written before
  /// the list existed, and absence is not an error — [read] falls back to the
  /// base row, which is the same answer that install was running on.
  static const String _listKey = 'currencies';

  final SubdockDatabase _db;

  CurrencyStore(this._db);

  Future<CurrencyPicks?> read() async {
    final rows = await _db.selectAllSettings().get();
    String? base;
    String? list;
    for (final row in rows) {
      if (row.settingKey == _baseKey) base = row.value;
      if (row.settingKey == _listKey) list = row.value;
    }

    // A three-letter code the catalog has never heard of is still a currency,
    // and refusing it here would strand anyone whose choice was written by a
    // later build with a longer list.
    final codes = [
      for (final part in (list ?? '').split(','))
        if (part.trim().length == 3) part.trim().toUpperCase(),
    ];
    final chosen = (base ?? '').trim().length == 3
        ? base!.trim().toUpperCase()
        : null;

    if (codes.isEmpty && chosen == null) return null;
    if (codes.isEmpty) return CurrencyPicks.one(chosen!);
    return CurrencyPicks(codes, base: chosen);
  }

  Future<void> save(CurrencyPicks picks) async {
    await _write(_baseKey, picks.base);
    await _write(_listKey, picks.codes.join(','));
  }

  Future<void> _write(String key, String value) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(settingKey: Value(key), value: Value(value)),
        mode: InsertMode.insertOrReplace,
      );

  /// The best guess to put under the cursor before the user has answered.
  ///
  /// Offered, never applied. The picker still shows what is selected and the
  /// user still has to press on, which is the difference between a default and
  /// a decision made on someone's behalf.
  static CurrencyPicks suggestFor(String? countryCode) {
    final code = _byCountry[countryCode?.toUpperCase()];
    return CurrencyPicks.one(code ?? CurrencyCatalog.featured.first);
  }

  /// Only the countries whose currency this app is likely to be opened in.
  /// A miss falls back to the first featured code, which the user can move.
  static const Map<String, String> _byCountry = {
    'VN': 'VND', 'US': 'USD', 'GB': 'GBP', 'JP': 'JPY', 'KR': 'KRW', //
    'SG': 'SGD', 'MY': 'MYR', 'TH': 'THB', 'ID': 'IDR', 'PH': 'PHP',
    'IN': 'INR', 'AU': 'AUD', 'NZ': 'NZD', 'CA': 'CAD', 'CH': 'CHF',
    'CN': 'CNY', 'HK': 'HKD', 'TW': 'TWD', 'BR': 'BRL', 'MX': 'MXN',
    'DE': 'EUR', 'FR': 'EUR', 'ES': 'EUR', 'IT': 'EUR', 'NL': 'EUR',
    'IE': 'EUR', 'PT': 'EUR', 'AT': 'EUR', 'BE': 'EUR', 'FI': 'EUR',
  };
}
