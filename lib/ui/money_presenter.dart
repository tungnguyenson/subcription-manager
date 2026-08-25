import 'package:meta/meta.dart';

import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/money_screen.dart';

/// Which span the Spending screen is showing.
enum MoneySpan { month, year }

/// One line of the yearly breakdown.
@immutable
class YearBand {
  final String label;
  final Money total;

  const YearBand({required this.label, required this.total});
}

/// One column of the six-month chart on the month view.
///
/// The figure is what the list says that month came to: every occurrence of
/// every counted item that lands in it, at the amount on the item. The same
/// kind of number as the total above the chart, and worked out the same way,
/// so the current month's column *is* that total.
///
/// It is not a record of what was paid. Nothing here reads the history of
/// marked payments, and a column can stand over a month whose bill the user
/// never confirmed.
@immutable
class SpendBar {
  /// 1 to 12. What a tap on this column selects.
  final int month;

  /// `3` — the month's number. Numerals rather than initials because three of
  /// the twelve initials are `J` and two more are `M`, and a row of twelve
  /// columns is exactly where that stops being readable.
  final String label;

  /// The month in full, for the screen reader, since one letter is not a
  /// month and `M` is three of them.
  final String longLabel;

  /// Base-currency minor units paid in that month.
  final int minor;

  /// The month the user is in. Marked whether or not it is the one being
  /// shown, so the chart never loses the reader's place in the year.
  final bool current;

  /// The column the card is showing. Exactly one of the twelve.
  final bool selected;

  /// A month that has not arrived. Its figure is the cycles read forward,
  /// which is a different kind of number from the months behind it, and the
  /// chart draws it back so the two do not read as one row of facts.
  final bool ahead;

  const SpendBar({
    required this.month,
    required this.label,
    required this.longLabel,
    required this.minor,
    this.current = false,
    this.selected = false,
    this.ahead = false,
  });
}

/// A trial, listed but not counted.
@immutable
class TrialSpend {
  final String name;

  /// `21/08` — the day the free period ends and the charge starts.
  final String startsCharging;

  /// What it will cost, or `—` when the user has not entered an amount.
  final String cost;

  const TrialSpend({
    required this.name,
    required this.startsCharging,
    required this.cost,
  });
}

@immutable
class MoneyView {
  final MoneySpan span;

  /// Which month of the current year the card is showing, 1 to 12, or null on
  /// the year view. The chart column that matches it is the selected one.
  final int? showingMonth;

  /// `THIS MONTH` / `MARCH` / `NEXT 12 MONTHS`.
  final String label;

  final MixedTotal total;

  /// The line under the figure: what was counted, and what was not.
  final String subtitle;

  /// Per-item, for the month view. Empty on the year view, where a list of
  /// forty annualised figures answers nothing a person asked.
  final List<ItemSpend> items;

  /// The same total in the other currency, small, under the headline.
  ///
  /// Null when nothing is charged in another currency — a dong figure restated
  /// in dollars answers a question a dong-only user never asked.
  ///
  /// The exact per-currency subtotals used to sit here instead, each with its
  /// own conversion. They were correct and they were unreadable: three groups
  /// of figures on one card, two of them decompositions of the same total, and
  /// a reader has to work out which is which before any of it means anything.
  /// The `≈` and the rate line at the foot of the card still say this figure is
  /// converted rather than counted.
  final String? alternateTotal;

  /// Three bands, for the year view. Empty on the month view.
  final List<YearBand> bands;

  /// Six columns of what each month costs, for the month view.
  ///
  /// Empty when no counted item has an occurrence anywhere in the window, and
  /// empty rather than six zeroed columns: a flat row of stubs reads as "you
  /// spend nothing", which is a claim, where an absent chart reads as "nothing
  /// in here yet", which is the truth about a list the window cannot reach.
  final List<SpendBar> bars;

  /// Trials, listed under a heading that says they are not in the total.
  ///
  /// Listed rather than dropped, and this is the whole reason the section
  /// exists: a trial is the single most expensive thing to forget, and a
  /// spending screen that simply omits it teaches the user it is free.
  final List<TrialSpend> trials;

  const MoneyView({
    required this.span,
    this.showingMonth,
    required this.label,
    required this.total,
    required this.subtitle,
    this.alternateTotal,
    this.items = const [],
    this.bands = const [],
    this.bars = const [],
    this.trials = const [],
  });
}

abstract final class MoneyPresenter {
  /// How many columns the chart carries: the calendar year, January to
  /// December.
  ///
  /// A calendar year rather than a rolling window because that is how a person
  /// talks about the months of their own spending — "back in March" means a
  /// square on a grid they already hold, not "five columns to the left".
  static const int barMonths = 12;

