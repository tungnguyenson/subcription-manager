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

/// Whether a date on a shelf reads as money owed or as permission running out.
///
/// Not derivable from the item: a prepaid SIM is already paid for and still
/// expires, and a passport costs nothing on the day it lapses. It is a property
/// of the shelf, which is why the user picks it when they make one.
enum CategoryWording with WireNamed {
  /// "Due 22/08". Something will be taken.
  due('DUE'),

  /// "Expires 22/08". Something will stop working.
  expires('EXPIRES');

  const CategoryWording(this.wireName);

  @override
  final String wireName;
}

/// A shelf an item sits on, and the reminder defaults that come with it.
///
/// A row the user can edit rather than a value the app knows by name. The old
/// five-value enum could not answer the question the service list is read for
/// -- 199 of 223 catalogue entries were `SUBSCRIPTION`, so nearly everything
/// landed under one heading -- while the catalogue's own 21-way grouping had no
/// say in how anything behaved. Both are this one type now: the grouping the
/// user browses *is* the thing that carries the behaviour.
///
/// The app knows no shelf by name. Everything it used to decide with a switch
/// reads a field here instead, so a shelf someone invents on Tuesday behaves
/// exactly like a shipped one.
@immutable
class Category {
  /// Stable across renames. The shipped rows use the catalogue's own codes
  /// (`STREAMING`, `PHONE`); a user-made one gets a generated id.
  final String id;

  /// What the user reads. Editable on shipped rows too.
  final String label;

  /// The mark to draw, or null to work it out from the item's name the way an
  /// uncategorised item already does.
  final String? iconName;

  final CategoryWording wording;

  /// What happens after the date passes. Also decides time sensitivity: see
  /// [isTimeSensitive].
  final NagPolicy nag;

  /// The lead times a new item on this shelf starts with.
  final List<int> leadDays;

  /// How often to ask the user to re-check the date, or null for never.
  final int? verifyEveryDays;

  /// Whether an amount on this shelf counts as spending.
  ///
  /// False for paperwork: a passport fee is real money and still has no
  /// business in a monthly subscription total, because renewing one is not a
  /// recurring cost. A flag rather than something inferred from the cycle,
  /// because a document with a five-year cycle is still not a subscription.
  final bool countsTowardSpend;

  /// Shipped with the app. Only the manager reads it, to refuse deleting a
  /// shelf the bundled catalogue still points at.
  final bool builtIn;

  final int sortOrder;

  const Category({
    required this.id,
    required this.label,
    this.iconName,
    this.wording = CategoryWording.due,
    this.nag = NagPolicy.none,
    this.leadDays = const [Reminders.defaultLead],
    this.verifyEveryDays,
    this.countsTowardSpend = true,
    this.builtIn = false,
    required this.sortOrder,
  });

  /// Whether missing the date on this shelf costs something.
  ///
  /// Read off [nag] rather than stored beside it. Nagging after the date *is*
  /// the statement that something is at stake -- a shelf set to keep asking and
  /// a shelf with a consequence are the same shelf, and a second column would
  /// let the user set them to disagree.
  ///
  /// Two screens read it. Money files these amounts under bills rather than
  /// subscriptions: a bill is owed whether or not the user wants it, while the
  /// subscription band is money they could stop paying by cancelling, and
  /// mixing the two makes that number answer a different question.
  bool get isObligation => nag != NagPolicy.none;

  /// Whether a notification for this shelf should get past Focus and Do Not
  /// Disturb, using iOS's Time Sensitive interruption level.
  ///
  /// A deadline that arrives silently during Focus is a deadline the app failed
  /// to deliver; a subscription renewing is news, and news can wait.
  ///
  /// Deliberately not Critical Alert: that sounds through silent mode and needs
  /// a per-app entitlement granted by Apple.
  bool get isTimeSensitive => isObligation;

  Category copyWith({
    String? label,
    String? Function()? iconName,
    CategoryWording? wording,
    NagPolicy? nag,
    List<int>? leadDays,
    int? Function()? verifyEveryDays,
    bool? countsTowardSpend,
    int? sortOrder,
  }) => Category(
    id: id,
    label: label ?? this.label,
    iconName: iconName == null ? this.iconName : iconName(),
    wording: wording ?? this.wording,
    nag: nag ?? this.nag,
    leadDays: leadDays ?? this.leadDays,
    verifyEveryDays: verifyEveryDays == null
        ? this.verifyEveryDays
        : verifyEveryDays(),
    countsTowardSpend: countsTowardSpend ?? this.countsTowardSpend,
    builtIn: builtIn,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.label == label &&
      other.iconName == iconName &&
      other.wording == wording &&
      other.nag == nag &&
      other.verifyEveryDays == verifyEveryDays &&
      other.countsTowardSpend == countsTowardSpend &&
      other.builtIn == builtIn &&
      other.sortOrder == sortOrder &&
      _sameLeads(other.leadDays, leadDays);

  static bool _sameLeads(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    iconName,
    wording,
    nag,
    verifyEveryDays,
    countsTowardSpend,
    builtIn,
    sortOrder,
    Object.hashAll(leadDays),
  );
}

/// Where the user bought this subscription, which decides where they can go to
/// look at it.
///
/// Not a property of the service: Claude sells through the web, the App Store
/// and Google Play at once, and knowing that tells you nothing about where
/// *this* user is billed. Only they know, so it lives on their item -- the same
/// shape as [DateSource], and for the same reason.
///
/// [unknown] is the honest default. The app does not open with a question about
/// billing plumbing; it shows the vendor's page and offers the store as the
/// other answer, and the first tap records which one was right.
enum PurchaseChannel with WireNamed {
  unknown('UNKNOWN'),

