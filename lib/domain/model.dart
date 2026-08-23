import 'package:meta/meta.dart';

import 'local_date.dart';
import 'money.dart';
import 'recurrence.dart';
import 'reminders.dart';

/// Every persisted enum carries an explicit [wireName] rather than relying on
/// the Dart identifier.
///
/// Storage and the backup file are written in terms of these strings. Tying
/// them to identifier names instead would mean a rename in an editor silently
/// rewrites the storage format and orphans every existing row.
mixin WireNamed on Enum {
  String get wireName;
}

/// Finds the member whose [WireNamed.wireName] matches [wire], or returns
/// [fallback].
///
/// Reading is deliberately lenient: a value this build does not recognise must
/// not take the whole database down. Every caller picks a fallback that is
/// *less* trusted than any real value, never more. See [DateSource].
T enumFromWire<T extends WireNamed>(List<T> values, String? wire, T fallback) {
  if (wire == null) return fallback;
  for (final value in values) {
    if (value.wireName == wire) return value;
  }
  return fallback;
}

/// What this item is. One axis with five values.
///
/// The hand-off's data model gives an item a single `category` and nothing
/// beside it, so the old pair — a five-value `kind` and an eight-value spend
/// `categoryId` that mostly restated it — is collapsed to this. Two
/// classifications the user has to keep aligned is one classification too
/// many; that is the same mistake the risk axis was removed for.
enum Category with WireNamed {
  /// Anything that renews itself until stopped: streaming, software, a phone
  /// plan, a free trial that is going to convert.
  subscription('SUBSCRIPTION'),

  /// An amount owed by a date: electricity, an instalment, a top-up.
  bill('BILL'),

  /// A policy that lapses if the premium is missed.
  insurance('INSURANCE'),

  /// Expires and must be renewed; never counted as spend.
  document('DOCUMENT'),

  /// Everything the other four do not describe. Offered last, never guessed
  /// into: an item lands here because the user put it here.
  other('OTHER');

  const Category(this.wireName);

  @override
  final String wireName;
}

enum ItemState with WireNamed {
  active('ACTIVE'),

  /// Cancelled but still usable until the period ends. Not the same as deleted.
  cancelledStillActive('CANCELLED_STILL_ACTIVE'),
  archived('ARCHIVED');

  const ItemState(this.wireName);

  @override
  final String wireName;
}

enum NagPolicy with WireNamed {
  none('NONE'),
  daily('DAILY'),
  weekly('WEEKLY');

  const NagPolicy(this.wireName);

  @override
  final String wireName;
}

/// Where the due date came from. The app only knows what the user typed; it
/// cannot read the provider's records. A date shown with more confidence than
/// its source deserves is the failure this enum exists to prevent.
enum DateSource with WireNamed {
  /// User checked with the provider and typed what they were told.
  userConfirmed('USER_CONFIRMED'),

  /// User typed it from memory.
  userEstimated('USER_ESTIMATED'),

  /// The app computed it from a cycle.
  computed('COMPUTED'),

  /// Read out of an image and not yet confirmed against the source.
  extracted('EXTRACTED');

  const DateSource(this.wireName);

  @override
  final String wireName;
}

/// Cycle is persisted too, so it needs wire names on the same terms. Kept out
/// of `recurrence.dart` so that file stays pure calendar arithmetic.
///
/// The five presets keep the names they have always had. A custom interval is
/// written as `EVERY_<n>_<unit>`, which stays legible in a sqlite3 shell and,
/// more importantly, is not a name an older build could mistake for a preset:
/// [fromWire] returns null for anything it does not recognise, so a build that
/// predates custom cycles reads such a row as a one-off rather than as the
/// wrong cycle.
extension CycleWire on Cycle {
  String get wireName => switch ((unit, step)) {
    (CycleUnit.day, 7) => 'WEEKLY',
    (CycleUnit.month, 1) => 'MONTHLY',
    (CycleUnit.month, 3) => 'QUARTERLY',
    (CycleUnit.month, 6) => 'SEMIANNUAL',
    (CycleUnit.month, 12) => 'YEARLY',
    (CycleUnit.day, _) => 'EVERY_${step}_DAY',
    (CycleUnit.month, _) => 'EVERY_${step}_MONTH',
  };

