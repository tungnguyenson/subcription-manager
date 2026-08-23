import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
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
  static String summary(TrackedItem item, LocalDate today) {
    final parts = <String>[
      when(item, today),
      MoneyFormat.shortDate(item.expiresOn),
    ];

    final money = item.money;
    if (money != null) parts.add(MoneyFormat.full(money));
    return parts.join(' · ');
  }

  /// The relative half of the summary line.
  ///
  /// A document *expires*; everything else is *due*. The extra branch earns
  /// its keep: "Due tomorrow" on a passport reads as a bill, and a passport is
  /// not something the user can settle by tapping Pay.
  static String when(TrackedItem item, LocalDate today) {
    final days = today.daysUntil(item.expiresOn);
    final expiring = item.category == Category.document;

    if (days < 0) {
      final late = -days;
      return expiring
          ? 'Expired ${_days(late)} ago'
          : 'Overdue by ${_days(late)}';
    }
    if (days == 0) return expiring ? 'Expires today' : 'Due today';
    if (days == 1) return expiring ? 'Expires tomorrow' : 'Due tomorrow';
    return expiring ? 'Expires in ${_days(days)}' : 'Due in ${_days(days)}';
  }

  static String _days(int days) => days == 1 ? '1 day' : '$days days';

  /// The `Repeats` row: `Monthly · 2 of 3`, or just `Monthly`.
  static String repeatLabel(TrackedItem item) {
    final cycle = cycleLabel(item.cycle);
    final total = item.repeatCount;
    if (item.cycle == null || total == null) return cycle;
    return '$cycle · $total times';
  }

  /// The line under the instalment pips: `3 paid · this one due · 2 left`.
  ///
  /// Spelled out rather than left to the pips alone. The pips say the shape of
  /// it at a glance; this says it in a form a screen reader can read and a
  /// hurried reader can trust.
  static String instalmentLine(Instalments position) {
    final parts = <String>[];
    if (position.paid > 0) {
      parts.add('${position.paid} paid');
    }
    parts.add('this one due');
    if (position.left > 0) {
      parts.add('${position.left} left');
    } else {
      parts.add('last one');
    }
    return parts.join(' · ');
  }

  static String categoryLabel(Category category) => switch (category) {
    Category.subscription => 'Subscription',
    Category.bill => 'Bill',
    Category.insurance => 'Insurance',
    Category.document => 'Document',
    Category.other => 'Other',
  };

  static String cycleLabel(Cycle? cycle) {
    if (cycle == null) return 'Once';
    return switch ((cycle.unit, cycle.step)) {
      (CycleUnit.day, 7) => 'Weekly',
      (CycleUnit.month, 1) => 'Monthly',
      (CycleUnit.month, 3) => 'Quarterly',
      (CycleUnit.month, 6) => 'Twice a year',
      (CycleUnit.month, 12) => 'Yearly',
      _ => 'Every ${cycleEvery(cycle)}',
    };
  }

  /// The interval on its own, pluralised: `5 months`, `2 weeks`, `10 days`.
  ///
  /// Read back in the largest unit it divides into, because a user who typed
  /// "every 2 weeks" must not find "every 14 days" on the item afterwards.
  static String cycleEvery(Cycle cycle) {
    final (count, field) = cycle.inLargestField;
    final noun = switch (field) {
      CycleField.day => 'day',
      CycleField.week => 'week',
      CycleField.month => 'month',
      CycleField.year => 'year',
    };
    return count == 1 ? noun : '$count ${noun}s';
  }

  /// The interval abbreviated to fit a segment or a pill: `5 mo`, `2 wk`.
  static String cycleEveryShort(Cycle cycle) {
    final (count, field) = cycle.inLargestField;
    final unit = switch (field) {
      CycleField.day => 'd',
      CycleField.week => 'wk',
      CycleField.month => 'mo',
      CycleField.year => 'yr',
    };
    return '$count $unit';
  }

  /// The suffix on a cost: `$20.00 / mo`.
  static String? cyclePer(Cycle? cycle) {
    if (cycle == null) return null;
    return switch ((cycle.unit, cycle.step)) {
      (CycleUnit.day, 7) => '/ wk',
      (CycleUnit.month, 1) => '/ mo',
      (CycleUnit.month, 3) => '/ qtr',
      (CycleUnit.month, 6) => '/ 6 mo',
      (CycleUnit.month, 12) => '/ yr',
      _ => '/ ${cycleEveryShort(cycle)}',
    };
  }

  /// How much the shown date can be trusted.
  ///
  /// The app cannot read the provider's records; it only knows what was typed.
  /// A date shown with more confidence than its source deserves is the failure
  /// this label exists to prevent.
  static String dateSourceLabel(DateSource source) => switch (source) {
    DateSource.userConfirmed => 'confirmed with the provider',
    DateSource.userEstimated => 'from memory',
    DateSource.computed => 'worked out from the cycle',
    DateSource.extracted => 'read from an image, not checked',
  };

  /// The reminder ladder as short chips: `7 days before`, `On the day`.
  static List<String> leadLabels(List<int> leadDays) => [
    for (final lead in leadDays) leadLabel(lead),
  ];

  static String leadLabel(int lead) => switch (lead) {
    0 => 'On the day',
    1 => '1 day before',
    final days => '$days days before',
  };

  /// The line under the delete button. Names the consequences so the
  /// confirmation is informed rather than reflexive.
  static String deleteConsequence(int reminderCount) {
    final reminders = reminderCount == 0
        ? 'No reminders are pending.'
        : 'Removes $reminderCount pending ${reminderCount == 1 ? "reminder" : "reminders"}.';
    return '$reminders What you have already paid stays under Money.';
  }
}
