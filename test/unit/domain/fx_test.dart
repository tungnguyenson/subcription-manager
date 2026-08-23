import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  final rate = Fx.bundledUsdVnd;

  test('converts USD to VND at the bundled rate', () {
    // $20.00 at 26,046 = 520,920 dong.
    expect(rate.convert(Money.usd(20)), Money.vnd(520920));
  });

  test('conversion handles cents', () {
    // $22.99 at 26,046 = 598,797.54 -> 598,798 after one final rounding.
    expect(rate.convert(Money.usd(22, 99)), Money.vnd(598798));
  });

  test('converting the wrong currency is rejected rather than guessed', () {
    expect(() => rate.convert(Money.vnd(1000)), throwsA(isA<ArgumentError>()));
  });

  test('age is measured from the rate date', () {
    expect(rate.ageInDays(today), 1);
    expect(rate.isStale(today), isFalse);
  });

  test('a rate older than the display limit is stale', () {
    expect(rate.isStale(LocalDate.parse('2026-10-01')), isTrue);
  });

  test('same-currency amounts total exactly with no rate needed', () {
    final total = Fx.total(
      [Money.vnd(74000), Money.vnd(25000)],
      rate: rate,
      today: today,
    );
    expect(total.perCurrency['VND'], Money.vnd(99000));
    expect(total.approximateBase, Money.vnd(99000));
    expect(total.unconvertedCount, 0);
  });

  test('mixed currencies keep exact per-currency subtotals', () {
    final total = Fx.total(
      [Money.vnd(618000), Money.usd(20), Money.usd(19, 99)],
      rate: rate,
      today: today,
    );
    expect(total.perCurrency['VND'], Money.vnd(618000));
    expect(total.perCurrency['USD'], Money.usd(39, 99));
  });

  test('the approximate base total includes converted rows', () {
    final total = Fx.total(
      [Money.vnd(618000), Money.usd(20)],
      rate: rate,
      today: today,
    );
    expect(total.approximateBase, Money.vnd(618000 + 520920));
    expect(total.rate, isNotNull);
  });

  // The Firefly III bug: a missing rate defaulting to 1 turns $20 into 20 dong,
  // wrong by four orders of magnitude but shaped like a plausible number.
  test(
    'an unconvertible currency is excluded and counted, never one-to-one',
    () {
      final total = Fx.total(
        [Money.vnd(100000), Money(5000, 'EUR')],
        rate: rate,
        today: today,
      );

      expect(
        total.approximateBase,
        Money.vnd(100000),
        reason: 'EUR must not leak in at rate 1',
      );
      expect(total.unconvertedCount, 1);
      expect(total.perCurrency['EUR'], Money(5000, 'EUR'));
    },
  );

  test('with no rate at all only base-currency rows are totalled', () {
    final total = Fx.total([Money.vnd(100000), Money.usd(20)]);
    expect(total.approximateBase, Money.vnd(100000));
    expect(total.unconvertedCount, 1);
    expect(total.rate, isNull);
  });

  test('a stale rate is refused so no confident wrong number is shown', () {
    final total = Fx.total(
      [Money.usd(20)],
      rate: rate,
      today: LocalDate.parse('2026-12-01'),
    );
    expect(total.approximateBase, isNull);
    expect(total.rate, isNull);
    expect(total.unconvertedCount, 1);
  });

  test('an all-foreign list with no usable rate yields no base total', () {
    final total = Fx.total([Money(100, 'GBP')], rate: rate, today: today);
    expect(total.approximateBase, isNull);
  });

  test('an empty list totals to nothing rather than zero', () {
    final total = Fx.total([], rate: rate, today: today);
    expect(total.perCurrency, isEmpty);
    expect(total.approximateBase, isNull);
  });

  test('rate rejects nonsense values', () {
    expect(
      () => FxRate(
        from: 'USD',
        to: 'VND',
        scaled: -1,
        scale: 4,
        asOf: today,
        source: 'x',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => FxRate(
        from: 'USD',
        to: 'VND',
        scaled: 1,
        scale: -1,
        asOf: today,
        source: 'x',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