  /// Bought on the vendor's own site, so the vendor's billing page is the one
  /// that shows it.
  web('WEB'),

  /// Bought as an in-app purchase on iOS. The vendor's own page will not show
  /// this subscription at all, which is the trap this enum exists to avoid.
  appStore('APP_STORE'),

  playStore('PLAY_STORE');

  const PurchaseChannel(this.wireName);

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

/// What the user decided about the "this plan costs less yearly" suggestion.
///
/// Three values because there are three answers, and the app must be able to
/// tell "not asked" from "asked and declined". Without the third, a dismissed
/// suggestion comes back on the next launch and the Savings screen becomes a
/// nag the user learns to scroll past.
enum YearlyChoice with WireNamed {
  /// Never acted on. The suggestion shows.
  undecided('UNDECIDED'),

  /// The user wants the renewal reminder to mention it.
  remind('REMIND'),

  /// Stop suggesting it. Reversible from the "N skipped — show again" line,
  /// which is why this is stored rather than a permanent opt-out.
  skipped('SKIPPED');

  const YearlyChoice(this.wireName);

  @override
  final String wireName;
}

/// Which mark to draw beside a payment source's name.
///
/// Five values, and no more coming. This is not a taxonomy of payment methods
/// -- it is a small set of shapes that make a list of user-written nicknames
/// scannable. "VCB 4412" with a card beside it and "Momo" with a wallet beside
/// it are told apart at a glance; the same two names in plain grey are not.
enum SourceGlyph with WireNamed {
  card('CARD'),
  bank('BANK'),
  wallet('WALLET'),

  /// Apple Pay, Google Pay -- a phone tapped against a terminal.
  contactless('CONTACTLESS'),

  cash('CASH');

  const SourceGlyph(this.wireName);

  @override
  final String wireName;
}

/// A card, wallet or account, named by the user.
///
/// **There is no field for a card number and there must never be one.** The
/// feature exists so a reminder can say which card is about to be charged, and
/// a nickname the user recognises does that completely. Subdock is offline and
/// accountless; a stored PAN would be the one thing in it worth stealing.
@immutable
class PaymentSource {
  final String id;
  final String name;
  final SourceGlyph glyph;

  const PaymentSource({
    required this.id,
    required this.name,
    this.glyph = SourceGlyph.card,
  });

  PaymentSource copyWith({String? name, SourceGlyph? glyph}) => PaymentSource(
    id: id,
    name: name ?? this.name,
    glyph: glyph ?? this.glyph,
  );
}

@immutable
class TrackedItem {
  final String id;
  final String name;

  /// Which shelf this sits on: a [Category.id].
  ///
  /// The id rather than the [Category] itself, because the shelf is a row the
  /// user edits: an item holding a copy would keep showing a label that was
  /// renamed and reminder defaults that were changed. Whoever needs the shelf
  /// looks it up, the same way an icon is worked out from the name at draw
  /// time rather than frozen into the row.
  final String categoryId;

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

  /// Where this one was bought. See [PurchaseChannel].
  final PurchaseChannel purchaseChannel;

  /// The day a free trial began, or null for an item being paid for.
  ///
  /// The trial's *end* is [expiresOn]: the day the free period stops is the day
  /// the first charge lands, and they cannot be allowed to disagree. Every
  /// reminder in the app already fires ahead of [expiresOn], which is exactly
  /// the promise a trial reminder makes — warn me while cancelling is still
  /// free.
  final LocalDate? trialStart;

  /// Which source pays for this, or null for "not said". See [PaymentSource].
  final String? paymentSourceId;

  /// Turned off by the user: no reminders, and hidden from Upcoming.
  ///
  /// Not a fourth [ItemState]. Pausing says "be quiet about this", and the
  /// three states say what has happened to the subscription itself, so a
  /// cancelled-but-still-running item can also be paused. Folding the two
  /// would make un-pausing an archived item impossible to express.
  final bool paused;

  /// What the user said about moving this to a yearly plan. See [YearlyChoice].
  final YearlyChoice yearlyChoice;

  TrackedItem({
    required this.id,
    required this.name,
    required this.categoryId,
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
    this.lastVerifiedAt,
    this.dateSource = DateSource.userEstimated,
    this.snoozedUntil,
    this.state = ItemState.active,
    this.purchaseChannel = PurchaseChannel.unknown,
    this.trialStart,
    this.paymentSourceId,
    this.paused = false,
    this.yearlyChoice = YearlyChoice.undecided,
    NagPolicy? nagAfterDue,
    this.verifyEveryDays,
  }) : leadDays = List.unmodifiable(leadDays ?? const [Reminders.defaultLead]),
       nagAfterDue = nagAfterDue ?? NagPolicy.none;

