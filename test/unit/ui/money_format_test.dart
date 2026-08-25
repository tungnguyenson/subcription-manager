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

  // The bug this pair exists to prevent: a field seeded with minor units shows
  // $20.00 as "2000", and the 111 the user then types comes back as $1.11.
  group('the cost field speaks in major units', () {
    test('an amount is offered the way it is written', () {
      expect(MoneyFormat.majorInput(2000, 'USD'), '20');
      expect(MoneyFormat.majorInput(2050, 'USD'), '20.50');
      expect(MoneyFormat.majorInput(2005, 'USD'), '20.05');
      expect(MoneyFormat.majorInput(260000, 'VND'), '260,000');
    });

    test('a typed amount is read back as the same number', () {
      expect(MoneyFormat.parseMajor('111', 'USD'), 11100);
      expect(MoneyFormat.parseMajor('20.50', 'USD'), 2050);
      expect(MoneyFormat.parseMajor('20.5', 'USD'), 2050);
      expect(MoneyFormat.parseMajor('.29', 'USD'), 29);
      expect(MoneyFormat.parseMajor('260,000', 'VND'), 260000);
      expect(MoneyFormat.parseMajor(r'$20', 'USD'), 2000);
    });

    // iOS labels the decimal pad's separator key in the *device's* locale, so a
    // phone set to Vietnamese offers a comma and no full stop at all. Someone
    // entering $32.68 has no way to type a full stop; they type `32,68`, and
    // every comma used to be stripped as a thousands mark. That made it
    // $3,268.00 -- silently, and off by a hundred.
    test('a comma standing in for the decimal point is read as one', () {
      expect(MoneyFormat.parseMajor('32,68', 'USD'), 3268);
      expect(MoneyFormat.parseMajor('20,5', 'USD'), 2050);
      expect(MoneyFormat.parseMajor('0,99', 'USD'), 99);
      expect(MoneyFormat.parseMajor('-32,68', 'USD'), -3268);
    });

    // The narrow half of the same rule. `1,234` is how a thousand is written
    // everywhere, and reading it as 1.234 would be the same size of mistake in
    // the other direction.
    test('a comma that is a thousands mark stays one', () {
      expect(MoneyFormat.parseMajor('1,234', 'USD'), 123400);
      expect(MoneyFormat.parseMajor('260,000', 'USD'), 26000000);
      expect(MoneyFormat.parseMajor('1,234,567', 'USD'), 123456700);
      // A full stop anywhere settles it: the full stop is the point, and every
      // comma beside it is grouping.
      expect(MoneyFormat.parseMajor('1,234.56', 'USD'), 123456);
      // A currency with no minor unit has no decimal point for a comma to be.
      expect(MoneyFormat.parseMajor('1,234', 'VND'), 1234);
    });

    test('a round trip through the field changes nothing', () {
      for (final (minor, currency) in const [
        (2000, 'USD'),
        (2050, 'USD'),
        (1, 'USD'),
        (260000, 'VND'),
        (25, 'VND'),
      ]) {
        expect(
          MoneyFormat.parseMajor(
            MoneyFormat.majorInput(minor, currency),
            currency,
          ),
          minor,
          reason: '$minor $currency',
        );
      }
    });

    // Rounding, not truncation: 20.5 dong is 21 dong. Dropping the half
    // silently would make every seeded USD amount lose a cent on the way to a
    // currency that has none.
    test('more precision than the currency has is rounded half-up', () {
      expect(MoneyFormat.parseMajor('20.5', 'VND'), 21);
      expect(MoneyFormat.parseMajor('20.4', 'VND'), 20);
      expect(MoneyFormat.parseMajor('20.005', 'USD'), 2001);
      expect(MoneyFormat.parseMajor('20.004', 'USD'), 2000);
    });

    test('text that is not an amount reads as no amount at all', () {
      expect(MoneyFormat.parseMajor('', 'USD'), isNull);
      expect(MoneyFormat.parseMajor('  ', 'USD'), isNull);
      expect(MoneyFormat.parseMajor('1.2.3', 'USD'), isNull);
      expect(MoneyFormat.parseMajor('1234567890123456', 'USD'), isNull);
    });
  });
}
