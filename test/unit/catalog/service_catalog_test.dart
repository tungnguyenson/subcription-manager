import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/catalog/bundled_data.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/reminders.dart';
import 'package:subdock/ui/item_presenter.dart';

void main() {
  // Read straight off disk rather than through the asset bundle: this is a
  // check on the shipped data file itself, and going through Flutter's asset
  // loader would only prove that pubspec lists it.
  final catalog = BundledData.parseCatalog(
    File('assets/services.json').readAsStringSync(),
  );
  final lookup = ServiceCatalog(catalog.entries);

  group('the bundled data', () {
    test('parses and is large enough to be useful', () {
      expect(catalog.entries.length, greaterThanOrEqualTo(60));
    });

    test('entry ids are unique', () {
      final ids = catalog.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every category has a label the picker can show', () {
      for (final category in Category.values) {
        expect(ItemPresenter.categoryLabel(category), isNotEmpty);
      }
    });

    // A catalog entry that classified itself as "Other" would be a row that
    // knows the service and still makes the user choose.
    test('no entry falls back to Other', () {
      for (final entry in catalog.entries) {
        expect(
          entry.category,
          isNot(Category.other),
          reason: '${entry.id} is unclassified',
        );
      }
    });
  });

  group('prices', () {
    test('an amount always comes with a currency', () {
      for (final entry in catalog.entries) {
        if (entry.typicalAmountMinor != null) {
          expect(
            entry.currency,
            isNotNull,
            reason: '${entry.id} has no currency',
          );
        }
      }
    });

    // The 100x bug, checked against real data: VND has no minor unit, so a
    // price that was multiplied or divided by 100 lands outside this range.
    test('VND prices are plausible whole dong, not cents', () {
      for (final entry in catalog.entries) {
        if (entry.currency != 'VND') continue;
        final amount = entry.typicalAmountMinor;
        if (amount == null) continue;
        expect(
          amount,
          greaterThanOrEqualTo(1000),
          reason: '${entry.id} looks divided by 100',
        );
        expect(
          amount,
          lessThan(100000000),
          reason: '${entry.id} looks multiplied by 100',
        );
      }
    });

    test('USD prices are in cents and plausible', () {
      for (final entry in catalog.entries) {
        if (entry.currency != 'USD') continue;
        final cents = entry.typicalAmountMinor;
        if (cents == null) continue;
        expect(
          cents,
          inInclusiveRange(99, 50000),
          reason: '${entry.id} is out of range',
        );
      }
    });

    // Netflix VN and iCloud with a VN Apple ID bill in dong, not dollars.
    // Getting this wrong would make the whole FX story look bigger than it is.
    test('Vietnam-billed services are priced in dong', () {
      for (final id in ['netflix', 'icloud', 'youtube-premium']) {
        expect(
          lookup.byId(id)?.currency,
          'VND',
          reason: '$id should bill in VND',
        );
      }
    });

    test('the genuinely dollar-billed services are priced in dollars', () {
      for (final id in ['claude', 'chatgpt']) {
        expect(
          lookup.byId(id)?.currency,
          'USD',
          reason: '$id should bill in USD',
        );
      }
    });
  });

  group('categories and links', () {
    test(
      'the catalog carries documents, bills and insurance, not just apps',
      () {
        for (final category in const [
          Category.document,
          Category.bill,
          Category.insurance,
        ]) {
          expect(
            catalog.entries.where((e) => e.category == category),
            isNotEmpty,
            reason: 'nothing in the catalog is a ${category.wireName}',
          );
        }
      },
    );

    // A deadline that arrives silently during Focus is a deadline the app
    // failed to deliver. Only a subscription renewing is mere news.
    test('everything that is not a subscription is time-sensitive', () {
      for (final entry in catalog.entries) {
        expect(
          Reminders.isTimeSensitive(entry.category),
          entry.category != Category.subscription,
          reason: entry.id,
        );
      }
    });

    test('cancel urls are https', () {
      for (final entry in catalog.entries) {
        final url = entry.cancelUrl;
        if (url == null) continue;
        expect(
          url,
          startsWith('https://'),
          reason: 'insecure cancel url on ${entry.id}',
        );
      }
    });
  });

  group('search', () {
    test('typing a prefix surfaces the obvious match first', () {
      expect(lookup.search('net').first.id, 'netflix');
      expect(lookup.search('claude').first.id, 'claude');
    });

    test('search ignores case and Vietnamese diacritics', () {
      expect(lookup.search('hộ chiếu').first.id, 'ho-chieu');
      expect(lookup.search('HO CHIEU').first.id, 'ho-chieu');
      expect(lookup.search('điện').first.id, 'dien');
    });

    test('aliases match so common shorthand works', () {
      expect(lookup.search('openai').first.id, 'chatgpt');
      expect(lookup.search('mobi').first.id, 'sim-mobifone');
    });

    test('an empty query suggests nothing rather than everything', () {
      expect(lookup.search(''), isEmpty);
      expect(lookup.search('   '), isEmpty);
    });

    test('a nonsense query matches nothing', () {
      expect(lookup.search('zzzqqq'), isEmpty);
    });

    test('results are capped so the suggestion list stays scannable', () {
      expect(lookup.search('s', limit: 3).length, lessThanOrEqualTo(3));
    });
  });

  group('parsing is strict about what it cannot interpret', () {
    test('an unknown kind is refused rather than defaulted', () {
      expect(
        () => BundledData.parseCatalog(
          '{"schemaVersion":1,"generatedAt":"x","entries":['
          '{"id":"a","name":"A","kind":"NOT_A_KIND","categoryId":"cloud"}]}',
        ),
        throwsFormatException,
      );
    });

    test('a missing required field is refused', () {
      expect(
        () => BundledData.parseCatalog(
          '{"schemaVersion":1,"generatedAt":"x","entries":[{"id":"a"}]}',
        ),
        throwsFormatException,
      );
    });

    test('an unknown top-level key is ignored so a newer file still loads', () {
      final bundle = BundledData.parseCatalog(
        '{"schemaVersion":1,"generatedAt":"x","futureKey":true,"entries":[]}',
      );
      expect(bundle.entries, isEmpty);
    });
  });
}