  /// A brand new item on [category], taking that shelf's reminder defaults.
  ///
  /// Separate from the constructor because the defaults can only be read off a
  /// row the caller has already loaded. The constructor used to compute them
  /// from an enum it could switch on; nothing can switch on a shelf any more,
  /// which is the point. Anything reading an existing item -- storage, backup,
  /// a copyWith -- goes through the constructor and carries what was stored.
  factory TrackedItem.on(
    Category category, {
    required String id,
    required String name,
    String? iconName,
    required LocalDate expiresOn,
    int actByOffsetDays = 0,
    required LocalDate anchorDate,
    Cycle? cycle,
    int? repeatCount,
    int? amountMinor,
    String? currency,
    String? actionUrl,
    String? actionLabel,
    String? note,
    List<int>? leadDays,
    LocalTime remindAt = Reminders.defaultRemindAt,
    NagPolicy? nagAfterDue,
    int? verifyEveryDays,
    bool verifyEveryDaysIsExplicit = false,
    LocalDate? lastVerifiedAt,
    DateSource dateSource = DateSource.userEstimated,
    LocalDate? snoozedUntil,
    ItemState state = ItemState.active,
    PurchaseChannel purchaseChannel = PurchaseChannel.unknown,
    LocalDate? trialStart,
    String? paymentSourceId,
    bool paused = false,
    YearlyChoice yearlyChoice = YearlyChoice.undecided,
  }) => TrackedItem(
    id: id,
    name: name,
    categoryId: category.id,
    iconName: iconName,
    expiresOn: expiresOn,
    actByOffsetDays: actByOffsetDays,
    anchorDate: anchorDate,
    cycle: cycle,
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: currency,
    actionUrl: actionUrl,
    actionLabel: actionLabel,
    note: note,
    leadDays: leadDays ?? category.leadDays,
    remindAt: remindAt,
    nagAfterDue: nagAfterDue ?? category.nag,
    // Dart cannot express "default to null" and "default to the shelf's value"
    // in one optional parameter, so an explicit null is passed as a flag
    // instead of being mistaken for "not said".
    verifyEveryDays: verifyEveryDaysIsExplicit
        ? verifyEveryDays
        : (verifyEveryDays ?? category.verifyEveryDays),
    lastVerifiedAt: lastVerifiedAt,
    dateSource: dateSource,
    snoozedUntil: snoozedUntil,
    state: state,
    purchaseChannel: purchaseChannel,
    trialStart: trialStart,
    paymentSourceId: paymentSourceId,
    paused: paused,
    yearlyChoice: yearlyChoice,
  );

  Money? get money => (amountMinor != null && currency != null)
      ? Money(amountMinor!, currency!)
      : null;

  /// The date reminders anchor on. Earlier than expiry whenever acting takes
  /// lead time.
  LocalDate get actBy => Recurrence.actBy(expiresOn, actByOffsetDays);

  /// In a free trial right now.
  bool get isTrial => trialStart != null;

  /// How many free days the trial runs for, or null when it is not a trial.
  int? get trialLengthDays => trialStart?.daysUntil(expiresOn);

  /// Whether this belongs in a spend total, given the shelf it sits on.
  ///
  /// Takes the shelf because the answer is not a property of the item alone: a
  /// passport fee is real money that must not land in a monthly subscription
  /// total, and only the shelf says so.
  ///
  /// A trial is excluded for the same reason from the other direction: the
  /// amount on it is what the user *will* pay, and putting a figure nobody has
  /// been charged into "this month" makes the total answer a different
  /// question. The trial is reported separately, as "not counted yet".
  bool countsTowardSpend(Category category) =>
      money != null && category.countsTowardSpend && !isTrial;

  /// Whether reminders should be scheduled and whether the item belongs on
  /// Upcoming. The one predicate for both, so the list and the notifications
  /// can never disagree about what the user turned off.
  bool get isLive => !paused && state != ItemState.archived;

  TrackedItem copyWith({
    String? id,
    String? name,
    String? categoryId,
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
    PurchaseChannel? purchaseChannel,
    LocalDate? Function()? trialStart,
    String? Function()? paymentSourceId,
    bool? paused,
    YearlyChoice? yearlyChoice,
  }) {
    return TrackedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
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
      lastVerifiedAt: lastVerifiedAt != null
          ? lastVerifiedAt()
          : this.lastVerifiedAt,
      dateSource: dateSource ?? this.dateSource,
      snoozedUntil: snoozedUntil != null ? snoozedUntil() : this.snoozedUntil,
      state: state ?? this.state,
      purchaseChannel: purchaseChannel ?? this.purchaseChannel,
      trialStart: trialStart != null ? trialStart() : this.trialStart,
      paymentSourceId: paymentSourceId != null
          ? paymentSourceId()
          : this.paymentSourceId,
      paused: paused ?? this.paused,
      yearlyChoice: yearlyChoice ?? this.yearlyChoice,
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
