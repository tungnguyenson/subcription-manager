import 'package:meta/meta.dart';

import 'local_date.dart';
import 'model.dart';
import 'money.dart';
import 'recurrence.dart';

/// Where an item is inside a cycle that ends.
///
/// A subscription runs until it is stopped; a course paid in six instalments
/// does not. The difference is not cosmetic — the app has to stop reminding
/// after the sixth payment, and until then it has to be able to say which
/// payment this one is. Both facts are derived here rather than stored, so a
/// mark-as-paid that moves the due date cannot leave a counter behind.
///
/// The position is computed from [TrackedItem.anchorDate], never by counting
/// how many times the user pressed a button. Counting presses drifts the first
/// time a payment is recorded twice or restored from a backup.
@immutable
class Instalments {
  /// Which payment the item's current due date is. 1-based, so it reads the
  /// way the screen says it: "payment 4 of 6".
  final int index;

  final int total;

  const Instalments({required this.index, required this.total});

  /// How many are already behind this one.
  int get paid => index - 1;

  /// How many come after this one.
  int get left => total - index;

  bool get isLast => index >= total;

  /// True once the last payment has been made and the item is done for good.
  bool get isComplete => index > total;

  /// Null unless the item both repeats and has an end. Everything else in the
  /// app treats a null here as "forever", which is the honest reading: an item
  /// with no declared count has no last payment to name.
  static Instalments? of(TrackedItem item) {
    final cycle = item.cycle;
    final total = item.repeatCount;
    if (cycle == null || total == null || total < 1) return null;

    return Instalments(
      index:
          Recurrence.cyclesElapsed(item.anchorDate, cycle, item.expiresOn) + 1,
      total: total,
    );
  }

  /// The date of the final payment, or null when there is no final payment.
  static LocalDate? lastOccurrence(TrackedItem item) {
    final cycle = item.cycle;
    final total = item.repeatCount;
    if (cycle == null || total == null || total < 1) return null;
    return Recurrence.occurrenceAfter(item.anchorDate, cycle, total - 1);
  }

  /// What is still owed after the current payment.
  ///
  /// Deliberately excludes the payment that is due now: the user is looking at
  /// this screen because they are about to make that one, and folding it in
  /// would answer a question they did not ask.
  static Money? totalLeft(TrackedItem item) {
    final money = item.money;
    final position = of(item);
    if (money == null || position == null) return null;
    if (position.left <= 0) return null;
    return Money(money.minor * position.left, money.currency);
  }
}
