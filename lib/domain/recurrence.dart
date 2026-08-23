import 'local_date.dart';

/// How often an item comes round again. A null cycle means it happens once.
enum Cycle {
  weekly(unit: CycleUnit.day, step: 7),
  monthly(unit: CycleUnit.month, step: 1),
  quarterly(unit: CycleUnit.month, step: 3),
  semiannual(unit: CycleUnit.month, step: 6),
  yearly(unit: CycleUnit.month, step: 12);

  const Cycle({required this.unit, required this.step});

  final CycleUnit unit;
  final int step;
}

enum CycleUnit { day, month }

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
