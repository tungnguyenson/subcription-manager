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
      expect(month.subtitle, '1 item counted');
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
      expect(month.subtitle, '1 item counted · 1 trial not counted yet');
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

    // An estimate has to say it is one. A bill carried twelve times forward at
    // today's amount is a guess about the other eleven months.
    test('the year figure says out loud that it is an estimate', () {
      final year = view([item('Netflix')], MoneySpan.year);

      expect(year.label, 'Next 12 months');
      expect(year.subtitle, startsWith('Estimate.'));
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
      expect(year.alternateTotal, r'≈ $359.79');
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
  group('the six-month chart', () {
    List<SpendBar> bars(List<TrackedItem> items) => MoneyPresenter.bars(
      items: items,
      categories: CategoryBook.shipped,
      today: today,
    );

    test('runs six months back and ends on the month the user is in', () {
      final chart = bars([item('Netflix', expiresOn: '2026-03-05')]);

      expect(chart.length, MoneyPresenter.barMonths);
      expect(chart.map((b) => b.longLabel), [
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
      ]);
      expect(chart.last.current, isTrue);
      expect(chart.where((b) => b.current).length, 1);
    });

    test('a monthly item lands on every month from its anchor onward', () {
      final chart = bars([item('Netflix', expiresOn: '2026-03-05')]);

      expect(chart.map((b) => b.minor), [
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

      expect(chart.map((b) => b.minor), [0, 0, 0, 260000, 260000, 260000]);
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

      expect(chart.map((b) => b.minor), [0, 0, 300000, 0, 0, 0]);
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

      expect(chart.map((b) => b.minor), [0, 0, 0, 0, 200000, 0]);
    });

    // Crossing the year boundary is the case a naive `month - 5` gets wrong.
    test('counts back across the turn of the year', () {
      final chart = MoneyPresenter.bars(
        items: [item('Netflix', expiresOn: '2025-11-04')],
        categories: CategoryBook.shipped,
        today: d('2026-02-10'),
      );

      expect(chart.first.longLabel, 'September');
      expect(chart.last.longLabel, 'February');
      expect(chart.map((b) => b.minor), [0, 0, 260000, 260000, 260000, 260000]);
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
      expect(chart.last.minor, converted.minor);
    });

    // A trial is free until it converts, and the total above the chart says so
    // in as many words.
    test('a trial is not counted', () {
      final chart = bars([
        item(
          'Claude Pro',
          expiresOn: '2026-08-26',
          trialStart: d('2026-08-12'),
        ),
      ]);

      expect(chart, isEmpty);
    });

    test('an item with no amount on it is left out rather than guessed at', () {
      expect(bars([item('Netflix', amountMinor: null)]), isEmpty);
    });

    test('an archived item is gone from the chart as well', () {
      final chart = bars([
        item('Netflix', expiresOn: '2026-03-05', state: ItemState.archived),
      ]);

      expect(chart, isEmpty);
    });

    // The switch stops reminders, not the vendor.
    test('a paused item is still being charged and still counted', () {
      final chart = bars([
        item('Netflix', expiresOn: '2026-03-05', paused: true),
      ]);

      expect(chart.last.minor, 260000);
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

      expect(chart.map((b) => b.minor), [500000, 500000, 500000, 0, 0, 0]);
    });

    // Six zeroed columns claim "you spent nothing"; no chart says "nothing
    // here yet", which is the truth about a list with nothing in the window.
    test(
      'nothing in the window draws no chart rather than six empty columns',
      () {
        expect(bars(const []), isEmpty);
        expect(bars([item('Netflix', expiresOn: '2026-11-05')]), isEmpty);
      },
    );

    test('the chart is on the month view and not on the year one', () {
      final items = [item('Netflix', expiresOn: '2026-03-05')];

      expect(view(items, MoneySpan.month).bars, isNotEmpty);
      expect(view(items, MoneySpan.year).bars, isEmpty);
    });
  });
}
