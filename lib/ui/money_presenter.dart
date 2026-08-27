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
import 'package:subdock/i18n.dart';

/// Which span the Spending screen is showing.
enum MoneySpan { month, year }

/// One line of the yearly breakdown.
@immutable
class YearBand {
  final String label;
  final Money total;

  /// Whether a rate was applied to build [total]. A band made entirely of dong
  /// amounts is exact, and printing a tilde over it claims otherwise.
  final bool converted;

  const YearBand({
    required this.label,
    required this.total,
    required this.converted,
  });
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

/// A trial that is still free today, and the day that stops.
///
/// Listed on every month's card, because which trials a person is running is a
/// fact about them rather than about March. The money is not repeated here:
/// the first charge is counted in the month it lands in, and the free months
/// before it are empty in the chart above.
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

/// One shelf's share of the card's total.
///
/// A share as well as a figure, because the question this answers is not "how
/// much is streaming" -- the figure alone says that -- but "what is this money
/// going on", and a proportion is what makes forty thousand beside two hundred
/// thousand read at a glance.
@immutable
class CategorySpend {
  final String label;
  final Money total;

  /// The figure went through a rate to get here.
  final bool converted;

  /// This row's part of the rows below it, 0 to 1.
  ///
  /// Of the rows rather than of [MoneyView.total]: anything the app could not
  /// convert is missing from both, so the shares always add up to the whole
  /// bar rather than to some fraction of it that nothing on screen explains.
  final double share;

  const CategorySpend({
    required this.label,
    required this.total,
    required this.share,
    this.converted = false,
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

  /// Per-item, for the month view. Empty on the year view, where a list of
  /// forty annualised figures answers nothing a person asked.
  final List<ItemSpend> items;

  /// The same total in the other currency, small, under the headline.
  ///
  /// Null when the user tracks nothing in another currency — a dong figure
  /// restated in dollars answers a question a dong-only user never asked.
  ///
  /// Present on *every* month once they do track one, including a month whose
  /// own charges happen to be all dong. The card is read by flicking between
  /// months, and a line that comes and going with the month moves the chart
  /// under the reader's thumb. Which currencies a person keeps is a fact about
  /// them, not about March.
  ///
  /// The exact per-currency subtotals used to sit here instead, each with its
  /// own conversion. They were correct and they were unreadable: three groups
  /// of figures on one card, two of them decompositions of the same total, and
  /// a reader has to work out which is which before any of it means anything.
  /// Carries the rate that produced it, in brackets, because this is the one
  /// line on the card where a rate belongs: it sits against the figure it
  /// explains rather than at the foot of the card, where it read as a stray
  /// fact about the app.
  final String? alternateTotal;

  /// Three bands, for the year view. Empty on the month view.
  final List<YearBand> bands;

  /// The same total split by shelf, largest first. On both spans.
  ///
  /// Kept separate from [bands], which is the year view's three fixed kinds.
  /// These are the user's own shelves and there can be twenty of them, so this
  /// is a section of its own rather than another block on the total card --
  /// see the note on the card holding the same number of lines in every month.
  final List<CategorySpend> byCategory;

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
    this.alternateTotal,
    this.items = const [],
    this.bands = const [],
    this.byCategory = const [],
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
        if (item.isTrialOn(today))
          TrialSpend(
            name: item.name,
            startsCharging: MoneyFormat.shortDate(item.expiresOn),
            cost: item.money == null ? '—' : MoneyFormat.full(item.money!),
          ),
    ];

    // A fact about the person, not about the month they are looking at. Worked
    // out from the whole list so that every month of the card is laid out the
    // same way; see [MoneyView.alternateTotal].
    final restate = live.any(
      (item) => item.money != null && item.money!.currency != Fx.base,
    );

    if (span == MoneySpan.year) {
      return _year(live, categories, today, trials, restate: restate);
    }

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
      restate: restate,
    );
  }

  // ---- one month of the year ----

  static MoneyView _month({
    required CategoryBook categories,
    required LocalDate today,
    required int showing,
    required Map<int, List<TrackedItem>> charges,
    required List<TrialSpend> trials,
    required bool restate,
  }) {
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
            name: times == 1 ? item.name : S.t.timesInMonth(item.name, times),
            total: Fx.total(
              [Money(money.minor * times, money.currency)],
              rate: Fx.bundledUsdVnd,
              today: today,
            ).approximateBase!,
            // The exact foreign figure is kept beside the converted one,
            // because it is the part that is actually true. "Foreign" is
            // relative to the base the user picked, not to the dong.
            foreign: money.currency == Fx.base
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

    // Per occurrence, exactly like the total above it: a weekly charge is four
    // rows of the same shelf in a four-week month, and its share has to say so.
    final perShelf = <String, List<Money>>{};
    for (final item in counted) {
      (perShelf[item.categoryId] ??= []).add(item.money!);
    }

    return MoneyView(
      span: MoneySpan.month,
      showingMonth: showing,
      label: showing == today.month ? S.t.thisMonth : DateCopy.month(showing),
      total: total,
      // Nothing under the figure. The two lines that used to live here -- the
      // count of items, and a note that a month still ahead was read off the
      // cycles -- appeared on some months and not others, so the chart below
      // shifted every time the reader tapped a different column. The trials
      // have their own section further down and the chart says for itself
      // which months have not happened.
      alternateTotal: MoneyPresenter.alternateTotal(total, restate: restate),
      items: rows,
      byCategory: _shelfRows(perShelf, categories, today),
      bars: _bars(charges: charges, today: today, showing: showing),
      trials: trials,
    );
  }

