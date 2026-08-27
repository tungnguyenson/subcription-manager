import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/i18n.dart';

/// Rendering money.
///
/// Deliberately hand-written rather than `intl`'s `NumberFormat`. Two reasons:
/// the exponent has to come from [Currencies], which already owns the ISO 4217
/// table and knows VND has no minor unit, and formatting must not follow the
/// *device* locale. An amount the user typed as 260.000 must not come back as
/// 260,000.00 because their phone is set to English.
///
/// The one thing that does follow the app's language is the abbreviation on a
/// stat card, because that is a word rather than a number. Everything else
/// here — grouping, decimals, which side the symbol goes on — is a property of
/// the currency and stays put when the interface changes tongue.
abstract final class MoneyFormat {
  /// The full amount with its symbol: `260,000 ₫`, `$20.00`.
  static String full(Money money) {
    final exponent = money.exponent;

    if (exponent == 0) {
      return _withSymbol(grouped(money.minor), money.currency);
    }

    final unit = Currencies.pow10(exponent);
    final major = money.minor ~/ unit;
    final minor = (money.minor % unit).abs().toString().padLeft(exponent, '0');

    return _withSymbol('${grouped(major)}.$minor', money.currency);
  }

  /// Puts the currency's mark on the side that currency writes it.
  ///
  /// A code with no symbol of its own prints as `1,200 XPF`, spaced, because
  /// `XPF1,200` reads as one token and the reader cannot tell where the code
  /// stops and the number starts.
  static String _withSymbol(String digits, String currency) {
    final info = CurrencyCatalog.find(currency);
    // A currency whose "symbol" is its own code has no glyph -- `CHF`, `KWD`,
    // and anything the catalog has never heard of. Those trail the digits with
    // a space: `KWD1.234` reads as one token and the eye cannot find where the
    // code stops and the number starts.
    if (info == null || info.symbol == info.code) {
      return '$digits ${info?.symbol ?? currency.toUpperCase()}';
    }
    if (!info.symbolLeads) return '$digits ${info.symbol}';
    return '${info.symbol}$digits';
  }

  /// Abbreviated for a small stat card, where the exact figure is available a
  /// tap away and the column is 150px wide.
  static String short(Money money) {
    final symbol = CurrencyCatalog.symbolOf(money.currency);
    final major = money.minor / Currencies.pow10(money.exponent);

    if (major.abs() >= 1000000) {
      // One decimal, with a bare `.0` dropped, so 14.9 and 120 both read
      // cleanly. Rounding 14.9 up to 15 would overstate a figure whose whole
      // job is to be roughly right.
      final millions = major / 1000000;
      final text = millions
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      // Whether the word or the letter is used follows the currency, not the
      // language: `14.2 triệu ₫` is how a seven-figure dong amount is spoken
      // in either tongue, and `$14.2M` is how a dollar one is. The language
      // only decides which word stands in for `triệu`.
      return S.t.millions(text, symbol, minorUnits: money.exponent > 0);
    }
    return full(money);
  }

  /// The amount as the user would type it, in major units: `20`, `20.50`,
  /// `260,000`. What goes into the cost field.
  ///
  /// Minor units are the storage format, not an input format. A field seeded
  /// with `2000` for $20.00 reads as two thousand dollars, and the next digit
  /// the user types lands two decimal places away from where they aimed it.
  static String majorInput(int minor, String currency) {
    final exponent = Currencies.exponentOf(currency);
    final unit = Currencies.pow10(exponent);
    final major = minor ~/ unit;
    final fraction = (minor % unit).abs();

    // A round amount is offered without its zeros: `20`, not `20.00`. The
    // decimals are what the user would have to delete before typing anything
    // else, and they carry no information here.
    if (fraction == 0) return grouped(major);

    final digits = fraction.toString().padLeft(exponent, '0');
    return '${grouped(major)}.$digits';
  }