  static final RegExp _custom = RegExp(r'^EVERY_(\d{1,3})_(DAY|MONTH)$');

  static Cycle? fromWire(String? wire) {
    if (wire == null) return null;
    for (final cycle in Cycle.values) {
      if (cycle.wireName == wire) return cycle;
    }

    final match = _custom.firstMatch(wire);
    if (match == null) return null;

    final step = int.parse(match.group(1)!);
    if (step < 1 || step > Cycle.maxStep) return null;
    return match.group(2) == 'DAY'
        ? Cycle.every(step, CycleField.day)
        : Cycle.every(step, CycleField.month);
  }
}

@immutable
class TrackedItem {
  final String id;
  final String name;
  final Category category;

  /// The chosen icon's key, or null to let the name decide.
  ///
  /// Null is the normal state: the icon is detected from the name every time
  /// it is drawn, so renaming "Netflix" to "Netflix Premium" keeps its icon
  /// without a migration. A non-null value means the user overrode that, and
  /// an override is never re-guessed.
  final String? iconName;

  /// The date the thing actually expires.
  final LocalDate expiresOn;

  /// How many days before expiry the user must have acted. See spec 5.3.
  final int actByOffsetDays;

  /// The original date, never mutated. Cycle maths anchors here. See spec 5.2.
  final LocalDate anchorDate;
  final Cycle? cycle;

  /// How many occurrences this item has in total, or null for "forever".
  ///
  /// Only meaningful alongside a [cycle]: a one-off already happens exactly
  /// once. A course paid in six instalments is the case this exists for, and
  /// the difference matters — the app has to stop reminding after the sixth,
  /// and it has to be able to say "payment 4 of 6" while it is still going.
  final int? repeatCount;

  final int? amountMinor;
  final String? currency;

  final String? actionUrl;
  final String? actionLabel;
  final String? note;

  final List<int> leadDays;
  final LocalTime remindAt;
  final NagPolicy nagAfterDue;

  final int? verifyEveryDays;
  final LocalDate? lastVerifiedAt;
  final DateSource dateSource;

  /// One extra reminder the user asked for, on top of the ladder.
  ///
  /// Set by "Remind me again in 3 days" and by the notification's "Remind
  /// tomorrow" button; cleared as soon as the occurrence is handled. A single
  /// date rather than a queue, because a second snooze replaces the first —
  /// what the user means both times is "not now, then".
  final LocalDate? snoozedUntil;

  final ItemState state;

  TrackedItem({
    required this.id,
    required this.name,
    required this.category,
    this.iconName,
    required this.expiresOn,
    this.actByOffsetDays = 0,
    required this.anchorDate,
    this.cycle,
    this.repeatCount,
    this.amountMinor,
    this.currency,
    this.actionUrl,
    this.actionLabel,
    this.note,
    List<int>? leadDays,
    this.remindAt = Reminders.defaultRemindAt,
    NagPolicy? nagAfterDue,
    int? verifyEveryDays,
    this.lastVerifiedAt,
    this.dateSource = DateSource.userEstimated,
    this.snoozedUntil,
    this.state = ItemState.active,
    // Dart cannot express "default to null" and "default to a computed value"
    // in the same optional parameter, so an explicit null for a
    // category-defaulted field is passed as a flag instead of guessing.
    bool verifyEveryDaysIsExplicit = false,
  }) : leadDays = List.unmodifiable(
         leadDays ?? Reminders.defaultLeadDays(category),
       ),
       nagAfterDue = nagAfterDue ?? Reminders.defaultNagPolicy(category),
       verifyEveryDays = verifyEveryDaysIsExplicit
           ? verifyEveryDays
           : (verifyEveryDays ?? Reminders.defaultVerifyEveryDaysFor(category));

  Money? get money => (amountMinor != null && currency != null)
      ? Money(amountMinor!, currency!)
      : null;

