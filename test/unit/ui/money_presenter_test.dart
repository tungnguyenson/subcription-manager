import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/money_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-15');

  TrackedItem item(
    String name, {
    String expiresOn = '2026-08-20',
    String categoryId = 'STREAMING',
    Cycle? cycle = Cycle.monthly,
    int? amountMinor = 260000,
    String currency = 'VND',
    LocalDate? trialStart,
    ItemState state = ItemState.active,
    bool paused = false,
  }) => TrackedItem(
    id: name,
    name: name,
    categoryId: categoryId,
    expiresOn: d(expiresOn),
    anchorDate: d(expiresOn),
    cycle: cycle,
    amountMinor: amountMinor,
    currency: amountMinor == null ? null : currency,
    trialStart: trialStart,
    state: state,
    paused: paused,
  );

  MoneyView view(List<TrackedItem> items, MoneySpan span) =>
      MoneyPresenter.build(
        categories: CategoryBook.shipped,
        items: items,
        today: today,
        span: span,
      );

  group('this month', () {
    test('counts what falls inside the calendar month and nothing else', () {
      final month = view([
        item('Netflix', expiresOn: '2026-08-20'),
        item('Spotify', expiresOn: '2026-09-04', amountMinor: 59000),
      ], MoneySpan.month);

      expect(month.items.map((i) => i.name), ['Netflix']);
    });

    test('the breakdown is biggest first', () {
      final month = view([
        item('Netflix', amountMinor: 260000),
        item('Electricity', amountMinor: 842000, categoryId: 'UTILITIES'),
      ], MoneySpan.month);

      expect(month.items.map((i) => i.name), ['Electricity', 'Netflix']);
    });

    // A document costs money to renew but is not a subscription, and folding it
    // into a monthly figure makes the total answer a question nobody asked.
    test('a document is never counted', () {
      final month = view([
        item('Passport', categoryId: 'DOCUMENTS', cycle: null),
      ], MoneySpan.month);

      expect(month.items, isEmpty);
    });

    // The amount on a trial is what the user *will* pay. Putting a figure
    // nobody has been charged into "this month" makes the total a different
    // number from the one that will leave their account.
    test('a trial is listed separately, never in the total', () {
      final month = view([
        item('Netflix'),
        item('Claude Pro', trialStart: d('2026-08-10'), amountMinor: 520000),
      ], MoneySpan.month);

      expect(month.items.map((i) => i.name), ['Netflix']);
      expect(month.trials.single.name, 'Claude Pro');
      expect(month.trials.single.cost, '520,000 ₫');
      expect(month.trials.single.startsCharging, '20/08');
    });

    // A service switched off is still being charged: the switch stops
    // reminders, not the vendor.
    test('a paused item still counts', () {
      final month = view([item('Netflix', paused: true)], MoneySpan.month);

      expect(month.items, hasLength(1));
    });

    test('an archived item does not', () {
      final month = view([
        item('Netflix', state: ItemState.archived),
      ], MoneySpan.month);

      expect(month.items, isEmpty);
    });
  });

  group('next twelve months', () {
    test('a monthly charge is carried twelve times forward', () {
      final year = view([item('Netflix')], MoneySpan.year);

      expect(year.total.perCurrency['VND']?.minor, 260000 * 12);
    });

    test('a yearly charge is counted once', () {
      final year = view([
        item('Adobe', cycle: Cycle.yearly, amountMinor: 5290000),
      ], MoneySpan.year);

      expect(year.total.perCurrency['VND']?.minor, 5290000);
    });

    // A one-off is a single charge. Multiplying it by anything, or counting it
    // once inside a figure labelled "per year", puts a number in the total that
    // does not recur.
    test('a one-off is left out of a recurring total', () {
      final year = view([item('Deposit', cycle: null)], MoneySpan.year);

      expect(year.total.perCurrency, isEmpty);
    });

    test('the three bands split the total without overlapping', () {
      final year = view([
        item('Netflix', amountMinor: 260000),
        item('Electricity', amountMinor: 842000, categoryId: 'UTILITIES'),
        item(
          'Car insurance',
          amountMinor: 4800000,
          categoryId: 'INSURANCE',
          cycle: Cycle.yearly,
        ),
      ], MoneySpan.year);

      expect(year.bands.map((b) => b.label), [
        'Subscriptions',
        'Bills and utilities',
        'Charged once a year',
      ]);
      // A yearly insurance premium is in the annual band, not the bills one:
      // the cycle decides before the category does.
      expect(year.bands[1].total.minor, 842000 * 12);
      expect(year.bands[2].total.minor, 4800000);
      expect(
        year.bands.fold<int>(0, (n, b) => n + b.total.minor),
        year.total.approximateBase?.minor,
      );
    });

    test('the year span names itself', () {
      expect(view([item('Netflix')], MoneySpan.year).label, 'Next 12 months');
    });

    // One number said twice, so the two can never disagree: converted from the
    // base total rather than summed on its own. The per-currency subtotals that
    // used to sit here were correct and unreadable -- three groups of figures
    // on one card, two of them decompositions of the same total.
    test('a mixed total is restated in the other currency', () {
      final year = view([
        item('Netflix', amountMinor: 260000),
        item('Claude', amountMinor: 2000, currency: 'USD'),
      ], MoneySpan.year);

      // 3,120,000 ₫ + $240.00 at 26,046 = 9,371,040 ₫, back at the same rate.
      expect(year.total.approximateBase?.minor, 9371040);
      // The rate rides on this line rather than on one of its own at the foot
      // of the card: it is what makes both figures approximate, and beside the
      // figure it produced it reads as an explanation instead of trivia.
      expect(year.alternateTotal, r'≈ $359.79 (26,046 ₫/$)');
    });

    // The tilde stands for one thing: a foreign amount went through the
    // bundled rate. Multiplying a dong figure by a cycle is exact, and a
    // tilde over it claims an imprecision the arithmetic never incurred.
    test('a dong-only total is not marked approximate', () {
      final year = view([item('Netflix', amountMinor: 260000)], MoneySpan.year);

      expect(year.total.converted, isFalse);
      expect(year.bands.every((band) => !band.converted), isTrue);
    });

    test('a total with a converted amount in it is marked approximate', () {
      final year = view([
        item('Netflix', amountMinor: 260000),
        item('Claude', amountMinor: 2000, currency: 'USD'),
      ], MoneySpan.year);

      expect(year.total.converted, isTrue);
    });

    // Band by band, not card-wide. A card can hold one band of dong and one
    // band with dollars in it, and only the second is approximate.
    test('a band of dong keeps its exact figure beside a converted one', () {
      final year = view([
        item('Electricity', amountMinor: 842000, categoryId: 'UTILITIES'),
        item('Claude', amountMinor: 2000, currency: 'USD'),
      ], MoneySpan.year);

      final bands = {for (final band in year.bands) band.label: band};
      expect(bands['Bills and utilities']!.converted, isFalse);
      expect(bands['Subscriptions']!.converted, isTrue);
    });

    // Which currencies a person keeps is a fact about them, not about March.
    // A restatement that came and went with the month moved the chart under
    // the reader's thumb every time they tapped a column.
    test('every month is restated once any item is in another currency', () {
      final items = [
        item('Netflix', expiresOn: '2026-08-20', amountMinor: 260000),
        item(
          'Claude',
          expiresOn: '2026-09-04',
          amountMinor: 2000,
          currency: 'USD',
        ),
      ];

      MoneyView at(int month) => MoneyPresenter.build(
        categories: CategoryBook.shipped,
        items: items,
        today: today,
        span: MoneySpan.month,
        month: month,
      );

      // August is charged in dong only, and still carries the dollar line.
      expect(at(8).total.converted, isFalse);
      expect(at(8).alternateTotal, isNotNull);
      expect(at(9).alternateTotal, isNotNull);
    });

    // A dong figure restated in dollars answers a question a dong-only user
    // never asked.
    test('a single-currency total is not restated', () {
      final year = view([item('Netflix', amountMinor: 260000)], MoneySpan.year);

      expect(year.alternateTotal, isNull);
    });

    // Forty annualised figures answer nothing anybody asked.
    test('the year view drops the per-item list', () {
      final year = view([item('Netflix')], MoneySpan.year);

      expect(year.items, isEmpty);
      expect(year.bands, isNotEmpty);
    });
  });

  // The chart is derived from the list, not from what has been marked paid.
  // Everything the app needs is already on the item: an amount, a cycle, and
  // an anchor the cycle counts from.
  // The chart is derived from the list, not from what has been marked paid.
  // Everything the app needs is already on the item: an amount, a cycle, and
  // an anchor the cycle counts from.
  group('the year chart', () {
    List<SpendBar> bars(List<TrackedItem> items, {int? month}) =>
        MoneyPresenter.build(
          categories: CategoryBook.shipped,
          items: items,
          today: today,
          span: MoneySpan.month,
          month: month,
        ).bars;

    test('carries the calendar year, January first', () {
      final chart = bars([item('Netflix', expiresOn: '2026-03-05')]);

      expect(chart.length, 12);
      expect(chart.map((b) => b.month), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
      expect(chart.map((b) => b.label), [
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        '11',
        '12',
      ]);
      expect(chart[2].longLabel, 'March');
    });

    test('the month the user is in is marked wherever they are looking', () {
      expect(bars([item('Netflix')]).where((b) => b.current).single.month, 8);
      expect(
        bars([item('Netflix')], month: 3).where((b) => b.current).single.month,
        8,
      );
    });

    test('the chart opens on the month the user is in', () {
      expect(bars([item('Netflix')]).where((b) => b.selected).single.month, 8);
    });

    test('tapping a column moves the selection there and nowhere else', () {
      final chart = bars([item('Netflix')], month: 3);

      expect(chart.where((b) => b.selected).single.month, 3);
    });

    test('months that have not arrived are marked as such', () {
      final chart = bars([item('Netflix')]);

      expect(chart.where((b) => b.ahead).map((b) => b.month), [9, 10, 11, 12]);
    });

    test('a monthly item lands on every month from its anchor onward', () {
      final chart = bars([item('Netflix', expiresOn: '2026-03-05')]);

      expect(chart.map((b) => b.minor), [
        0,
        0,
        260000,
        260000,
        260000,
        260000,
        260000,
        260000,
        260000,
        260000,
        260000,
        260000,
      ]);
    });

    // The anchor is the earliest date the app has any evidence for. Filling in
    // the months before it would invent a subscription history nobody typed.
    test('months before the anchor stay empty', () {
      final chart = bars([item('Netflix', expiresOn: '2026-06-05')]);

      expect(chart.take(5).map((b) => b.minor), [0, 0, 0, 0, 0]);
      expect(chart[5].minor, 260000);
    });

    test('a yearly charge lands on one month only', () {
      final chart = bars([
        item(
          'Domain',
          expiresOn: '2026-05-09',
          cycle: Cycle.yearly,
          amountMinor: 300000,
          categoryId: 'UTILITIES',
        ),
      ]);

      expect(chart.where((b) => b.minor > 0).single.month, 5);
      expect(chart[4].minor, 300000);
    });

    test('a one-off lands on the month it falls in', () {
      final chart = bars([
        item(
          'Passport fee',
          expiresOn: '2026-07-02',
          cycle: null,
          amountMinor: 200000,
          categoryId: 'UTILITIES',
        ),
      ]);

      expect(chart.where((b) => b.minor > 0).single.month, 7);
    });

    // Adding 2000 US cents to a dong figure would draw a column an order of
    // magnitude short of the truth.
    test('a foreign amount is converted rather than added raw', () {
      final chart = bars([
        item(
          'Claude Pro',
          expiresOn: '2026-08-04',
          amountMinor: 2000,
          currency: 'USD',
        ),
      ]);

      final converted = Fx.total(
        [Money(2000, 'USD')],
        rate: Fx.bundledUsdVnd,
        today: today,
      ).approximateBase!;
      expect(chart[7].minor, converted.minor);
    });

    // A trial is free until it converts, and the total above the chart says so
    // in as many words.
    test('a trial is not counted', () {
      expect(
        bars([
          item(
            'Claude Pro',
            expiresOn: '2026-08-26',
            trialStart: d('2026-08-12'),
          ),
        ]),
        isEmpty,
      );
    });

    test('an item with no amount on it is left out rather than guessed at', () {
      expect(bars([item('Netflix', amountMinor: null)]), isEmpty);
    });

    test('an archived item is gone from the chart as well', () {
      expect(
        bars([
          item('Netflix', expiresOn: '2026-03-05', state: ItemState.archived),
        ]),
        isEmpty,
      );
    });

    // The switch stops reminders, not the vendor.
    test('a paused item is still being charged and still counted', () {
      final chart = bars([
        item('Netflix', expiresOn: '2026-03-05', paused: true),
      ]);

      expect(chart[7].minor, 260000);
    });

    // Rolling a counted plan past its last payment would draw an instalment
    // the user never owes.
    test('an instalment plan stops after its last payment', () {
      final chart = bars([
        TrackedItem(
          id: 'course',
          name: 'Course',
          categoryId: 'EDUCATION',
          expiresOn: d('2026-05-10'),
          anchorDate: d('2026-03-10'),
          cycle: Cycle.monthly,
          repeatCount: 3,
          amountMinor: 500000,
          currency: 'VND',
        ),
      ]);

      expect(chart.where((b) => b.minor > 0).map((b) => b.month), [3, 4, 5]);
    });

    // Anything anchored in a later year has not started; anything that ended
    // in an earlier one is over. Neither belongs on this year's chart.
    test('an item outside the year draws no chart at all', () {
      expect(bars(const []), isEmpty);
      expect(bars([item('Netflix', expiresOn: '2027-02-05')]), isEmpty);
    });

    test('the chart is on the month view and not on the year one', () {
      final items = [item('Netflix', expiresOn: '2026-03-05')];

      expect(view(items, MoneySpan.month).bars, isNotEmpty);
      expect(view(items, MoneySpan.year).bars, isEmpty);
    });
  });

  group('a month other than this one', () {
    MoneyView at(int month, List<TrackedItem> items) => MoneyPresenter.build(
      categories: CategoryBook.shipped,
      items: items,
      today: today,
      span: MoneySpan.month,
      month: month,
    );

    test('the card names the month it is showing', () {
      final items = [item('Netflix', expiresOn: '2026-03-05')];

      expect(at(8, items).label, 'This month');
      expect(at(3, items).label, 'March');
      expect(at(3, items).showingMonth, 3);
    });

    test('the total and the list follow the month', () {
      final items = [
        item('Netflix', expiresOn: '2026-03-05'),
        item(
          'Domain',
          expiresOn: '2026-05-09',
          cycle: Cycle.yearly,
          amountMinor: 300000,
          categoryId: 'UTILITIES',
        ),
      ];

      expect(at(5, items).items.map((i) => i.name), ['Domain', 'Netflix']);
      expect(at(5, items).total.approximateBase!.minor, 560000);
      expect(at(4, items).items.map((i) => i.name), ['Netflix']);
    });

    // A month that has not happened is the cycles read forward, and the chart
    // says so rather than sitting there looking like a receipt. It says it on
    // the column the reader is on, not only on the ones beside it -- that flag
    // is what the screen draws the selected column back with.
    test('a month still ahead is flagged on the column being read', () {
      final ahead = at(11, [item('Netflix')]).bars;
      expect(ahead.singleWhere((bar) => bar.selected).ahead, isTrue);

      final behind = at(8, [item('Netflix')]).bars;
      expect(behind.singleWhere((bar) => bar.selected).ahead, isFalse);
    });

    // A trial is listed under its own heading and never inside the total, on
    // whichever month the card is showing. It used to be named a second time
    // in a line under the figure, which appeared only on the month the user
    // was in and moved the chart every time they left it.
    test('a trial stays out of the total and in its own section', () {
      final items = [
        item('Netflix'),
        item(
          'Claude Pro',
          expiresOn: '2026-08-26',
          trialStart: d('2026-08-12'),
        ),
      ];

      for (final month in [3, 8]) {
        expect(at(month, items).trials.single.name, 'Claude Pro');
        expect(
          at(month, items).items.map((i) => i.name),
          isNot(contains('Claude Pro')),
        );
      }
    });

    // Twice in one month is one subscription billed twice, not two
    // subscriptions.
    test('a charge landing more than once in a month says how many', () {
      final weekly = at(8, [
        item(
          'Gym',
          expiresOn: '2026-08-03',
          cycle: Cycle.weekly,
          amountMinor: 50000,
          categoryId: 'FITNESS',
        ),
      ]);

      expect(weekly.items.single.name, 'Gym ×5');
      expect(weekly.items.single.total.minor, 250000);
      expect(weekly.total.approximateBase!.minor, 250000);
    });
  });
}
