import 'package:meta/meta.dart';

import 'local_date.dart';
import 'model.dart';

/// What the user has narrowed the Upcoming list down to.
///
/// A value rather than a bag of booleans on the screen, because three separate
/// places have to agree on it: the list, the sheet that edits it, and the row
/// that stores it between sessions. Each group is a set of keys and an empty
/// set means "no constraint" -- never "match nothing", which is what makes the
/// default value and the cleared value the same object.
///
/// Within a group the keys are OR-ed, and the groups are AND-ed. That is the
/// only combination that behaves the way a reader expects: picking a second
/// category widens, picking a payment source on top of it narrows.
@immutable
class UpcomingFilter {
  /// [Category.id]s. An item matches if its shelf is one of these.
  final Set<String> categoryIds;

  /// [CycleWire.wireName]s, plus [onceKey] for an item that happens once.
  ///
  /// The wire name rather than the [Cycle] itself so the set can be written to
  /// a settings row and read back without a second encoding.
  final Set<String> cycleKeys;

  /// [PaymentSource.id]s, plus [noSourceKey] for an item that has not been
  /// told where it is paid from.
  final Set<String> sourceIds;

  /// Only items in a free trial.
  final bool trialOnly;

  /// Only items with no amount on them. The point of the chip is finding the
  /// rows that are missing one, so it can be filled in.
  final bool noPriceOnly;

  /// The one condition that does not narrow the list.
  ///
  /// Everything else here is a predicate over the items Upcoming already
  /// shows. This one swaps the pool: Upcoming hides switched-off items
  /// entirely, so a predicate could never reach them, and "show me the ones I
  /// muted" is exactly the question that cannot be asked any other way.
  final bool mutedOnly;

  /// The key standing for "no payment source said", which is a real answer and
  /// so needs a chip of its own. Leading underscore so it cannot collide with
  /// a generated [PaymentSource.id].
  static const String noSourceKey = '_none';

  /// The key standing for a one-off. Not a [Cycle], so it has no wire name of
  /// its own; `ONCE` is not one of the five preset names or the `EVERY_n_UNIT`
  /// shape, so it cannot collide with one.
  static const String onceKey = 'ONCE';

  const UpcomingFilter({
    this.categoryIds = const {},
    this.cycleKeys = const {},
    this.sourceIds = const {},
    this.trialOnly = false,
    this.noPriceOnly = false,
    this.mutedOnly = false,
  });

  /// Nothing selected: the list shows what it shows without a filter.
  static const UpcomingFilter none = UpcomingFilter();

  /// How many conditions are on, counting each selected chip separately.
  ///
  /// This is what the sheet's button and the summary line count, and it is
  /// deliberately per-chip rather than per-group: the user picked five chips
  /// and the app should not tell them they picked three things.
  int get count =>
      categoryIds.length +
      cycleKeys.length +
      sourceIds.length +
      (trialOnly ? 1 : 0) +
      (noPriceOnly ? 1 : 0) +
      (mutedOnly ? 1 : 0);

  bool get isEmpty => count == 0;
  bool get isNotEmpty => count > 0;

  /// The key for [item]'s cycle, matching what [cycleKeys] holds.
  static String cycleKeyOf(TrackedItem item) => item.cycle?.wireName ?? onceKey;

  /// The key for [item]'s payment source, matching what [sourceIds] holds.
  static String sourceKeyOf(TrackedItem item) =>
      item.paymentSourceId ?? noSourceKey;

  /// The items this filter draws from, before any of its predicates run.
  ///
  /// Inactive items are gone from both branches: being finished is not being
  /// muted, and nothing on Upcoming brings an inactive item back.
  List<TrackedItem> pool(List<TrackedItem> items) => mutedOnly
      ? items.where((i) => i.paused && i.state != ItemState.inactive).toList()
      : items.where((i) => i.isLive).toList();

  /// Whether [item] survives the narrowing conditions.
  ///
  /// [mutedOnly] is not asked here — it has already decided which items were
  /// handed in. See its own doc comment.
  ///
  /// Takes the date for one condition: a free trial stops being one the day
  /// the charge lands, so `Free trials` has to be asked against a day rather
  /// than against the item alone.
  bool matches(TrackedItem item, LocalDate today) {
    if (categoryIds.isNotEmpty && !categoryIds.contains(item.categoryId)) {
      return false;
    }
    if (cycleKeys.isNotEmpty && !cycleKeys.contains(cycleKeyOf(item))) {
      return false;
    }
    if (sourceIds.isNotEmpty && !sourceIds.contains(sourceKeyOf(item))) {
      return false;
    }
    if (trialOnly && !item.isTrialOn(today)) return false;
    if (noPriceOnly && item.money != null) return false;
    return true;
  }

  /// [pool] and [matches] in one pass, which is what every caller wants.
  List<TrackedItem> apply(List<TrackedItem> items, LocalDate today) =>
      pool(items).where((i) => matches(i, today)).toList();

  UpcomingFilter toggleCategory(String id) =>
      _copy(categoryIds: _toggled(categoryIds, id));

  UpcomingFilter toggleCycle(String key) =>
      _copy(cycleKeys: _toggled(cycleKeys, key));

  UpcomingFilter toggleSource(String id) =>
      _copy(sourceIds: _toggled(sourceIds, id));

  UpcomingFilter withTrialOnly(bool on) => _copy(trialOnly: on);
  UpcomingFilter withNoPriceOnly(bool on) => _copy(noPriceOnly: on);
  UpcomingFilter withMutedOnly(bool on) => _copy(mutedOnly: on);

  /// The same filter with any payment source that no longer exists dropped.
  ///
  /// A source deleted in Settings leaves its id behind in a stored filter, and
  /// an id nothing can match turns the list permanently empty with no chip on
  /// screen to explain why -- the sheet builds its chips from sources that
  /// exist, so the offending one is not even drawn.
  UpcomingFilter prunedTo(Set<String> knownSourceIds) {
    final kept = sourceIds
        .where((id) => id == noSourceKey || knownSourceIds.contains(id))
        .toSet();
    if (kept.length == sourceIds.length) return this;
    return _copy(sourceIds: kept);
  }

  static Set<String> _toggled(Set<String> set, String key) {
    final next = {...set};
    if (!next.remove(key)) next.add(key);
    return next;
  }

  UpcomingFilter _copy({
    Set<String>? categoryIds,
    Set<String>? cycleKeys,
    Set<String>? sourceIds,
    bool? trialOnly,
    bool? noPriceOnly,
    bool? mutedOnly,
  }) => UpcomingFilter(
    categoryIds: categoryIds ?? this.categoryIds,
    cycleKeys: cycleKeys ?? this.cycleKeys,
    sourceIds: sourceIds ?? this.sourceIds,
    trialOnly: trialOnly ?? this.trialOnly,
    noPriceOnly: noPriceOnly ?? this.noPriceOnly,
    mutedOnly: mutedOnly ?? this.mutedOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is UpcomingFilter &&
      other.trialOnly == trialOnly &&
      other.noPriceOnly == noPriceOnly &&
      other.mutedOnly == mutedOnly &&
      _sameSet(other.categoryIds, categoryIds) &&
      _sameSet(other.cycleKeys, cycleKeys) &&
      _sameSet(other.sourceIds, sourceIds);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
    trialOnly,
    noPriceOnly,
    mutedOnly,
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(cycleKeys),
    Object.hashAllUnordered(sourceIds),
  );
}