  static MoneyView build({
    required List<TrackedItem> items,
    required CategoryBook categories,
    required LocalDate today,
    required MoneySpan span,

    /// Which month of [today]'s year the card is showing, 1 to 12. Null is the
    /// month the user is in, which is where the screen opens.
    int? month,
  }) {
    // Archived is gone; paused is not. A service switched off is still being
    // charged — the switch stops reminders, not the vendor — so leaving it out
    // of a spending total would understate the bill.
    final live = items
        .where((i) => i.state != ItemState.archived)
        .toList(growable: false);

    final trials = [
      for (final item in live)
        if (item.isTrial)
          TrialSpend(
            name: item.name,
            startsCharging: MoneyFormat.shortDate(item.expiresOn),
            cost: item.money == null ? '—' : MoneyFormat.full(item.money!),
          ),
    ];

    if (span == MoneySpan.year) return _year(live, categories, today, trials);

    // One pass over the items for the whole year, so the column the user taps
    // and the figures they land on are literally the same arithmetic. Two
    // passes would be two chances to disagree.
    final charges = _chargesByMonth(live, categories, today.year);

    return _month(
      categories: categories,
      today: today,
      showing: (month ?? today.month).clamp(1, 12),
      charges: charges,
      trials: trials,
    );
  }

  // ---- one month of the year ----

  static MoneyView _month({
    required CategoryBook categories,
    required LocalDate today,
    required int showing,
    required Map<int, List<TrackedItem>> charges,
    required List<TrialSpend> trials,
  }) {
    final isThisMonth = showing == today.month;

    // Repeated once per occurrence, so a weekly charge counts four times in a
    // four-week month rather than once.
    final counted = charges[showing] ?? const <TrackedItem>[];

    // Grouped back up for the list, because two rows with one name on them
    // read as two subscriptions rather than as one billed twice.
    final occurrences = <String, int>{};
    final byId = <String, TrackedItem>{};
    for (final item in counted) {
      occurrences[item.id] = (occurrences[item.id] ?? 0) + 1;
      byId[item.id] = item;
    }

    final rows = [
      for (final entry in occurrences.entries)
        () {
          final item = byId[entry.key]!;
          final times = entry.value;
          final money = item.money!;
          return ItemSpend(
            // A charge that lands more than once in the month says so.
            // Netflix at four times the price with no explanation reads as
            // a mistake in the app.
            name: times == 1 ? item.name : '${item.name} ×$times',
            total: Fx.total(
              [Money(money.minor * times, money.currency)],
              rate: Fx.bundledUsdVnd,
              today: today,
            ).approximateBase!,
            // The exact foreign figure is kept beside the converted one,
            // because it is the part that is actually true.
            foreign: money.currency == Fx.bundledUsdVnd.to
                ? null
                : Money(money.minor * times, money.currency),
          );
        }(),
    ]..sort((a, b) => b.total.minor.compareTo(a.total.minor));

    final total = Fx.total(
      [for (final item in counted) item.money!],
      rate: Fx.bundledUsdVnd,
      today: today,
    );

    return MoneyView(
      span: MoneySpan.month,
      showingMonth: showing,
      label: isThisMonth ? 'This month' : DateCopy.month(showing),
      total: total,
      subtitle: _monthSubtitle(
        counted: occurrences.length,
        trials: isThisMonth ? trials.length : 0,
        ahead: showing > today.month,
      ),
      alternateTotal: MoneyPresenter.alternateTotal(total),
      items: rows,
      bars: _bars(charges: charges, today: today, showing: showing),
      trials: trials,
    );
  }

  /// The twelve columns of [today]'s calendar year, January first.
  ///
  /// Worked out from the items themselves rather than from what has been
  /// marked paid. An amount, a cycle and an anchor are everything a month's
  /// figure needs, and a chart that waited on the user to mark payments would
  /// sit blank over a list that is perfectly well filled in.
  static List<SpendBar> _bars({
    required Map<int, List<TrackedItem>> charges,
    required LocalDate today,
    required int showing,
  }) {
    if (charges.isEmpty) return const [];

    return [
      for (var month = 1; month <= barMonths; month++)
        SpendBar(
          month: month,
          label: '$month',
          longLabel: DateCopy.month(month),
          minor: switch (charges[month]) {
            null => 0,
            final items =>
              Fx.total(
                    [for (final item in items) item.money!],
                    rate: Fx.bundledUsdVnd,
                    today: today,
                  ).approximateBase?.minor ??
                  0,
          },
          current: month == today.month,
          selected: month == showing,
          ahead: month > today.month,
        ),
    ];
  }

  /// Which counted items are charged in each month of [year], one entry per
  /// occurrence.
  ///
  /// Counting starts at the anchor and never runs behind it. The anchor is the
  /// earliest date the app has any evidence for; carrying a monthly charge
  /// back through months the user never mentioned would draw a subscription
  /// history out of nothing.
  static Map<int, List<TrackedItem>> _chargesByMonth(
    List<TrackedItem> live,
    CategoryBook categories,
    int year,
  ) {
    final charges = <int, List<TrackedItem>>{};
    for (final item in live) {
      if (!item.countsTowardSpend(categories[item.categoryId])) continue;

      for (final on in _occurrences(item, year: year)) {
        (charges[on.month] ??= []).add(item);
      }
    }
    return charges;
  }

