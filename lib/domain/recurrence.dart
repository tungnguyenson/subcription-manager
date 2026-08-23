import 'package:meta/meta.dart';

import 'local_date.dart';

/// How often an item comes round again. A null cycle means it happens once.
///
/// A value, not an enum. The five named cycles below cover almost everything,
/// but "every 5 months" is a real contract, and a form that cannot say it
/// sends the user back to a one-off they have to re-date by hand every time.
///
/// Custom intervals are canonicalised into the same two units the presets use,
/// so there is exactly one representation of any interval: `Cycle.every(2,
/// CycleField.week)` *is* [Cycle.weekly] doubled, and `Cycle.every(1,
/// CycleField.year)` *is* [Cycle.yearly]. Two ways of writing one interval
/// would compare unequal and quietly split every downstream grouping.
@immutable
class Cycle {
  /// Days or months. Weeks and years are stored as their multiples, because a
  /// separate unit for them would make 14 days and 2 weeks two different
  /// values that behave identically.
  final CycleUnit unit;

  /// How many [unit]s between occurrences. Always at least 1.
  final int step;

  const Cycle._(this.unit, this.step);

  static const weekly = Cycle._(CycleUnit.day, 7);
  static const monthly = Cycle._(CycleUnit.month, 1);
  static const quarterly = Cycle._(CycleUnit.month, 3);
  static const semiannual = Cycle._(CycleUnit.month, 6);
  static const yearly = Cycle._(CycleUnit.month, 12);

  /// The named cycles, in ascending length. Not every cycle that exists — a
  /// custom one is a [Cycle] too — so nothing may treat this as exhaustive.
  static const List<Cycle> values = [
    weekly,
    monthly,
    quarterly,
    semiannual,
    yearly,
  ];

  /// An arbitrary interval: every [count] [field]s.
  factory Cycle.every(int count, CycleField field) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    if (count > maxStep) {
      throw ArgumentError.value(count, 'count', 'must be at most $maxStep');
    }
    return switch (field) {
      CycleField.day => Cycle._(CycleUnit.day, count),
      CycleField.week => Cycle._(CycleUnit.day, count * 7),
      CycleField.month => Cycle._(CycleUnit.month, count),
      CycleField.year => Cycle._(CycleUnit.month, count * 12),
    };
  }

  /// A ceiling on the interval, so a mistyped step cannot ask the planner to
  /// walk ten thousand occurrences looking for the next due date.
  static const int maxStep = 480;

  /// True for the five [values], false for anything the user typed themselves.
  bool get isPreset => values.contains(this);

  /// The interval read back in the largest whole unit it fits: 14 days is
  /// 2 weeks, 24 months is 2 years, 5 months stays 5 months.
  (int, CycleField) get inLargestField => switch (unit) {
    CycleUnit.day when step % 7 == 0 => (step ~/ 7, CycleField.week),
    CycleUnit.day => (step, CycleField.day),
    CycleUnit.month when step % 12 == 0 => (step ~/ 12, CycleField.year),
    CycleUnit.month => (step, CycleField.month),
  };

  @override
  bool operator ==(Object other) =>
      other is Cycle && other.unit == unit && other.step == step;

  @override
  int get hashCode => Object.hash(unit, step);

  @override
  String toString() => 'Cycle(every $step ${unit.name})';
}

/// The two units cycle arithmetic actually runs in.
enum CycleUnit { day, month }

/// The units a person picks a cycle in, which is not the same list: weeks and
/// years are how people say it, days and months are how the calendar adds it.
enum CycleField { day, week, month, year }

/// Cycle arithmetic anchored to the original date.
///
/// The bug this guards against: adding one month at a time from 31 January
/// clamps each step, and the 31st is gone for good.
///
///     31 Jan -> 28 Feb -> 28 Mar -> 28 Apr ...
///
/// Computing the Nth occurrence from the anchor instead gives
/// 31 Jan + 2 months = 31 Mar, which is what a subscription actually does.
/// See product-spec.md section 5.2.
///
/// Every function here takes the anchor. None of them takes "the previous due
/// date", because that is the shape of the bug.
abstract final class Recurrence {
  /// The [n]th occurrence after [anchor]. `n = 0` is the anchor itself.
  static LocalDate occurrenceAfter(LocalDate anchor, Cycle cycle, int n) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'must not be negative');
    }
    final amount = cycle.step * n;
    return switch (cycle.unit) {
      CycleUnit.day => anchor.plusDays(amount),
      CycleUnit.month => anchor.plusMonths(amount),
    };
  }

  /// The occurrence [n] cycles *before* [date].
  ///
  /// The inverse of [occurrenceAfter], used when a due date is edited by hand
  /// and the anchor has to move with it without losing the item's place in a
  /// counted plan.
  ///
  /// Not an exact inverse where a month clamped: 31 Jan + 1 month is 28 Feb,
  /// and 28 Feb - 1 month is 28 Jan. The day the user just typed is the one
  /// worth keeping, so the loss lands on the anchor rather than on the date.
  static LocalDate occurrenceBefore(LocalDate date, Cycle cycle, int n) {
    if (n < 0) {
      throw ArgumentError.value(n, 'n', 'must not be negative');
    }
    final amount = cycle.step * n;
    return switch (cycle.unit) {
      CycleUnit.day => date.minusDays(amount),
      CycleUnit.month => date.plusMonths(-amount),
    };
  }

  /// How many whole cycles have elapsed from [anchor] up to and including
  /// [today].
  ///
  /// Counts forward rather than dividing the calendar distance, because
  /// month-length clamping makes that division non-exact. Cheap at realistic
  /// cycle counts.
  static int cyclesElapsed(LocalDate anchor, Cycle cycle, LocalDate today) {
    if (today <= anchor) return 0;
    var n = 0;
    while (occurrenceAfter(anchor, cycle, n + 1) <= today) {
      n++;
    }
    return n;
  }

  /// The first occurrence strictly after [today], or the anchor if it is still
  /// ahead. Null for one-off items that have already passed.
  static LocalDate? nextDue(LocalDate anchor, Cycle? cycle, LocalDate today) {
    if (cycle == null) return anchor > today ? anchor : null;
    if (anchor > today) return anchor;
    return occurrenceAfter(
      anchor,
      cycle,
      cyclesElapsed(anchor, cycle, today) + 1,
    );
  }

  /// The date the user must act by, which is earlier than the expiry for
  /// almost everything that matters: cancel a trial before it converts, top up
  /// before the line is barred, renew a passport months ahead. See spec 5.3.
  static LocalDate actBy(LocalDate expiresOn, int actByOffsetDays) {
    if (actByOffsetDays < 0) {
      throw ArgumentError.value(
        actByOffsetDays,
        'actByOffsetDays',
        'must not be negative',
      );
    }
    return expiresOn.minusDays(actByOffsetDays);
  }
}
