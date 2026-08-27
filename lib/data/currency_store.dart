import 'package:drift/drift.dart';

import 'package:subdock/domain/currency_catalog.dart';

import 'database.dart';

/// Remembers which currency the totals are stated in.
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
  static const String _key = 'base_currency';

  final SubdockDatabase _db;

  CurrencyStore(this._db);

  Future<String?> read() async {
    final rows = await _db.selectAllSettings().get();
    for (final row in rows) {
      if (row.settingKey == _key) {
        final code = row.value.toUpperCase();
        // A three-letter code the catalog has never heard of is still a
        // currency, and refusing it here would strand anyone whose choice was
        // written by a later build with a longer list.
        if (code.length == 3) return code;
      }
    }
    return null;
  }

  Future<void> save(String code) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_key),
          value: Value(code.toUpperCase()),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// The best guess to put under the cursor before the user has answered.
  ///
  /// Offered, never applied. The picker still shows what is selected and the
  /// user still has to press on, which is the difference between a default and
  /// a decision made on someone's behalf.
  static String suggestFor(String? countryCode) {
    final code = _byCountry[countryCode?.toUpperCase()];
    return code ?? CurrencyCatalog.featured.first;
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