  /// The date reminders anchor on. Earlier than expiry whenever acting takes
  /// lead time.
  LocalDate get actBy => Recurrence.actBy(expiresOn, actByOffsetDays);

  /// A document is renewed, not bought on a cycle; its fee is not a
  /// subscription and must not land in a monthly spend total.
  bool get countsTowardSpend => money != null && category != Category.document;

  TrackedItem copyWith({
    String? id,
    String? name,
    Category? category,
    String? Function()? iconName,
    LocalDate? expiresOn,
    int? actByOffsetDays,
    LocalDate? anchorDate,
    Cycle? Function()? cycle,
    int? Function()? repeatCount,
    int? Function()? amountMinor,
    String? Function()? currency,
    String? Function()? actionUrl,
    String? Function()? actionLabel,
    String? Function()? note,
    List<int>? leadDays,
    LocalTime? remindAt,
    NagPolicy? nagAfterDue,
    int? Function()? verifyEveryDays,
    LocalDate? Function()? lastVerifiedAt,
    DateSource? dateSource,
    LocalDate? Function()? snoozedUntil,
    ItemState? state,
  }) {
    return TrackedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      iconName: iconName != null ? iconName() : this.iconName,
      expiresOn: expiresOn ?? this.expiresOn,
      actByOffsetDays: actByOffsetDays ?? this.actByOffsetDays,
      anchorDate: anchorDate ?? this.anchorDate,
      cycle: cycle != null ? cycle() : this.cycle,
      repeatCount: repeatCount != null ? repeatCount() : this.repeatCount,
      amountMinor: amountMinor != null ? amountMinor() : this.amountMinor,
      currency: currency != null ? currency() : this.currency,
      actionUrl: actionUrl != null ? actionUrl() : this.actionUrl,
      actionLabel: actionLabel != null ? actionLabel() : this.actionLabel,
      note: note != null ? note() : this.note,
      leadDays: leadDays ?? this.leadDays,
      remindAt: remindAt ?? this.remindAt,
      nagAfterDue: nagAfterDue ?? this.nagAfterDue,
      verifyEveryDays: verifyEveryDays != null
          ? verifyEveryDays()
          : this.verifyEveryDays,
      verifyEveryDaysIsExplicit: true,
      lastVerifiedAt: lastVerifiedAt != null
          ? lastVerifiedAt()
          : this.lastVerifiedAt,
      dateSource: dateSource ?? this.dateSource,
      snoozedUntil: snoozedUntil != null ? snoozedUntil() : this.snoozedUntil,
      state: state ?? this.state,
    );
  }
}

/// One completed occurrence. Append-only; never edited once written.
@immutable
class HandledEvent {
  final String id;
  final String itemId;
  final int handledAtEpochSeconds;
  final LocalDate forDueDate;

  // Money is snapshotted here and never recomputed. See spec section 6.3.
  final int? amountMinor;
  final String? currency;
  final int? fxRateScaled;
  final int? fxRateScale;
  final LocalDate? fxRateDate;
  final String? fxSource;
  final int? baseAmountMinor;

  /// Typed off a bank statement. Overrides every computed figure when present.
  final int? actualChargedMinor;

  const HandledEvent({
    required this.id,
    required this.itemId,
    required this.handledAtEpochSeconds,
    required this.forDueDate,
    this.amountMinor,
    this.currency,
    this.fxRateScaled,
    this.fxRateScale,
    this.fxRateDate,
    this.fxSource,
    this.baseAmountMinor,
    this.actualChargedMinor,
  });

  HandledEvent copyWith({String? id, int? actualChargedMinor}) => HandledEvent(
    id: id ?? this.id,
    itemId: itemId,
    handledAtEpochSeconds: handledAtEpochSeconds,
    forDueDate: forDueDate,
    amountMinor: amountMinor,
    currency: currency,
    fxRateScaled: fxRateScaled,
    fxRateScale: fxRateScale,
    fxRateDate: fxRateDate,
    fxSource: fxSource,
    baseAmountMinor: baseAmountMinor,
    actualChargedMinor: actualChargedMinor ?? this.actualChargedMinor,
  );
}
