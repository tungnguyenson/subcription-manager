import 'package:meta/meta.dart';

/// Money as an integer count of the currency's smallest unit, never a double.
///
/// The trap this type exists to prevent: VND has no minor unit at all (ISO 4217
/// exponent 0), so the near-universal "multiply by 100 to get cents" assumption
/// makes every VND amount 100x too large. See product-spec.md section 6.2.
///
///     $20.00   -> Money(2000, 'USD')    exponent 2
///     25.000d  -> Money(25000, 'VND')   exponent 0
///
/// Dart's `int` is 64-bit on mobile and desktop, which matters: VND scaled for
/// FX precision overflows 32 bits at roughly 55 billion. On the web `int` is a
/// double under the hood and loses precision past 2^53, so this app does not
/// target web.
@immutable
class Money {
  final int minor;
  final String currency;

  Money(this.minor, this.currency) {
    if (currency.length != 3) {
      throw ArgumentError.value(
        currency,
        'currency',
        'must be a 3-letter ISO 4217 code',
      );
    }
  }

  factory Money.vnd(int dong) => Money(dong, 'VND');

  /// Builds from major units, e.g. `Money.usd(20)` is \$20.00.
  factory Money.usd(int dollars, [int cents = 0]) =>
      Money(dollars * 100 + cents, 'USD');

  int get exponent => Currencies.exponentOf(currency);

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minor - other.minor, currency);
  }

  Money operator *(int factor) => Money(minor * factor, currency);

  Money copyWith({int? minor, String? currency}) =>
      Money(minor ?? this.minor, currency ?? this.currency);

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'cannot combine $currency with ${other.currency}; convert first',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => '$minor $currency';
}

/// ISO 4217 decimal digits per currency.
///
/// Deliberately a lookup with a default rather than a fixed allowlist: shipped
/// trackers have burned whole releases adding four currencies at a time
/// (product-spec.md section 10bis). Unknown codes get the common exponent 2.
abstract final class Currencies {
  /// Currencies with no minor unit. The full ISO 4217 exponent-0 set.
  static const _zeroDecimal = <String>{
    'VND', 'JPY', 'KRW', 'BIF', 'CLP', 'DJF', 'GNF', 'ISK', //
    'KMF', 'PYG', 'RWF', 'UGX', 'VUV', 'XAF', 'XOF', 'XPF',
  };

  /// Currencies with three decimal digits.
  static const _threeDecimal = <String>{
    'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND', //
  };

  static const int defaultExponent = 2;

  static int exponentOf(String code) {
    final upper = code.toUpperCase();
    if (_zeroDecimal.contains(upper)) return 0;
    if (_threeDecimal.contains(upper)) return 3;
    return defaultExponent;
  }

  /// 10^exponent: how many minor units make one major unit.
  static int minorUnitsPerMajor(String code) => pow10(exponentOf(code));

  /// Integer 10^[n]. Kept here rather than using `dart:math`'s `pow`, which
  /// returns a `num` and would reintroduce floating point into money maths.
  static int pow10(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}
