import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/money_format.dart';

void main() {
  // The 100x bug at the display layer: VND has no minor unit, so 260000 is two
  // hundred sixty thousand dong, never 2,600.00.
  test('VND is written whole, with no decimal part', () {
    expect(MoneyFormat.full(Money.vnd(260000)), '260,000 ₫');
    expect(MoneyFormat.full(Money.vnd(1240000)), '1,240,000 ₫');
    expect(MoneyFormat.full(Money.vnd(500)), '500 ₫');
  });

  test('USD keeps exactly two decimals with the symbol in front', () {
    expect(MoneyFormat.full(Money.usd(20)), r'$20.00');
    expect(MoneyFormat.full(Money.usd(22, 99)), r'$22.99');
    expect(MoneyFormat.full(Money.usd(0, 5)), r'$0.05');
  });

  test('a currency with no symbol falls back to its code', () {
    expect(MoneyFormat.full(Money(5000, 'EUR')), '50.00 EUR');
    expect(MoneyFormat.full(Money(1000, 'JPY')), '1,000 JPY');
  });

  test('a three-decimal currency keeps all three', () {
    expect(MoneyFormat.full(Money(1234, 'KWD')), '1.234 KWD');
  });

  test('grouping inserts a comma every three digits', () {
    expect(MoneyFormat.grouped(1), '1');
    expect(MoneyFormat.grouped(999), '999');
    expect(MoneyFormat.grouped(1000), '1,000');
    expect(MoneyFormat.grouped(1000000), '1,000,000');
    expect(MoneyFormat.grouped(-1234567), '-1,234,567');
  });

  test('large figures abbreviate on a stat card', () {
    expect(MoneyFormat.short(Money.vnd(14900000)), '14.9 triệu ₫');
    expect(MoneyFormat.short(Money.vnd(120000000)), '120 triệu ₫');
    expect(MoneyFormat.short(Money.vnd(861200)), '861,200 ₫');
  });

  test(
    'the rate is written with both symbols so its direction is readable',
    () {
      expect(MoneyFormat.rate(Fx.bundledUsdVnd), r'26,046 ₫/$');
    },
  );

  // Using the device locale here would render 17/08 as 08/17 for a reader whose
  // phone is set to English, and the two are indistinguishable on screen.
  test('dates are day-first regardless of device locale', () {
    final date = LocalDate.parse('2026-08-05');
    expect(MoneyFormat.date(date), '05/08/2026');
    expect(MoneyFormat.shortDate(date), '05/08');
  });
}
