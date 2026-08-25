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
  /// `A` — the month's initial, which is all the width allows.
  final String label;

  /// The month in full, for the screen reader, since one letter is not a
  /// month and `M` is three of them.
  final String longLabel;

  /// Base-currency minor units paid in that month.
  final int minor;

  /// The month the user is in. Drawn in the accent; the rest are the soft one.
  final bool current;

  const SpendBar({
    required this.label,
    required this.longLabel,
    required this.minor,
    this.current = false,
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

  /// `THIS MONTH` / `NEXT 12 MONTHS`.
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
  /// How many columns the chart carries, including the current month.
  static const int barMonths = 6;

  static MoneyView build({
    required List<TrackedItem> items,
    required CategoryBook categories,
    required LocalDate today,
    required MoneySpan span,
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

    return span == MoneySpan.month
        ? _month(
            live,
            categories,
            today,
            trials,
            bars(items: live, categories: categories, today: today),
          )
        : _year(live, categories, today, trials);
  }

  // ---- this month ----

  static MoneyView _month(
    List<TrackedItem> live,
    CategoryBook categories,
    LocalDate today,
    List<TrialSpend> trials,
    List<SpendBar> bars,
  ) {
    final counted = [
      for (final item in live)
        if (item.countsTowardSpend(categories[item.categoryId]) &&
            item.expiresOn.month == today.month &&
            item.expiresOn.year == today.year)
          item,
    ];

    final rows = [
      for (final item in counted)
        ItemSpend(
          name: item.name,
          total: Fx.total(
            [item.money!],
            rate: Fx.bundledUsdVnd,
            today: today,
          ).approximateBase!,
          // The exact foreign figure is kept beside the converted one, because
          // it is the part that is actually true.
          foreign: item.currency == Fx.bundledUsdVnd.to ? null : item.money,
        ),
    ]..sort((a, b) => b.total.minor.compareTo(a.total.minor));

    final total = Fx.total(
      [for (final item in counted) item.money!],
      rate: Fx.bundledUsdVnd,
      today: today,
    );

    return MoneyView(
      span: MoneySpan.month,
      label: 'This month',
      total: total,
      subtitle: _monthSubtitle(counted.length, trials.length),
      alternateTotal: MoneyPresenter.alternateTotal(total),
      items: rows,
      bars: bars,
      trials: trials,
    );
  }

  /// The last [barMonths] calendar months of what the list says each month
  /// costs, oldest first.
  ///
  /// Worked out from the items themselves rather than from what has been
  /// marked paid. An amount, a cycle and an anchor are everything a month's
  /// figure needs, and a chart that waited on the user to mark payments would
  /// sit blank over a list that is perfectly well filled in.
  ///
  /// Counting starts at the anchor and never runs behind it. The anchor is the
  /// earliest date the app has any evidence for; carrying a monthly charge
  /// back through months the user never mentioned would draw a subscription
  /// history out of nothing.
  ///
  /// The same test as the total above the chart decides what counts, so the
  /// current month's column and the headline figure can never disagree.
  static List<SpendBar> bars({
    required List<TrackedItem> items,
    required CategoryBook categories,
    required LocalDate today,
  }) {
    final newest = _monthKey(today);
    final oldest = newest - (barMonths - 1);

    // Kept as amounts rather than summed on the way in, because two currencies
    // in one month have to go through the same conversion the totals do.
    final amounts = <int, List<Money>>{};
    for (final item in items) {
      if (item.state == ItemState.archived) continue;
      if (!item.countsTowardSpend(categories[item.categoryId])) continue;

      for (final on in _occurrences(item, oldest: oldest, newest: newest)) {
        (amounts[_monthKey(on)] ??= []).add(item.money!);
      }
    }

    if (amounts.isEmpty) return const [];

    return [
      for (var at = oldest; at <= newest; at++)
        SpendBar(
          label: DateCopy.month(at % 12 + 1).substring(0, 1),
          longLabel: DateCopy.month(at % 12 + 1),
          minor: switch (amounts[at]) {
            null => 0,
            final month =>
              Fx.total(
                    month,
                    rate: Fx.bundledUsdVnd,
                    today: today,
                  ).approximateBase?.minor ??
                  0,
          },
          current: at == newest,
        ),
    ];
  }

  /// Keyed `year * 12 + month` so December to January is one step like any
  /// other, and so the arithmetic around it never has to touch day lengths.
  static int _monthKey(LocalDate date) => date.year * 12 + (date.month - 1);

  /// Every occurrence of [item] falling inside the window, oldest first.
  ///
  /// Walks forward from the anchor rather than back from the due date, because
  /// the anchor is the date cycle maths is defined against — stepping back a
  /// month at a time from the 31st loses the 31st for good. A counted plan
  /// stops at its last instalment: rolling it on would draw a payment the user
  /// does not owe.
  static Iterable<LocalDate> _occurrences(
    TrackedItem item, {
    required int oldest,
    required int newest,
  }) sync* {
    final cycle = item.cycle;
    if (cycle == null) {
      // A one-off happens on its own date and never again.
      if (_monthKey(item.expiresOn) >= oldest &&
          _monthKey(item.expiresOn) <= newest) {
        yield item.expiresOn;
      }
      return;
    }

    final instalments = item.repeatCount;
    for (var n = 0; instalments == null || n < instalments; n++) {
      final on = Recurrence.occurrenceAfter(item.anchorDate, cycle, n);
      final at = _monthKey(on);
      if (at > newest) return;
      if (at >= oldest) yield on;
    }
  }

  static String _monthSubtitle(int counted, int trials) {
    final head = '$counted ${counted == 1 ? "item" : "items"} counted';
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