  /// Shelves as shares of themselves, largest first.
  ///
  /// A shelf whose money the app cannot convert is dropped rather than shown
  /// at zero, and the shares are taken over what is left. A row reading `0%`
  /// beside a real amount is the screen reporting a rate failure in the one
  /// notation that looks like an answer.
  static List<CategorySpend> _shelfRows(
    Map<String, List<Money>> perShelf,
    CategoryBook categories,
    LocalDate today,
  ) {
    final totals = <String, MixedTotal>{};
    var whole = 0;
    for (final entry in perShelf.entries) {
      final sum = Fx.total(entry.value, rate: Fx.bundledUsdVnd, today: today);
      final base = sum.approximateBase;
      if (base == null || base.minor <= 0) continue;
      totals[entry.key] = sum;
      whole += base.minor;
    }
    if (whole == 0) return const [];

    return [
      for (final entry in totals.entries)
        CategorySpend(
          label: categories[entry.key].displayLabel,
          total: entry.value.approximateBase!,
          converted: entry.value.converted,
          share: entry.value.approximateBase!.minor / whole,
        ),
    ]..sort((a, b) => b.total.minor.compareTo(a.total.minor));
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

      for (final on in countedOccurrences(item, year: year)) {
        (charges[on.month] ??= []).add(item);
      }
    }
    return charges;
  }

  /// Every occurrence of [item] that costs money and falls inside [year],
  /// oldest first.
  ///
  /// Walks forward from the anchor rather than back from the due date, because
  /// the anchor is the date cycle maths is defined against — stepping back a
  /// month at a time from the 31st loses the 31st for good. A counted plan
  /// stops at its last instalment: rolling it on would draw a payment the user
  /// does not owe.
  ///
  /// A free trial drops the occurrences before its first charge. That first
  /// charge is [TrackedItem.expiresOn], so what the trial actually says is
  /// "the months before this date were free" — which is why the test is
  /// `inTrial` and not `isTrialOn(today)`. Those months stay free once the day
  /// passes; asking against today would refill them the morning after and
  /// rewrite spending the user had already read.
  @visibleForTesting
  static Iterable<LocalDate> countedOccurrences(
    TrackedItem item, {
    required int year,
  }) sync* {
    final cycle = item.cycle;
    if (cycle == null) {
      // A one-off happens on its own date and never again. A trial one-off is
      // charged on that same date, so there is nothing before it to drop.
      if (item.expiresOn.year == year) yield item.expiresOn;
      return;
    }

    final instalments = item.repeatCount;
    for (var n = 0; instalments == null || n < instalments; n++) {
      final on = Recurrence.occurrenceAfter(item.anchorDate, cycle, n);
      if (on.year > year) return;
      if (item.inTrial && on < item.expiresOn) continue;
      if (on.year == year) yield on;
    }
  }

  // ---- next twelve months ----

  static MoneyView _year(
    List<TrackedItem> live,
    CategoryBook categories,
    LocalDate today,
    List<TrialSpend> trials, {
    required bool restate,
  }) {
    final subscriptions = <Money>[];
    final bills = <Money>[];
    final annual = <Money>[];
    final all = <Money>[];

    final perShelf = <String, List<Money>>{};

    for (final item in live) {
      if (!item.countsTowardSpend(categories[item.categoryId])) continue;
      final yearly = annualised(item);
      if (yearly == null) continue;

      all.add(yearly);
      (perShelf[item.categoryId] ??= []).add(yearly);
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

    MixedTotal? band(List<Money> parts) => parts.isEmpty
        ? null
        : Fx.total(parts, rate: Fx.bundledUsdVnd, today: today);

    final total = Fx.total(all, rate: Fx.bundledUsdVnd, today: today);

    return MoneyView(
      span: MoneySpan.year,
      label: S.t.nextTwelveMonths,
      total: total,
      // No sentence explaining that twelve monthly charges come to twelve
      // times one. The heading already says which twelve months, and a reader
      // who has entered their own cycles does not need the arithmetic read
      // back to them.
      alternateTotal: MoneyPresenter.alternateTotal(total, restate: restate),
      bands: [
        for (final (label, parts) in [
          (S.t.bandSubscriptions, subscriptions),
          (S.t.bandBills, bills),
          (S.t.bandAnnual, annual),
        ])
          if (band(parts) case final MixedTotal band)
            if (band.approximateBase case final Money total)
              YearBand(label: label, total: total, converted: band.converted),
      ],
      byCategory: _shelfRows(perShelf, categories, today),
      trials: trials,
    );
  }

  /// The total again in the other currency, or null when there is no other
  /// currency in play.
  ///
  /// Converted from the base total rather than summed separately, so the two
  /// figures on the card can never disagree: one number, said twice.
  static String? alternateTotal(MixedTotal total, {bool restate = false}) {
    if (!restate && total.perCurrency.length < 2) return null;

    final base = total.approximateBase;
    final rate = total.rate;
    if (base == null || rate == null) return null;

    // Read in whichever direction the base sits on. The app bundles one rate,
    // USD to VND, and which of the two the user counts in is their choice --
    // a card that only knew how to restate a dong total would leave someone
    // who picked dollars with no second figure at all.
    final other = switch (base.currency) {
      final code when code == rate.to => rate.invert(base),
      final code when code == rate.from => rate.convert(base),
      _ => null,
    };
    if (other == null) return null;

    // The rate rides on this line rather than on a line of its own at the
    // foot of the card. It is the whole reason both figures on the card are
    // approximate, and beside the figure it produced it reads as an
    // explanation instead of as trivia.
    //
    // Without its date, which the old foot line carried. [Fx.total] drops a
    // rate older than [Fx.maxDisplayAgeDays] rather than converting with it,
    // so a rate that reaches the screen at all is one the app is prepared to
    // stand behind; past that there is no converted figure here to date.
    return S.t.alternateTotal(MoneyFormat.full(other), MoneyFormat.rate(rate));
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
