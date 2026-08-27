import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/money.dart';

void main() {
  final today = LocalDate.parse('2026-08-20');

  tearDown(() => Fx.publishBase(Fx.defaultBase));

  group('the currency the totals are stated in', () {
    test('is the dong until someone says otherwise', () {
      expect(Fx.base, 'VND');
    });

    // The app bundles one rate, USD to VND. Which of the two the user counts
    // in is their choice, not the rate's -- refusing to read it backwards
    // would leave someone who picked dollars with no combined total at all.
    test('reads the one bundled rate in whichever direction it is needed', () {
      Fx.publishBase('USD');

      final total = Fx.total(
        [Money.usd(20), Money.vnd(260460)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );

      expect(total.approximateBase, Money.usd(30));
      expect(total.converted, isTrue);
      expect(total.unconvertedCount, 0);
    });

    // Every amount keeps the currency it was entered in. Only the sums move.
    test('leaves the per-currency subtotals exactly where they were', () {
      Fx.publishBase('USD');

      final total = Fx.total(
        [Money.usd(20), Money.vnd(260460)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );

      expect(total.perCurrency['USD'], Money.usd(20));
      expect(total.perCurrency['VND'], Money.vnd(260460));
    });

    // A third currency is allowed and everything still adds up on its own.
    // What goes away is the single combined figure, and `unconvertedCount` is
    // what lets the screen say so instead of quietly reporting a short total.
    test('a currency with no rate drops out of the total and is counted', () {
      Fx.publishBase('EUR');

      final total = Fx.total(
        [Money(5000, 'EUR'), Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );

      expect(total.approximateBase, Money(5000, 'EUR'));
      expect(total.converted, isFalse);
      expect(total.unconvertedCount, 1);
    });
  });

  group('the currency catalogue', () {
    test('says which pair the app can actually relate', () {
      expect(CurrencyCatalog.isConvertible('VND'), isTrue);
      expect(CurrencyCatalog.isConvertible('usd'), isTrue);
      expect(CurrencyCatalog.isConvertible('EUR'), isFalse);
    });

    // Never a guess. A code with no symbol prints as its code, which is
    // correct and readable; inventing a glyph would be the one failure mode
    // this app does not accept.
    test('falls back to the code rather than inventing a mark', () {
      expect(CurrencyCatalog.symbolOf('XPF'), 'XPF');
      expect(CurrencyCatalog.symbolOf('vnd'), '₫');
    });

    test('every featured code is one the catalogue carries', () {
      for (final code in CurrencyCatalog.featured) {
        expect(CurrencyCatalog.find(code), isNotNull, reason: code);
      }
    });
  });
}
