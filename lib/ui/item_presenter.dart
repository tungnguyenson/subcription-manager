import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/money_format.dart';

/// The sentences and labels on the item detail screen.
///
/// Pure and separate from the widget, because the wording is where the product
/// decisions live: whether a date is presented as a fact or as something the
/// user typed from memory, and whether an act-by deadline is stated at all.
abstract final class ItemPresenter {
  /// The one line under the title: `Ends tomorrow · 17/08 · $20.00`.
  ///
  /// Three facts separated by dots, in the order a reader needs them — how
  /// soon, exactly when, how much. The relative phrase leads because that is
  /// what the user opened the screen to find out; the calendar date follows so
  /// they can check it against wherever the real record lives.
  static String summary(TrackedItem item, Category category, LocalDate today) {
    final parts = <String>[
      when(item, category, today),
      MoneyFormat.shortDate(item.expiresOn),
    ];

    final money = item.money;
    if (money != null) parts.add(MoneyFormat.full(money));
    return parts.join(S.t.bullet);
  }

  /// The relative half of the summary line.
  ///
  /// The shelf decides whether this reads as *expires* or as *due*, and the
  /// distinction earns its keep both ways: "Due tomorrow" on a passport reads
  /// as a bill the user could settle by tapping Pay, and "Due in 4 days" on a
  /// prepaid SIM reads as something they could pay late without losing
  /// anything, when losing the number is exactly what happens.
  static String when(TrackedItem item, Category category, LocalDate today) {
    final days = today.daysUntil(item.expiresOn);
    final expiring = category.wording == CategoryWording.expires;

    if (days < 0) {
      final late = -days;
      return expiring ? S.t.expiredAgo(late) : S.t.overdueBy(late);
    }
    if (days == 0) return expiring ? S.t.expiresToday : S.t.dueToday;
    if (days == 1) return expiring ? S.t.expiresTomorrow : S.t.dueTomorrow;
    return expiring ? S.t.expiresInDays(days) : S.t.dueInDays(days);
  }

  /// The `Repeats` row: `Monthly · 2 of 3`, or just `Monthly`.
  static String repeatLabel(TrackedItem item) {
    final cycle = cycleLabel(item.cycle);
    final total = item.repeatCount;
    if (item.cycle == null || total == null) return cycle;
    return S.t.repeatTimes(cycle, total);
  }

  /// The line under the instalment pips: `3 paid · this one due · 2 left`.
  ///
  /// Spelled out rather than left to the pips alone. The pips say the shape of
  /// it at a glance; this says it in a form a screen reader can read and a
  /// hurried reader can trust.
  static String instalmentLine(Instalments position) {
    final parts = <String>[];
    if (position.paid > 0) {
      parts.add(S.t.instalmentPaid(position.paid));
    }
    parts.add(S.t.instalmentThisOneDue);
    parts.add(
      position.left > 0
          ? S.t.instalmentLeft(position.left)
          : S.t.instalmentLastOne,
    );
    return parts.join(S.t.bullet);
  }

  static String cycleLabel(Cycle? cycle) {
    if (cycle == null) return S.t.cycleOnce;
    return switch ((cycle.unit, cycle.step)) {
      (CycleUnit.day, 7) => S.t.cycleWeekly,
      (CycleUnit.month, 1) => S.t.cycleMonthly,
      (CycleUnit.month, 3) => S.t.cycleQuarterly,
      (CycleUnit.month, 6) => S.t.cycleTwiceAYear,
      (CycleUnit.month, 12) => S.t.cycleYearly,
      _ => S.t.cycleEvery(cycleEvery(cycle)),
    };
  }

  /// The interval on its own, pluralised: `5 months`, `2 weeks`, `10 days`.
  ///
  /// Read back in the largest unit it divides into, because a user who typed
  /// "every 2 weeks" must not find "every 14 days" on the item afterwards.
  static String cycleEvery(Cycle cycle) {
    final (count, field) = cycle.inLargestField;
    return switch (field) {
      CycleField.day => S.t.intervalDays(count),
      CycleField.week => S.t.intervalWeeks(count),
      CycleField.month => S.t.intervalMonths(count),
      CycleField.year => S.t.intervalYears(count),
    };
  }

  /// The interval abbreviated to fit a segment or a pill: `5 mo`, `2 wk`.
  static String cycleEveryShort(Cycle cycle) {
    final (count, field) = cycle.inLargestField;
    return switch (field) {
      CycleField.day => S.t.intervalShortDays(count),
      CycleField.week => S.t.intervalShortWeeks(count),
      CycleField.month => S.t.intervalShortMonths(count),
      CycleField.year => S.t.intervalShortYears(count),
    };
  }

  /// The suffix on a cost: `$20.00 / mo`.
  static String? cyclePer(Cycle? cycle) {
    if (cycle == null) return null;
    return switch ((cycle.unit, cycle.step)) {
      (CycleUnit.day, 7) => S.t.perWeek,
      (CycleUnit.month, 1) => S.t.perMonth,
      (CycleUnit.month, 3) => S.t.perQuarter,
      (CycleUnit.month, 6) => S.t.perHalfYear,
      (CycleUnit.month, 12) => S.t.perYear,
      _ => S.t.perInterval(cycleEveryShort(cycle)),
    };
  }

  /// How much the shown date can be trusted.
  ///
  /// The app cannot read the provider's records; it only knows what was typed.
  /// A date shown with more confidence than its source deserves is the failure
  /// this label exists to prevent.
  static String dateSourceLabel(DateSource source) => switch (source) {
    DateSource.userConfirmed => S.t.dateSourceConfirmed,
    DateSource.userEstimated => S.t.dateSourceRemembered,
    DateSource.computed => S.t.dateSourceComputed,
    DateSource.extracted => S.t.dateSourceExtracted,
  };

  /// The reminder ladder as short chips: `7 days before`, `On the day`.
  static List<String> leadLabels(List<int> leadDays) => [
    for (final lead in leadDays) leadLabel(lead),
  ];

  static String leadLabel(int lead) =>
      lead == 0 ? S.t.leadOnTheDay : S.t.leadDaysBefore(lead);

  /// What deleting actually costs, said next to the button rather than only on
  /// the sheet that asks.
  ///
  /// This used to end with "What you have already paid stays under Spending",
  /// and that was wrong twice over: `handledEventRow` carries
  /// `ON DELETE CASCADE`, so the payments the user typed in go with the item,
  /// and Spending stopped reading that table when it started deriving months
  /// from the cycle. Both halves pointed at a safety net that is not there.
  static String deleteConsequence(int reminderCount) =>
      S.t.deleteConsequence(reminderCount);
}
