import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/reminders.dart';

/// What the item form produces.
///
/// The screen never writes to storage itself, so the same widget serves "add"
/// and "edit" and neither needs a repository. [DraftItem.of] seeds the form
/// from an item that exists; [applyTo] folds the answers back into it.
class DraftItem {
  final String name;
  final LocalDate expiresOn;
  final Category category;

  /// The icon the user picked, or null to let the name decide.
  final String? iconName;

  final Cycle? cycle;

  /// Null for "forever". Only ever set alongside a [cycle].
  final int? repeatCount;

  final int? amountMinor;
  final String? currency;
  final List<int> leadDays;

  /// The catalog row the name matched, when it matched one. Carries the cancel
  /// link and the note, neither of which the form asks for.
  final CatalogEntry? matched;

  const DraftItem({
    required this.name,
    required this.expiresOn,
    this.category = Category.subscription,
    this.iconName,
    this.cycle,
    this.repeatCount,
    this.amountMinor,
    this.currency,
    this.leadDays = const [Reminders.defaultLead],
    this.matched,
  });

  /// Seeds the form from an item that already exists.
  ///
  /// Deliberately does not carry the catalog match: the link and the note on
  /// the item were settled when it was created, and re-deriving them from the
  /// name would overwrite whatever the user has since put there.
  factory DraftItem.of(TrackedItem item) => DraftItem(
    name: item.name,
    expiresOn: item.expiresOn,
    category: item.category,
    iconName: item.iconName,
    cycle: item.cycle,
    repeatCount: item.repeatCount,
    amountMinor: item.amountMinor,
    currency: item.currency,
    leadDays: item.leadDays,
  );

  /// Folds this draft back into the item it was seeded from.
  ///
  /// A merge, not a rebuild: the form asks for eight things and a
  /// [TrackedItem] carries two dozen. Everything the form never showed — the
  /// act-by offset, the verify cadence, the history the item's id points at —
  /// has to come through the edit untouched.
  TrackedItem applyTo(TrackedItem original) {
    final dateChanged = expiresOn != original.expiresOn;
    final categoryChanged = category != original.category;
    final entry = matched;

    return original.copyWith(
      name: name,
      category: category,
      iconName: () => iconName,
      expiresOn: expiresOn,
      anchorDate: _anchorFor(original),
      cycle: () => cycle,
      // A one-off cannot have a count. Dropping the cycle has to drop it too,
      // or "payment 4 of 6" survives on an item that now happens once.
      repeatCount: () => cycle == null ? null : repeatCount,
      amountMinor: () => amountMinor,
      currency: () => currency,
      leadDays: leadDays,
      // Both are derived from the category and neither is on the form, so they
      // are re-derived when the category moves and left alone otherwise.
      nagAfterDue: categoryChanged
          ? Reminders.defaultNagPolicy(category)
          : null,
      verifyEveryDays: categoryChanged
          ? () => Reminders.defaultVerifyEveryDaysFor(category)
          : null,
      // A date the user has just retyped is a date from memory again, and a
      // snooze on the books was postponing the occurrence they have moved.
      dateSource: dateChanged ? DateSource.userEstimated : null,
      snoozedUntil: dateChanged ? () => null : null,
      actionUrl: entry == null ? null : () => entry.cancelUrl,
      note: entry == null ? null : () => entry.noteVi,
    );
  }

  /// Where the cycle maths counts from once the due date has moved.
  ///
  /// The anchor follows the date, but keeps the item's place in a counted
  /// plan: a course on payment 4 of 6 must still read 4 of 6 after its date is
  /// corrected, and [Instalments] reads that off the distance between the
  /// anchor and the due date. Leaving the old anchor where it was instead
  /// would undo the edit on the next mark-as-paid, because the next occurrence
  /// is computed from the anchor's own day of the month.
  LocalDate _anchorFor(TrackedItem original) {
    final target = cycle;
    if (target == null) return expiresOn;

    final was = original.cycle;
    final elapsed = was == null
        ? 0
        : Recurrence.cyclesElapsed(
            original.anchorDate,
            was,
            original.expiresOn,
          );
    return Recurrence.occurrenceBefore(expiresOn, target, elapsed);
  }
}
