import 'package:meta/meta.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/money_format.dart';

/// The yearly-versus-monthly block, already worded.
///
/// Every number here comes from a [CatalogPlan], which means every one of them
/// has a vendor page and a date behind it. That is also this block's biggest
/// hazard: a listed price is not the price the user pays. They may be on a
/// promotion, a legacy tier, a family plan split four ways, or a reseller. So
/// [sourceLine] is not decoration and is never absent, and [mismatchLine]
/// exists to say out loud when the app's arithmetic and the user's own number
/// disagree.
///
/// The amounts are kept apart from the words around them because the design
/// sets every figure in IBM Plex Mono and the sentences in Be Vietnam Pro. A
/// presenter that returned one joined string would force the widget to find
/// the number again by searching its own output.
@immutable
class AnnualSavingCopy {
  /// `Save`, or `Save about` once the price is old enough to hedge.
  final String savingLead;

  /// `456,000 ₫`.
  final String savingAmount;

  /// `129,000 ₫ × 12 = 1,548,000 ₫`. The multiplication is shown rather than
  /// folded away: it is what lets a user whose own price differs redo the sum
  /// in their head instead of trusting the total.
  final String monthlyValue;

  /// `1,092,000 ₫`.
  final String yearlyValue;

  /// Where the two numbers came from, and when. Doubles as the staleness
  /// notice once the price is old enough to doubt.
  final String sourceLine;

  /// Present only when the user's own cost sits far enough from the listed one
  /// that the sum above would look wrong to them. Null the rest of the time,
  /// because a line explaining a difference of two thousand dong is noise.
  final String? mismatchLine;

  /// True once the price is over a year old. The wording already hedges; this
  /// is for the layout, which gives the source line more weight when it has
  /// stopped being a footnote and started being a caveat.
  final bool stale;

  const AnnualSavingCopy({
    required this.savingLead,
    required this.savingAmount,
    required this.monthlyValue,
    required this.yearlyValue,
    required this.sourceLine,
    this.mismatchLine,
    this.stale = false,
  });

  /// The headline as one sentence. What the widget reads out to a screen
  /// reader, and what a test asserts on.
  String get headline => '$savingLead $savingAmount a year';
}

abstract final class AnnualSavingPresenter {
  /// A price older than this stops being stated and starts being suggested.
  ///
  /// Twelve months, not six: most vendors move list prices about once a year,
  /// so a six-month hedge would print "check the current price" on nearly
  /// every entry and teach the user to read straight past it.
  static const int staleAfterMonths = 12;

  /// How far the user's own cost may sit from the listed one before the block
  /// says so. Ten percent clears the usual small differences (tax rounding, a
  /// reseller's markup) and catches the ones that make the sum look broken.
  static const int mismatchPercent = 10;

  /// The block for [item], or null when there is nothing honest to show.
  ///
  /// Null is the common answer, and deliberately so: two thirds of the
  /// catalogue has no monthly/yearly pair at all, an item already billed
  /// yearly must not be invited to do what it has already done, and a bill or
  /// a document has no listed price to compare in the first place.
  static AnnualSavingCopy? of({
    required TrackedItem item,
    required CatalogEntry? entry,
    required LocalDate today,
  }) {
    if (entry == null) return null;
    if (!_billedMoreOftenThanYearly(item.cycle)) return null;

    final saving = _worthShowing(entry);
    if (saving == null) return null;

    final currency = saving.currency;
    final monthly = Money(saving.monthly.amountMinor, currency);
    final yearly = Money(saving.yearly.amountMinor, currency);
    final twelve = Money(saving.monthly.amountMinor * 12, currency);
    final saved = Money(saving.savingMinor, currency);

    // The older of the two dates. The sum is only as fresh as its weaker half,
    // and quoting the newer one would overstate how current it is.
    final checked = LocalDate.min(
      LocalDate.parse(saving.monthly.checkedAt),
      LocalDate.parse(saving.yearly.checkedAt),
    );
    final stale = _monthsBetween(checked, today) > staleAfterMonths;

    return AnnualSavingCopy(
      savingLead: stale ? 'Save about' : 'Save',
      savingAmount: MoneyFormat.full(saved),
      monthlyValue:
          '${MoneyFormat.full(monthly)} × 12 = ${MoneyFormat.full(twelve)}',
      yearlyValue: MoneyFormat.full(yearly),
      sourceLine: stale
          ? 'Listed price from ${DateCopy.listedDate(checked)} — '
                'check the current price'
          : 'Listed price, checked ${DateCopy.listedDate(checked)}',
      mismatchLine: _mismatchLine(item, monthly),
      stale: stale,
    );
  }

  /// The pair worth putting on screen: Vietnam first, then global.
  ///
  /// The VN price is the amount actually taken off a card here, so it wins
  /// whenever both exist. A global price in dollars is still worth showing
  /// when it is all there is.
  ///
  /// A saving of zero counts as nothing to show. Some vendors list the yearly
  /// plan at exactly twelve monthly payments and put the discount in a
  /// promotion instead; `Save 0 ₫ a year` is not a smaller version of this
  /// block, it is a different and much worse one.
  static AnnualSaving? _worthShowing(CatalogEntry entry) {
    for (final region in const ['VN', 'GLOBAL']) {
      final saving = entry.annualSaving(region: region);
      if (saving != null && saving.savingMinor > 0) return saving;
    }
    return null;
  }

  /// True for an item billed more often than once a year.
  ///
  /// A one-off has nothing to compare, and an item already on a yearly or
  /// longer cycle has already done the thing this block would suggest.
  static bool _billedMoreOftenThanYearly(Cycle? cycle) => switch (cycle) {
    null => false,
    Cycle(unit: CycleUnit.month, :final step) => step < 12,
    Cycle(unit: CycleUnit.day, :final step) => step < 365,
  };

  /// `Based on the listed price of 129,000 ₫, not the 99,000 ₫ you entered`.
  ///
  /// Only for an item billed monthly: the sum above multiplies a *monthly*
  /// price by twelve, so setting it beside a quarterly amount would compare
  /// two different things and read as a bug in the app.
  static String? _mismatchLine(TrackedItem item, Money listed) {
    if (item.cycle != Cycle.monthly) return null;

    final theirs = item.money;
    if (theirs == null) return null;
    if (theirs.currency != listed.currency) return null;
    if (listed.minor == 0) return null;

    final gap = (theirs.minor - listed.minor).abs();
    if (gap * 100 < listed.minor.abs() * mismatchPercent) return null;

    return 'Based on the listed price of ${MoneyFormat.full(listed)}, '
        'not the ${MoneyFormat.full(theirs)} you entered';
  }

  /// Whole months from [from] to [to], floored. Good enough for a staleness
  /// threshold and cheaper than being exact about it.
  static int _monthsBetween(LocalDate from, LocalDate to) {
    final months = (to.year - from.year) * 12 + (to.month - from.month);
    return to.day < from.day ? months - 1 : months;
  }
}