  /// Every occurrence of [item] that falls inside [year], oldest first.
  ///
  /// Walks forward from the anchor rather than back from the due date, because
  /// the anchor is the date cycle maths is defined against — stepping back a
  /// month at a time from the 31st loses the 31st for good. A counted plan
  /// stops at its last instalment: rolling it on would draw a payment the user
  /// does not owe.
  static Iterable<LocalDate> _occurrences(
    TrackedItem item, {
    required int year,
  }) sync* {
    final cycle = item.cycle;
    if (cycle == null) {
      // A one-off happens on its own date and never again.
      if (item.expiresOn.year == year) yield item.expiresOn;
      return;
    }

    final instalments = item.repeatCount;
    for (var n = 0; instalments == null || n < instalments; n++) {
      final on = Recurrence.occurrenceAfter(item.anchorDate, cycle, n);
      if (on.year > year) return;
      if (on.year == year) yield on;
    }
  }

  static String _monthSubtitle({
    required int counted,
    required int trials,
    required bool ahead,
  }) {
    final head = '$counted ${counted == 1 ? "item" : "items"} counted';
    if (ahead) {
      // A month that has not happened yet is the cycles read forward, and it
      // says so rather than sitting there looking like a receipt.
      return '$head · not due yet, worked out from the cycles';
    }
    return trials == 0
        ? head
        : '$head · ${trials == 1 ? "1 trial" : "$trials trials"} '
              'not counted yet';
  }

  // ---- next twelve months ----

  static MoneyView _year(
    List<TrackedItem> live,
    CategoryBook categories,
    LocalDate today,
    List<TrialSpend> trials,
  ) {
    final subscriptions = <Money>[];
    final bills = <Money>[];
    final annual = <Money>[];
    final all = <Money>[];

    for (final item in live) {
      if (!item.countsTowardSpend(categories[item.categoryId])) continue;
      final yearly = annualised(item);
      if (yearly == null) continue;

      all.add(yearly);
      if (_yearlyOrLonger(item.cycle)) {
        annual.add(yearly);
        // An obligation is an amount owed by a date. Filing one with
        // subscriptions would put it beside things the user could cancel, and
        // an electricity bill -- or a phone number -- is not one of those.
      } else if (categories[item.categoryId].isObligation) {
        bills.add(yearly);
      } else {
        subscriptions.add(yearly);
      }
    }

    Money? band(List<Money> parts) => parts.isEmpty
        ? null
        : Fx.total(parts, rate: Fx.bundledUsdVnd, today: today).approximateBase;

    final total = Fx.total(all, rate: Fx.bundledUsdVnd, today: today);

    return MoneyView(
      span: MoneySpan.year,
      label: 'Next 12 months',
      total: total,
      subtitle:
          'Estimate. A monthly bill is carried twelve times forward at '
          "today's amount; a yearly charge is counted once.",
      alternateTotal: MoneyPresenter.alternateTotal(total),
      bands: [
        for (final (label, parts) in [
          ('Subscriptions', subscriptions),
          ('Bills and utilities', bills),
          ('Charged once a year', annual),
        ])
          if (band(parts) case final Money total)
            YearBand(label: label, total: total),
      ],
      trials: trials,
    );
  }

  /// The total again in the other currency, or null when there is no other
  /// currency in play.
  ///
  /// Converted from the base total rather than summed separately, so the two
  /// figures on the card can never disagree: one number, said twice.
  static String? alternateTotal(MixedTotal total) {
    if (total.perCurrency.length < 2) return null;

    final base = total.approximateBase;
    final rate = total.rate;
    if (base == null || rate == null || rate.to != base.currency) return null;

    return '≈ ${MoneyFormat.full(rate.invert(base))}';
  }

  /// What this item costs over twelve months, or null when there is no amount
  /// or no cycle to repeat it on.
  ///
  /// A one-off is null on purpose. It is a single charge, and multiplying it by
  /// anything — or counting it once inside a figure labelled "per year" —
  /// would put a number in the total that does not recur. The figure this
  /// screen shows is a commitment, not a forecast of everything that will
  /// happen.
  static Money? annualised(TrackedItem item) {
    final money = item.money;
    final cycle = item.cycle;
    if (money == null || cycle == null) return null;

    final perYear = switch (cycle.unit) {
      CycleUnit.month => 12 / cycle.step,
      CycleUnit.day => 365 / cycle.step,
    };
    return Money((money.minor * perYear).round(), money.currency);
  }

  static bool _yearlyOrLonger(Cycle? cycle) => switch (cycle) {
    null => false,
    Cycle(unit: CycleUnit.month, :final step) => step >= 12,
    Cycle(unit: CycleUnit.day, :final step) => step >= 365,
  };
}
