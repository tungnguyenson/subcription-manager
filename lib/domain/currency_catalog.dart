import 'package:meta/meta.dart';

/// One currency, as far as the interface is concerned.
///
/// The decimal places are not here: [Currencies] already owns that table and
/// answers for codes this list has never heard of. What this file adds is the
/// two things a lookup table cannot infer — the mark people write it with, and
/// which side of the digits that mark goes on.
@immutable
class CurrencyInfo {
  final String code;

  /// The symbol, or the code again where a currency has no distinct one.
  /// `CHF` is written `CHF`, and printing a made-up glyph would be worse.
  final String symbol;

  /// Whether the symbol goes before the digits: `$20.00` against `260,000 ₫`.
  ///
  /// Per currency rather than derived from the decimal places. The old rule
  /// keyed off the exponent, which put the yen's mark after the digits because
  /// the dong's goes there — and `1,200 ¥` is written by nobody.
  final bool symbolLeads;

  const CurrencyInfo(this.code, this.symbol, {this.symbolLeads = true});
}

/// The currencies the picker offers, and the symbols money is printed with.
///
/// Not the whole ISO 4217 list. A picker of 180 rows is a scrolling exercise,
/// and the tail of it is currencies nobody reading this app is paid in. The
/// cut is "a currency with a consumer subscription market", plus every one in
/// the region the app was written in. A code outside the list still works
/// everywhere — [Currencies] knows its decimals and [symbolOf] falls back to
/// the code — it simply is not offered in the list.
abstract final class CurrencyCatalog {
  /// The four the picker shows before the search: written down rather than
  /// taken off the top of [all], so reordering the list cannot quietly change
  /// what the first screen of onboarding offers.
  static const List<String> featured = ['VND', 'USD', 'EUR', 'JPY'];

  static const List<CurrencyInfo> all = [
    CurrencyInfo('VND', '₫', symbolLeads: false),
    CurrencyInfo('USD', r'$'),
    CurrencyInfo('EUR', '€'),
    CurrencyInfo('JPY', '¥'),
    CurrencyInfo('GBP', '£'),
    CurrencyInfo('AUD', r'A$'),
    CurrencyInfo('CAD', r'C$'),
    CurrencyInfo('CHF', 'CHF'),
    CurrencyInfo('CNY', '¥'),
    CurrencyInfo('HKD', r'HK$'),
    CurrencyInfo('TWD', r'NT$'),
    CurrencyInfo('KRW', '₩'),
    CurrencyInfo('SGD', r'S$'),
    CurrencyInfo('MYR', 'RM'),
    CurrencyInfo('THB', '฿'),
    CurrencyInfo('IDR', 'Rp'),
    CurrencyInfo('PHP', '₱'),
    CurrencyInfo('INR', '₹'),
    CurrencyInfo('PKR', '₨'),
    CurrencyInfo('BDT', '৳'),
    CurrencyInfo('LKR', 'Rs'),
    CurrencyInfo('KHR', '៛', symbolLeads: false),
    CurrencyInfo('LAK', '₭', symbolLeads: false),
    CurrencyInfo('MMK', 'K'),
    CurrencyInfo('NZD', r'NZ$'),
    CurrencyInfo('SEK', 'kr', symbolLeads: false),
    CurrencyInfo('NOK', 'kr', symbolLeads: false),
    CurrencyInfo('DKK', 'kr', symbolLeads: false),
    CurrencyInfo('PLN', 'zł', symbolLeads: false),
    CurrencyInfo('CZK', 'Kč', symbolLeads: false),
    CurrencyInfo('HUF', 'Ft', symbolLeads: false),
    CurrencyInfo('RON', 'lei', symbolLeads: false),
    CurrencyInfo('TRY', '₺'),
    CurrencyInfo('RUB', '₽', symbolLeads: false),
    CurrencyInfo('UAH', '₴'),
    CurrencyInfo('ILS', '₪'),
    CurrencyInfo('AED', 'AED'),
    CurrencyInfo('SAR', 'SAR'),
    CurrencyInfo('QAR', 'QAR'),
    CurrencyInfo('KWD', 'KWD'),
    CurrencyInfo('EGP', 'E£'),
    CurrencyInfo('ZAR', 'R'),
    CurrencyInfo('NGN', '₦'),
    CurrencyInfo('KES', 'KSh'),
    CurrencyInfo('GHS', '₵'),
    CurrencyInfo('MAD', 'MAD'),
    CurrencyInfo('BRL', r'R$'),
    CurrencyInfo('MXN', r'MX$'),
    CurrencyInfo('ARS', r'$'),
    CurrencyInfo('CLP', r'CLP$'),
    CurrencyInfo('COP', r'COP$'),
    CurrencyInfo('PEN', 'S/'),
  ];

  static final Map<String, CurrencyInfo> _byCode = {
    for (final info in all) info.code: info,
  };

  static CurrencyInfo? find(String code) => _byCode[code.toUpperCase()];

  /// The mark to print, falling back to the code itself.
  ///
  /// Never a guess. A currency with no symbol in the table prints as `100 XPF`,
  /// which is correct and readable; inventing a glyph for it would be the one
  /// failure mode this app does not accept — looking more certain than it is.
  static String symbolOf(String code) =>
      find(code)?.symbol ?? code.toUpperCase();

  static bool symbolLeads(String code) => find(code)?.symbolLeads ?? true;

  /// The one pair the app carries a bundled rate for.
  static const Set<String> ratedPair = {'USD', 'VND'};

  /// Whether the app holds a rate that can turn [code] into [base], either way
  /// round. False means every screen still totals each currency exactly, and
  /// the single combined figure is simply absent.
  static bool hasRate(String code, String base) {
    final pair = {code.toUpperCase(), base.toUpperCase()};
    return pair.length == 1 || pair.difference(ratedPair).isEmpty;
  }

  /// Whether picking [code] as the base leaves the combined total working.
  ///
  /// Asked by the picker so it can say so *before* the choice is made. The
  /// alternative is a Money screen that quietly stops showing one number, and
  /// a user with no way to connect that to a tap they made in onboarding.
  static bool isConvertible(String code) =>
      ratedPair.contains(code.toUpperCase());
}