  /// Reads a typed major-unit amount back into minor units, or null when the
  /// text is not a number.
  ///
  /// Tolerant of what a real keyboard produces: grouping commas, a stray
  /// symbol, spaces. Strict about the one thing that matters — the arithmetic
  /// runs on digit strings, never on a double, so `0.29` cannot arrive as 28
  /// cents. Anything finer than the currency allows is rounded half-up, so
  /// `20.5` under VND is 21 dong rather than a silent truncation to 20.
  static int? parseMajor(String raw, String currency) {
    var text = raw.replaceAll(RegExp(r'[\s_ ₫$]'), '');
    if (text.isEmpty) return null;

    final exponent = Currencies.exponentOf(currency);
    // Work out what a comma meant *before* throwing commas away. See
    // [_decimalised].
    text = _decimalised(text, exponent).replaceAll(',', '');

    final negative = text.startsWith('-');
    if (negative) text = text.substring(1);

    final parts = text.split('.');
    if (parts.length > 2) return null;

    final wholeText = parts[0].isEmpty ? '0' : parts[0];
    // 15 digits keeps the whole calculation inside a 64-bit int even after the
    // exponent shift; past that the parse fails rather than wrapping.
    if (wholeText.length > 15 || !_digits.hasMatch(wholeText)) return null;
    final whole = int.parse(wholeText);

    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.isNotEmpty && !_digits.hasMatch(fraction)) return null;

    // One digit past the currency's precision, which is the one that decides
    // the rounding.
    final padded = fraction.padRight(exponent + 1, '0');
    final kept = exponent == 0 ? 0 : int.parse(padded.substring(0, exponent));
    final roundUp = int.parse(padded[exponent]) >= 5;

    final minor = whole * Currencies.pow10(exponent) + kept + (roundUp ? 1 : 0);
    return negative ? -minor : minor;
  }

  /// Rewrites a comma that is standing in for the decimal point.
  ///
  /// iOS renders the decimal pad's separator key in the *device's* locale, so a
  /// phone set to Vietnamese offers a comma and no full stop at all. Someone
  /// entering \$32.68 has no way to type a full stop, types `32,68`, and every
  /// comma used to be stripped as a thousands mark — which turned it into
  /// \$3,268.00. Silently, and off by a hundred, which is exactly the shape of
  /// mistake this app must never make with a number the user typed.
  ///
  /// The rule is narrow on purpose, because `1,234` genuinely is grouping:
  /// a lone comma is a decimal point only when there is no full stop anywhere,
  /// the currency has decimals at all, and the digits after it would fit in
  /// them. Three digits after a comma stay grouping, which is every real
  /// thousands mark ever written.
  static String _decimalised(String text, int exponent) {
    if (exponent == 0) return text;
    // A full stop present means the full stop is the point and every comma is
    // grouping — `1,234.56` reads the way it looks.
    if (text.contains('.')) return text;

    final at = text.indexOf(',');
    if (at < 0 || text.indexOf(',', at + 1) >= 0) return text;

    final after = text.length - at - 1;
    if (after < 1 || after > exponent) return text;

    return '${text.substring(0, at)}.${text.substring(at + 1)}';
  }

  static final RegExp _digits = RegExp(r'^\d+$');

  /// Thousands separated with a comma.
  ///
  /// Vietnamese usage also allows a dot, but this app puts dong and dollars on
  /// the same screen, and a dot beside `$20.00` reads as a decimal point.
  static String grouped(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// The rate itself, e.g. `26,046 ₫/$`.
  static String rate(FxRate rate) {
    final whole = rate.scaled ~/ Currencies.pow10(rate.scale);
    final from = CurrencyCatalog.symbolOf(rate.from);
    final to = CurrencyCatalog.symbolOf(rate.to);
    return '${grouped(whole)} $to/$from';
  }

  /// Day-first, which is how dates are written in Vietnam.
  static String date(LocalDate date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  static String shortDate(LocalDate date) =>
      '${_pad(date.day)}/${_pad(date.month)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
