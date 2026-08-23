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
