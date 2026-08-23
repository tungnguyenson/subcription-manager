import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/money.dart';

void main() {
  // The 100x bug: VND has no minor unit, so the usual "times 100" is wrong.
  test('VND has exponent zero', () {
    expect(Currencies.exponentOf('VND'), 0);
    expect(Currencies.minorUnitsPerMajor('VND'), 1);
    expect(Money.vnd(25000).minor, 25000);
  });

  test('USD has exponent two', () {
    expect(Currencies.exponentOf('USD'), 2);
    expect(Currencies.minorUnitsPerMajor('USD'), 100);
    expect(Money.usd(20).minor, 2000);
    expect(Money.usd(20, 99).minor, 2099);
  });

  test('the other zero-decimal currencies are covered', () {
    for (final code in [
      'JPY', 'KRW', 'ISK', 'XOF', 'XAF', //
      'CLP', 'PYG', 'UGX', 'VUV', 'XPF',
    ]) {
      expect(Currencies.exponentOf(code), 0, reason: '$code is zero-decimal');
    }
  });

  test('three-decimal currencies are covered', () {
    for (final code in ['KWD', 'BHD', 'OMR', 'JOD', 'TND', 'IQD', 'LYD']) {
      expect(Currencies.exponentOf(code), 3, reason: '$code is three-decimal');
    }
  });

  test('unknown currencies fall back to two rather than being rejected', () {
    // Shipped trackers have burned releases adding currencies one batch at a
    // time; an allowlist is the thing being avoided here.
    expect(Currencies.exponentOf('GBP'), 2);
    expect(Currencies.exponentOf('ZZZ'), 2);
  });

  test('exponent lookup is case-insensitive', () {
    expect(Currencies.exponentOf('vnd'), 0);
    expect(Currencies.exponentOf('usd'), 2);
  });

  test('same-currency arithmetic works', () {
    expect(Money.vnd(74000) + Money.vnd(25000), Money.vnd(99000));
    expect(Money.vnd(74000) - Money.vnd(25000), Money.vnd(49000));
    expect(Money.vnd(74000) * 12, Money.vnd(888000));
  });

  test('mixing currencies is a hard error, never a silent conversion', () {
    expect(
      () => Money.vnd(25000) + Money.usd(20),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('currency code must be three letters', () {
    expect(() => Money(100, 'DONG'), throwsA(isA<ArgumentError>()));
    expect(() => Money(100, ''), throwsA(isA<ArgumentError>()));
  });

  // 32-bit ints overflow around 2.1 billion; VND scaled for FX precision
  // passes that. Dart ints are 64-bit everywhere this app runs.
  test('large VND totals do not overflow', () {
    final big = Money.vnd(55000000000);
    expect((big + big).minor, 110000000000);
  });

  test('exponent is exposed on the value itself', () {
    expect(Money.vnd(1).exponent, 0);
    expect(Money.usd(1).exponent, 2);
  });

  test('equality is by value so amounts can be compared directly', () {
    expect(Money.vnd(1000), Money(1000, 'VND'));
    expect(Money.vnd(1000).hashCode, Money(1000, 'VND').hashCode);
    expect(Money.vnd(1000) == Money(1000, 'USD'), isFalse);
  });
}
