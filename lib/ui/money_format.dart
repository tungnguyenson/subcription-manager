import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';

/// Rendering money for a Vietnamese reader.
///
/// Deliberately hand-written rather than `intl`'s `NumberFormat`. Two reasons:
/// the exponent has to come from [Currencies], which already owns the ISO 4217
/// table and knows VND has no minor unit, and formatting must not follow the
/// device locale. An amount the user typed as 260.000 must not come back as
/// 260,000.00 because their phone is set to English.
abstract final class MoneyFormat {
  /// The full amount with its symbol: `260,000 ₫`, `$20.00`.
  static String full(Money money) {
    final exponent = money.exponent;
    final symbol = _symbols[money.currency.toUpperCase()];

    if (exponent == 0) {
      final digits = grouped(money.minor);
      return symbol == null ? '$digits ${money.currency}' : '$digits $symbol';
    }

    final unit = Currencies.pow10(exponent);
    final major = money.minor ~/ unit;
    final minor = (money.minor % unit).abs().toString().padLeft(exponent, '0');
    final digits = '${grouped(major)}.$minor';

    return symbol == null ? '$digits ${money.currency}' : '$symbol$digits';
  }

  /// Abbreviated for a small stat card, where the exact figure is available a
  /// tap away and the column is 150px wide.
  static String short(Money money) {
    final symbol = _symbols[money.currency.toUpperCase()] ?? money.currency;
    final major = money.minor / Currencies.pow10(money.exponent);

    if (major.abs() >= 1000000) {
      // One decimal, with a bare `.0` dropped, so 14.9 and 120 both read
      // cleanly. Rounding 14.9 up to 15 would overstate a figure whose whole
      // job is to be roughly right.
      final millions = major / 1000000;
      final text = millions
          .toStringAsFixed(1)
          .replaceFirst(RegExp(r'\.0$'), '');
      return money.exponent == 0 ? '$text triệu $symbol' : '$symbol${text}M';
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
    var text = raw.replaceAll(RegExp(r'[\s,_ ₫$]'), '');
    if (text.isEmpty) return null;

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

    final exponent = Currencies.exponentOf(currency);
    // One digit past the currency's precision, which is the one that decides
    // the rounding.
    final padded = fraction.padRight(exponent + 1, '0');
    final kept = exponent == 0 ? 0 : int.parse(padded.substring(0, exponent));
    final roundUp = int.parse(padded[exponent]) >= 5;

    final minor = whole * Currencies.pow10(exponent) + kept + (roundUp ? 1 : 0);
    return negative ? -minor : minor;
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
    final from = _symbols[rate.from.toUpperCase()] ?? rate.from;
    final to = _symbols[rate.to.toUpperCase()] ?? rate.to;
    return '${grouped(whole)} $to/$from';
  }

  /// Day-first, which is how dates are written in Vietnam.
  static String date(LocalDate date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  static String shortDate(LocalDate date) =>
      '${_pad(date.day)}/${_pad(date.month)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static const Map<String, String> _symbols = {'VND': '₫', 'USD': r'$'};
}
