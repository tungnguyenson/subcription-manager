import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/annual_saving_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-24');

  CatalogPlan plan({
    required Cycle cycle,
    required int amountMinor,
    String tier = 'standard',
    String region = 'VN',
    String currency = 'VND',
    String checkedAt = '2026-08-23',
  }) => CatalogPlan(
    tier: tier,
    name: 'Standard',
    region: region,
    currency: currency,
    cycle: cycle,
    amountMinor: amountMinor,
    source: 'https://example.com/pricing',
    checkedAt: checkedAt,
  );

  CatalogEntry entry({
    List<CatalogPlan> plans = const [],
    String? defaultPlan = 'standard',
  }) => CatalogEntry(
    id: 'netflix',
    name: 'Netflix',
    category: Category.subscription,
    plans: plans,
    defaultPlan: defaultPlan,
  );

  /// Netflix Vietnam: 129,000 a month or 1,092,000 a year.
  CatalogEntry netflix({String checkedAt = '2026-08-23'}) => entry(
    plans: [
      plan(cycle: Cycle.monthly, amountMinor: 129000, checkedAt: checkedAt),
      plan(cycle: Cycle.yearly, amountMinor: 1092000, checkedAt: checkedAt),
    ],
  );

  TrackedItem item({
    Cycle? cycle = Cycle.monthly,
    int? amountMinor,
    String? currency,
  }) => TrackedItem(
    id: 'x',
    name: 'Netflix',
    category: Category.subscription,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-09-01'),
    cycle: cycle,
    amountMinor: amountMinor,
    currency: currency,
  );

  group('the main case', () {
    test('says what a year of monthly costs and what a year costs', () {
      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: netflix(),
        today: today,
      );

      expect(copy, isNotNull);
      expect(copy!.headline, 'Save 456,000 ₫ a year');
      expect(copy.monthlyValue, '129,000 ₫ × 12 = 1,548,000 ₫');
      expect(copy.yearlyValue, '1,092,000 ₫');
      expect(copy.sourceLine, 'Listed price, checked 23 Aug 2026');
      expect(copy.stale, isFalse);
    });

    // The multiplication is the part a user can check against their own bill.
    // Folding it into a total would make the block something to believe rather
    // than something to verify.
    test('shows the multiplication rather than only its result', () {
      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: netflix(),
        today: today,
      );
      expect(copy!.monthlyValue, contains('× 12'));
    });
  });

  group('the cases that show nothing', () {
    test('an item with no catalog match', () {
      expect(
        AnnualSavingPresenter.of(item: item(), entry: null, today: today),
        isNull,
      );
    });

    test('a service the vendor sells monthly only', () {
      final monthlyOnly = entry(
        plans: [plan(cycle: Cycle.monthly, amountMinor: 129000)],
      );
      expect(
        AnnualSavingPresenter.of(
          item: item(),
          entry: monthlyOnly,
          today: today,
        ),
        isNull,
      );
    });

    test('an entry with no prices at all, such as an electricity bill', () {
      expect(
        AnnualSavingPresenter.of(
          item: item(),
          entry: entry(defaultPlan: null),
          today: today,
        ),
        isNull,
      );
    });

    // Inviting someone to do the thing they have already done is worse than
    // saying nothing: it reads as the app not knowing what it is looking at.
    test('an item already billed yearly', () {
      expect(
        AnnualSavingPresenter.of(
          item: item(cycle: Cycle.yearly),
          entry: netflix(),
          today: today,
        ),
        isNull,
      );
    });

    test('an item billed every two years', () {
      expect(
        AnnualSavingPresenter.of(
          item: item(cycle: Cycle.every(2, CycleField.year)),
          entry: netflix(),
          today: today,
        ),
        isNull,
      );
    });

    test('a one-off, which has nothing to compare', () {
      expect(
        AnnualSavingPresenter.of(
          item: item(cycle: null),
          entry: netflix(),
          today: today,
        ),
        isNull,
      );
    });

    // Simplize is a real shipped entry: 599,000 a month, 7,188,000 a year,
    // which is exactly twelve of them. The discount is in a promotion the
    // catalogue does not record, so on list price there is nothing to save.
    test('a yearly plan priced at exactly twelve monthly ones', () {
      final flat = entry(
        plans: [
          plan(cycle: Cycle.monthly, amountMinor: 599000),
          plan(cycle: Cycle.yearly, amountMinor: 7188000),
        ],
      );
      expect(
        AnnualSavingPresenter.of(item: item(), entry: flat, today: today),
        isNull,
      );
    });

    test('a quarterly item still gets the block', () {
      expect(
        AnnualSavingPresenter.of(
          item: item(cycle: Cycle.quarterly),
          entry: netflix(),
          today: today,
        ),
        isNotNull,
      );
    });
  });

  group('when the user pays something other than the listed price', () {
    test('says whose number the sum used', () {
      final copy = AnnualSavingPresenter.of(
        item: item(amountMinor: 99000, currency: 'VND'),
        entry: netflix(),
        today: today,
      );

      expect(
        copy!.mismatchLine,
        'Based on the listed price of 129,000 ₫, not the 99,000 ₫ you entered',
      );
      // The arithmetic still runs on the listed price. Subtracting a listed
      // yearly figure from the user's own monthly one would mix two sources
      // into a number that is true of neither.
      expect(copy.headline, 'Save 456,000 ₫ a year');
    });

    test('stays quiet about a difference under a tenth', () {
      final copy = AnnualSavingPresenter.of(
        item: item(amountMinor: 125000, currency: 'VND'),
        entry: netflix(),
        today: today,
      );
      expect(copy!.mismatchLine, isNull);
    });

    test('stays quiet when the item has no price of its own', () {
      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: netflix(),
        today: today,
      );
      expect(copy!.mismatchLine, isNull);
    });

    // A quarterly amount beside a monthly one is not a discrepancy, it is two
    // different quantities. Explaining it as a discrepancy would be wrong.
    test('stays quiet when the item is not billed monthly', () {
      final copy = AnnualSavingPresenter.of(
        item: item(
          cycle: Cycle.quarterly,
          amountMinor: 350000,
          currency: 'VND',
        ),
        entry: netflix(),
        today: today,
      );
      expect(copy!.mismatchLine, isNull);
    });

    test('stays quiet across currencies rather than comparing them', () {
      final copy = AnnualSavingPresenter.of(
        item: item(amountMinor: 599, currency: 'USD'),
        entry: netflix(),
        today: today,
      );
      expect(copy!.mismatchLine, isNull);
    });
  });

  group('as the price ages', () {
    test('a price under a year old is stated plainly', () {
      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: netflix(checkedAt: '2026-01-10'),
        today: today,
      );
      expect(copy!.stale, isFalse);
      expect(copy.savingLead, 'Save');
    });

    test('a price over a year old hedges and asks to be rechecked', () {
      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: netflix(checkedAt: '2025-06-01'),
        today: today,
      );

      expect(copy!.stale, isTrue);
      expect(copy.headline, 'Save about 456,000 ₫ a year');
      expect(copy.sourceLine, contains('check the current price'));
      expect(copy.sourceLine, contains('1 Jun 2025'));
    });

    // The sum is only as fresh as its weaker half. Quoting the newer date
    // would claim the whole block is more current than it is.
    test('quotes the older of the two dates', () {
      final mixed = entry(
        plans: [
          plan(
            cycle: Cycle.monthly,
            amountMinor: 129000,
            checkedAt: '2026-08-23',
          ),
          plan(
            cycle: Cycle.yearly,
            amountMinor: 1092000,
            checkedAt: '2024-02-09',
          ),
        ],
      );

      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: mixed,
        today: today,
      );
      expect(copy!.sourceLine, contains('9 Feb 2024'));
      expect(copy.stale, isTrue);
    });
  });

  group('regions', () {
    test('prefers the Vietnamese price, which is what gets charged here', () {
      final both = entry(
        plans: [
          plan(cycle: Cycle.monthly, amountMinor: 129000),
          plan(cycle: Cycle.yearly, amountMinor: 1092000),
          plan(
            cycle: Cycle.monthly,
            amountMinor: 1799,
            region: 'GLOBAL',
            currency: 'USD',
          ),
          plan(
            cycle: Cycle.yearly,
            amountMinor: 17900,
            region: 'GLOBAL',
            currency: 'USD',
          ),
        ],
      );

      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: both,
        today: today,
      );
      expect(copy!.yearlyValue, '1,092,000 ₫');
    });

    // A VN pair that saves nothing must not block a global pair that does.
    // Preferring the local region is about which number is truer, not about
    // suppressing the answer when the local one has nothing to say.
    test('skips a local pair with no saving in it and uses the global one', () {
      final mixed = entry(
        plans: [
          plan(cycle: Cycle.monthly, amountMinor: 599000),
          plan(cycle: Cycle.yearly, amountMinor: 7188000),
          plan(
            cycle: Cycle.monthly,
            amountMinor: 2000,
            region: 'GLOBAL',
            currency: 'USD',
          ),
          plan(
            cycle: Cycle.yearly,
            amountMinor: 20000,
            region: 'GLOBAL',
            currency: 'USD',
          ),
        ],
      );

      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: mixed,
        today: today,
      );
      expect(copy!.headline, r'Save $40.00 a year');
    });

    test('falls back to the global price when that is all there is', () {
      final global = entry(
        plans: [
          plan(
            cycle: Cycle.monthly,
            amountMinor: 2000,
            region: 'GLOBAL',
            currency: 'USD',
          ),
          plan(
            cycle: Cycle.yearly,
            amountMinor: 20000,
            region: 'GLOBAL',
            currency: 'USD',
          ),
        ],
      );

      final copy = AnnualSavingPresenter.of(
        item: item(),
        entry: global,
        today: today,
      );
      expect(copy!.headline, r'Save $40.00 a year');
      expect(copy.monthlyValue, r'$20.00 × 12 = $240.00');
    });
  });
}
