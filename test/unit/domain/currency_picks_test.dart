import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/currency_picks.dart';

void main() {
  group('CurrencyPicks', () {
    test('normalises rather than refusing what it is handed', () {
      final picks = CurrencyPicks(['vnd', ' usd ', 'VND', '', 'EUR']);

      // Upper-cased, de-duplicated, and cut at the cap. Lenient on purpose:
      // this is read back from a settings row an older build wrote, and a
      // throw here would leave a user with no currency at all.
      expect(picks.codes, ['VND', 'USD']);
      expect(picks.base, 'VND');
    });

    test('a base outside the list is pulled into it', () {
      expect(CurrencyPicks(['VND'], base: 'usd').codes, ['USD', 'VND']);
      expect(CurrencyPicks(['VND'], base: 'usd').base, 'USD');
    });

    test('adding leaves the base where it is', () {
      final picks = CurrencyPicks.one('VND').add('USD');

      // "I am billed in this too" is not "state my totals in this".
      expect(picks.codes, ['VND', 'USD']);
      expect(picks.base, 'VND');
    });

    test('a full list takes nothing more, and a duplicate changes nothing', () {
      final picks = CurrencyPicks(['VND', 'USD'], base: 'VND');

      expect(picks.add('EUR'), picks);
      expect(CurrencyPicks.one('VND').add('vnd'), CurrencyPicks.one('VND'));
    });

    // A list with no base is not a state any screen can render.
    test('removing the base hands the job to what is left', () {
      final picks = CurrencyPicks(['VND', 'USD'], base: 'USD').remove('USD');

      expect(picks.codes, ['VND']);
      expect(picks.base, 'VND');
    });

    test('the last currency cannot be removed', () {
      final picks = CurrencyPicks.one('VND');
      expect(picks.remove('VND'), picks);
    });

    test('replacing a slot leaves the other slot alone', () {
      final picks = CurrencyPicks([
        'VND',
        'USD',
      ], base: 'VND').replace('USD', 'EUR');

      expect(picks.codes, ['VND', 'EUR']);
      expect(picks.base, 'VND');
    });

    test('replacing the base moves the base with it', () {
      final picks = CurrencyPicks([
        'VND',
        'USD',
      ], base: 'VND').replace('VND', 'JPY');

      expect(picks.codes, ['JPY', 'USD']);
      expect(picks.base, 'JPY');
    });

    test('replacing a slot with the other slot collapses to one', () {
      final picks = CurrencyPicks([
        'VND',
        'USD',
      ], base: 'VND').replace('USD', 'VND');

      expect(picks.codes, ['VND']);
      expect(picks.base, 'VND');
    });

    test('a base already declared is promoted without disturbing the list', () {
      final picks = CurrencyPicks(['VND', 'USD'], base: 'VND').withBase('USD');

      expect(picks.codes, ['VND', 'USD']);
      expect(picks.base, 'USD');
    });

    test('a base not yet declared joins the list', () {
      final picks = CurrencyPicks.one('VND').withBase('USD');

      expect(picks.codes, ['VND', 'USD']);
      expect(picks.base, 'USD');
    });

    // The base slot gives way, not the other one. Someone changing which
    // currency their totals speak is editing that answer; the second currency
    // is a separate answer they gave on purpose.
    test('a full list gives up its base rather than its second currency', () {
      final picks = CurrencyPicks(['VND', 'USD'], base: 'VND').withBase('EUR');

      expect(picks.codes, ['EUR', 'USD']);
      expect(picks.base, 'EUR');
    });

    // The list is drawn in its order, so two picks that differ only in order
    // are two different screens.
    test('order counts', () {
      expect(
        CurrencyPicks(['VND', 'USD'], base: 'VND'),
        isNot(CurrencyPicks(['USD', 'VND'], base: 'VND')),
      );
    });
  });
}
