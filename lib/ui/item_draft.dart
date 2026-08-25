import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/category_book.dart';
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

  /// The shelf the user picked, carried whole rather than by id: the form shows
  /// its label, and [applyTo] reads its reminder defaults when the shelf moves.
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

  /// The day a free trial began, or null for an item being paid for.
  ///
  /// There is no separate trial-end field, and there must not be: the end of
  /// the free period is the day the first charge lands, which is [expiresOn].
  /// Two fields for one date is two things that can disagree.
  final LocalDate? trialStart;

  /// Which source pays for this, or null for "not said".
  final String? paymentSourceId;

  const DraftItem({
    required this.name,
    required this.expiresOn,
    required this.category,
    this.iconName,
    this.cycle,
    this.repeatCount,
    this.amountMinor,
    this.currency,
    this.leadDays = const [Reminders.defaultLead],
    this.matched,
    this.trialStart,
    this.paymentSourceId,
  });

  /// Seeds the form from an item that already exists.
  ///
  /// Deliberately does not carry the catalog match: the link and the note on
  /// the item were settled when it was created, and re-deriving them from the
  /// name would overwrite whatever the user has since put there.
  factory DraftItem.of(TrackedItem item, CategoryBook categories) => DraftItem(
    name: item.name,
    expiresOn: item.expiresOn,
    category: categories[item.categoryId],
    iconName: item.iconName,
    cycle: item.cycle,
    repeatCount: item.repeatCount,
    amountMinor: item.amountMinor,
    currency: item.currency,
    leadDays: item.leadDays,
    trialStart: item.trialStart,
    paymentSourceId: item.paymentSourceId,
  );

  /// Folds this draft back into the item it was seeded from.
  ///
  /// A merge, not a rebuild: the form asks for eight things and a
  /// [TrackedItem] carries two dozen. Everything the form never showed — the
  /// act-by offset, the verify cadence, the history the item's id points at —
  /// has to come through the edit untouched.
  TrackedItem applyTo(TrackedItem original) {
    final dateChanged = expiresOn != original.expiresOn;
    final categoryChanged = category.id != original.categoryId;
    final entry = matched;

    return original.copyWith(
      name: name,
      categoryId: category.id,
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
      // Both come from the shelf and neither is on the form, so they are taken
      // again when the shelf moves and left alone otherwise. An item whose
      // reminders the user tuned by hand keeps them until they file it
      // somewhere else, which is the one move that says the old defaults were
      // for a different kind of thing.
      nagAfterDue: categoryChanged ? category.nag : null,
      verifyEveryDays: categoryChanged ? () => category.verifyEveryDays : null,
      // A date the user has just retyped is a date from memory again, and a
      // snooze on the books was postponing the occurrence they have moved.
      dateSource: dateChanged ? DateSource.userEstimated : null,
      snoozedUntil: dateChanged ? () => null : null,
      actionUrl: entry == null ? null : () => entry.cancelUrl,
      note: entry == null ? null : () => entry.noteVi,
      trialStart: () => trialStart,
      paymentSourceId: () => paymentSourceId,
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
