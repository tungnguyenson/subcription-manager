import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/savings_presenter.dart';

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

  /// A vendor that charges 260,000 ₫ a month and 2,600,000 ₫ a year, so a year
  /// of monthly is 3,120,000 ₫ and moving saves exactly 520,000 ₫.
  CatalogEntry netflix({
    String? cancelUrl,
    String? manageUrl,
    String sector = 'STREAMING',
    String checkedAt = '2026-08-23',
    int monthly = 260000,
    int yearly = 2600000,
  }) => CatalogEntry(
    id: 'netflix',
    name: 'Netflix Premium',
    aliases: const ['netflix'],
    categoryId: sector,
    defaultCycle: Cycle.monthly,
    cancelUrl: cancelUrl,
    manageUrl: manageUrl,
    plans: [
      plan(cycle: Cycle.monthly, amountMinor: monthly, checkedAt: checkedAt),
      plan(cycle: Cycle.yearly, amountMinor: yearly, checkedAt: checkedAt),
    ],
    defaultPlan: 'standard',
  );

  TrackedItem item(
    String name, {
    String? id,
    String categoryId = 'STREAMING',
    Cycle? cycle = Cycle.monthly,
    int? amountMinor = 260000,
    String currency = 'VND',
    bool inTrial = false,
    YearlyChoice yearlyChoice = YearlyChoice.undecided,
    PurchaseChannel purchaseChannel = PurchaseChannel.unknown,
    ItemState state = ItemState.active,
    bool paused = false,
  }) => TrackedItem(
    id: id ?? name,
    name: name,
    categoryId: categoryId,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-08-01'),
    cycle: cycle,
    amountMinor: amountMinor,
    currency: amountMinor == null ? null : currency,
    leadDays: const [7],
    inTrial: inTrial,
    yearlyChoice: yearlyChoice,
    purchaseChannel: purchaseChannel,
    state: state,
    paused: paused,
  );

  SavingsView build(
    List<TrackedItem> items,
    List<CatalogEntry> entries, {
    LocalDate? on,
  }) => SavingsPresenter.build(
    categories: CategoryBook.shipped,
    items: items,
    catalog: ServiceCatalog(entries),
    today: on ?? today,
    defaultLeadDays: const [3],
  );

  group('move to yearly', () {
    test('the total is the exact difference, not a rounded one', () {
      final view = build([item('Netflix Premium')], [netflix()]);

      expect(view.yearly, hasLength(1));
      expect(view.total, '520,000 ₫');
      expect(view.yearly.single.saving, '−520,000 ₫');
    });

    // The multiplication is what lets a user whose own price differs redo the
    // sum in their head instead of trusting the total.
    test('the row shows the sum, not only its answer', () {
      final view = build([item('Netflix Premium')], [netflix()]);

      expect(
        view.yearly.single.compare,
        '260,000 ₫ × 12 → 2,600,000 ₫ · 17% less',
      );
    });

    // Two currencies are never folded into one figure. The bundled rate is good
    // enough to orient someone behind a tilde; it is not good enough inside a
    // sentence that claims "you would keep exactly this much".
    test('two currencies are shown side by side, never converted', () {
      final view = build(
        [
          item('Netflix Premium'),
          item('Claude Pro', amountMinor: 2000, currency: 'USD'),
        ],
        [
          netflix(),
          CatalogEntry(
            id: 'claude',
            name: 'Claude Pro',
            categoryId: 'STREAMING',
            defaultCycle: Cycle.monthly,
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
            defaultPlan: 'standard',
          ),
        ],
      );

      expect(view.total, '520,000 ₫ + \$40.00');
    });

    // Some vendors list the yearly plan at exactly twelve monthly payments and
    // put the discount in a promotion instead. "Save 0 ₫ a year" is not a
    // smaller version of this row, it is a different and much worse one.
    test('a zero saving is not a suggestion', () {
      final view = build(
        [item('Netflix Premium')],
        [netflix(yearly: 260000 * 12)],
      );

      expect(view.yearly, isEmpty);
      expect(view.unpriced, hasLength(1));
    });

    test('a plan with no yearly price is listed, not dropped', () {
      final view = build([item('Mystery service')], const []);

      expect(view.yearly, isEmpty);
      expect(view.unpriced.single.name, 'Mystery service');
      expect(view.leftOut, contains('1 plan with no yearly price'));
    });

    test('a skipped suggestion is counted but not shown', () {
      final view = build(
        [item('Netflix Premium', yearlyChoice: YearlyChoice.skipped)],
        [netflix()],
      );

      expect(view.yearly, isEmpty);
      expect(view.skipped, 1);
    });

    // Everything left out is named. A savings screen that quietly considers
    // half the list is a savings screen whose total cannot be trusted.
    test('what was left out is stated, with why', () {
      final view = build(
        [
          item('Netflix Premium'),
          item('Adobe', cycle: Cycle.yearly),
          item('Claude Pro', inTrial: true),
        ],
        [netflix()],
      );

      expect(view.leftOut, 'Left out: 1 already yearly · 1 in a trial');
    });

    // The button names the day the reminder actually lands, which is the
    // item's own furthest-out lead — not the renewal date itself.
    test('the reminder date is the lead date, not the renewal', () {
      final view = build([item('Netflix Premium')], [netflix()]);

      // 01/09 renewal, 7-day lead on the item.
      expect(view.yearly.single.remindOn, '25/08');
    });

    // A listed price is not the price the user pays. Where the two disagree by
    // more than a tenth, the row says so rather than letting the sum look wrong.
    test('a price the user disagrees with is called out', () {
      final view = build(
        [item('Netflix Premium', amountMinor: 190000)],
        [netflix()],
      );

      expect(
        view.yearly.single.note,
        'Listed price is 260,000 ₫, not the 190,000 ₫ you entered.',
      );
    });

    test('a price over a year old is flagged rather than quoted', () {
      final view = build(
        [item('Netflix Premium')],
        [netflix(checkedAt: '2025-01-05')],
      );

      expect(view.yearly.single.stale, isTrue);
      expect(view.yearly.single.note, contains('check it first'));
    });

    // A paused service is still being charged: the switch stops reminders, not
    // the vendor.
    test('a paused item still counts', () {
      final view = build([item('Netflix Premium', paused: true)], [netflix()]);

      expect(view.yearly, hasLength(1));
    });

    test('an archived item does not', () {
      final view = build(
        [item('Netflix Premium', state: ItemState.inactive)],
        [netflix()],
      );

      expect(view.yearly, isEmpty);
      expect(view.unpriced, isEmpty);
    });
  });

  group('cancel a service', () {
    test('entertainment is the easiest group and utilities the hardest', () {
      final view = build(
        [
          item('Netflix Premium'),
          item('iCloud+', categoryId: 'STORAGE', amountMinor: 89000),
        ],
        [
          netflix(),
          const CatalogEntry(
            id: 'icloud',
            name: 'iCloud+',
            aliases: ['icloud'],
            categoryId: 'STREAMING',
            defaultCycle: Cycle.monthly,
          ),
        ],
      );

      expect(view.groups.map((g) => g.label), [
        'Entertainment',
        'Hard to drop',
      ]);
      expect(view.groups.last.discouraged, isTrue);
    });

    // "I have no idea what this is" and "do not suggest dropping it" are the
    // same answer, so a service on a shelf the table does not rank -- one the
    // user made -- lands in the discouraged group.
    test('a service on a shelf nobody has ranked is not nudged', () {
      final view = build([
        item('Something local', categoryId: 'MY_OWN_SHELF'),
      ], const []);

      expect(view.groups.single.label, 'Hard to drop');
      expect(view.groups.single.discouraged, isTrue);
    });

    test('the group total is a year of what is in it', () {
      final view = build([item('Netflix Premium')], [netflix()]);

      expect(view.groups.single.total, '−3,120,000 ₫/yr');
      expect(view.groups.single.rows.single.yearly, '−3,120,000 ₫/yr');
    });

    // A subscription with no amount entered contributes nothing and says so,
    // rather than being estimated into the total.
    test('an item with no amount contributes nothing', () {
      final view = build(
        [item('Netflix Premium', amountMinor: null)],
        [netflix()],
      );

      expect(view.groups.single.rows.single.yearly, '—');
      expect(view.groups.single.total, '—');
    });

    test('a document is not offered for cancelling at all', () {
      final view = build([
        item('Passport', categoryId: 'DOCUMENTS', cycle: Cycle.yearly),
      ], const []);

      expect(view.groups, isEmpty);
    });

    group('where it is cancelled', () {
      test('the cancel page wins when the catalogue has one', () {
        final target = SavingsPresenter.cancelTarget(
          item('Netflix Premium'),
          netflix(cancelUrl: 'https://netflix.com/cancelplan'),
        );

        expect(target.via, 'Web');
        expect(target.where, 'netflix.com/cancelplan');
        expect(target.canOpen, isTrue);
      });

      // Where they bought it beats where the vendor would like them to go: a
      // subscription billed through the App Store will not even appear on the
      // vendor's own page.
      test('the store wins over the vendor page', () {
        final target = SavingsPresenter.cancelTarget(
          item('Netflix Premium', purchaseChannel: PurchaseChannel.appStore),
          netflix(cancelUrl: 'https://netflix.com/cancelplan'),
        );

        expect(target.via, 'App Store');
        expect(target.where, contains('Subscriptions'));
      });

      // Cancelling almost always lives inside the account page, and "Account
      // page" says what is being offered rather than claiming the link cancels.
      test('the account page is offered when there is no cancel page', () {
        final target = SavingsPresenter.cancelTarget(
          item('Netflix Premium'),
          netflix(manageUrl: 'https://netflix.com/account'),
        );

        expect(target.via, 'Account page');
        expect(target.canOpen, isTrue);
      });

      // The common case: 25 of 223 catalogue entries carry a cancel page. It is
      // stated rather than papered over with a button to a search results page.
      test('nothing is invented when the app knows nowhere', () {
        final target = SavingsPresenter.cancelTarget(
          item('Something local'),
          null,
        );

        expect(target.canOpen, isFalse);
        expect(target.action, isNull);
        expect(target.where, contains('no cancel page'));
      });
    });
  });

  group('the lead line', () {
    test('counts how many of the monthly plans are worth moving', () {
      final items = [item('Netflix Premium'), item('Mystery service')];
      final view = build(items, [netflix()]);

      expect(
        view.leadFor(
          SavingsTab.yearly,
          SavingsPresenter.monthlyCount(items, CategoryBook.shipped, today),
        ),
        '1 of 2 monthly plans cost less yearly.',
      );
    });

    test('says so plainly when there is nothing to move', () {
      final view = build([item('Mystery service')], const []);

      expect(view.leadFor(SavingsTab.yearly, 1), 'Nothing to move right now.');
    });
  });
}
