import 'package:meta/meta.dart';

import 'local_date.dart';
import 'money.dart';

/// An exchange rate as a scaled integer, plus where and when it came from.
///
/// Provenance is not optional metadata. Free rate sources disagree by around
/// 0.2% on the same day, which is larger than any rounding this code could
/// introduce, so a stored rate without its source silently rewrites history
/// when the source changes. See product-spec.md section 6.4.
@immutable
class FxRate {
  final String from;
  final String to;

  /// rate * 10^[scale], e.g. 26046.0 at scale 4 is 260_460_000.
  final int scaled;
  final int scale;
  final LocalDate asOf;
  final String source;

  FxRate({
    required this.from,
    required this.to,
    required this.scaled,
    required this.scale,
    required this.asOf,
    required this.source,
  }) {
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'must not be negative');
    }
    if (scaled <= 0) {
      throw ArgumentError.value(scaled, 'scaled', 'rate must be positive');
    }
  }

  int ageInDays(LocalDate today) => asOf.daysUntil(today);

  bool isStale(LocalDate today, {int maxAgeDays = Fx.maxDisplayAgeDays}) =>
      ageInDays(today) > maxAgeDays;

  /// Converts an amount, widening to the target currency's exponent before
  /// rounding once at the end rather than per line item.
  Money convert(Money amount) {
    if (amount.currency != from) {
      throw ArgumentError('rate converts $from, not ${amount.currency}');
    }

    final fromExponent = Currencies.exponentOf(from);
    final toExponent = Currencies.exponentOf(to);

    // Work in the target's minor units: value_major * rate * 10^toExponent.
    final numerator = amount.minor * scaled * Currencies.pow10(toExponent);
    final denominator =
        Currencies.pow10(scale) * Currencies.pow10(fromExponent);

    return Money(_roundHalfUp(numerator, denominator), to);
  }

  /// Converts the other way, from [to] back to [from].
  ///
  /// Not `1 / rate` applied with [convert]: inverting a scaled integer rate
  /// throws away precision before the multiplication rather than after it, and
  /// on a rate of 26,046 that is visible in the dong. Dividing by the same
  /// rate instead keeps the arithmetic exact until the single final rounding.
  Money invert(Money amount) {
    if (amount.currency != to) {
      throw ArgumentError(
        'rate converts back from $to, not ${amount.currency}',
      );
    }

    final fromExponent = Currencies.exponentOf(from);
    final toExponent = Currencies.exponentOf(to);

    final numerator =
        amount.minor * Currencies.pow10(scale) * Currencies.pow10(fromExponent);
    final denominator = scaled * Currencies.pow10(toExponent);

    return Money(_roundHalfUp(numerator, denominator), from);
  }

  static int _roundHalfUp(int numerator, int denominator) {
    final quotient = numerator ~/ denominator;
    final remainder = numerator % denominator;
    return remainder * 2 >= denominator ? quotient + 1 : quotient;
  }

  @override
  bool operator ==(Object other) =>
      other is FxRate &&
      other.from == from &&
      other.to == to &&
      other.scaled == scaled &&
      other.scale == scale &&
      other.asOf == asOf &&
      other.source == source;

  @override
  int get hashCode => Object.hash(from, to, scaled, scale, asOf, source);
}

/// The result of totalling a mixed-currency list.
@immutable
class MixedTotal {
  /// The truth: one exact subtotal per currency. Always shown.
  final Map<String, Money> perCurrency;

  /// Orientation only. Null when no usable rate exists.
  final Money? approximateBase;

  /// Whether a rate was actually applied to build [approximateBase].
  ///
  /// False when every amount was already in the base currency, and that case
  /// is not a detail: the figure is then exact to the dong, and a UI that
  /// prints a tilde over it is claiming an imprecision it did not incur. Also
  /// false when a foreign amount was dropped for want of a usable rate --
  /// what survives is still exact, and [unconvertedCount] is what says it is
  /// incomplete.
  final bool converted;

  final FxRate? rate;

  /// Items excluded because no rate covered them. Must be surfaced, not hidden.
  final int unconvertedCount;

  const MixedTotal({
    required this.perCurrency,
    required this.approximateBase,
    required this.converted,
    required this.rate,
    required this.unconvertedCount,
  });
}

abstract final class Fx {
  static const String baseCurrency = 'VND';

  /// Past this age the converted line is hidden entirely rather than shown
  /// with a stale date. A confident wrong number is worse than no number.
  static const int maxDisplayAgeDays = 30;

  /// Rate compiled into the binary, refreshed at release time. VND is a managed
  /// crawling peg that drifts about 2% a year, so a six-month-old bundled rate
  /// is roughly 1% off, which is invisible behind a tilde. This is what lets
  /// the app work forever with no network. See spec section 6.4.
  static final FxRate bundledUsdVnd = FxRate(
    from: 'USD',
    to: 'VND',
    scaled: 260460000,
    scale: 4,
    asOf: LocalDate.parse('2026-08-14'),
    source: 'bundled',
  );

  /// Totals a mixed-currency list.
  ///
  /// Never defaults a missing rate to 1. Firefly III does, which turns a \$20
  /// charge into 20 dong: wrong by four orders of magnitude but shaped like a
  /// plausible number. Here an unconvertible row stays in its own currency,
  /// drops out of the approximate total, and is counted so the UI can say so.
  static MixedTotal total(
    List<Money> amounts, {
    FxRate? rate,
    LocalDate? today,
    String base = baseCurrency,
  }) {
    final perCurrency = <String, Money>{};
    for (final amount in amounts) {
      final running = perCurrency[amount.currency];
      perCurrency[amount.currency] = running == null
          ? amount
          : running + amount;
    }

    final usableRate = (rate != null && today != null && rate.isStale(today))
        ? null
        : rate;

    var approx = 0;
    var unconverted = 0;
    var hasBaseContribution = false;
    var converted = false;

    for (final entry in perCurrency.entries) {
      final currency = entry.key;
      final money = entry.value;

      if (currency == base) {
        approx += money.minor;
        hasBaseContribution = true;
      } else if (usableRate != null &&
          usableRate.from == currency &&
          usableRate.to == base) {
        approx += usableRate.convert(money).minor;
        hasBaseContribution = true;
        converted = true;
      } else {
        unconverted++;
      }
    }

    return MixedTotal(
      perCurrency: Map.unmodifiable(perCurrency),
      approximateBase: hasBaseContribution ? Money(approx, base) : null,
      converted: converted,
      rate: usableRate,
      unconvertedCount: unconverted,
    );
  }
}
