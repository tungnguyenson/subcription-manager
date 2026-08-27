import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/i18n.dart';

/// One chip in the filter sheet: the key it toggles, and the word on it.
class FilterOption {
  final String key;
  final String label;

  /// Only the payment-source chips carry one, the same way the source picker
  /// in the add form does: the labels there are user-written nicknames and the
  /// glyph is what says the row is about money.
  final SourceGlyph? glyph;

  /// True for the "No source" chip, which stands for an absence rather than
  /// for a thing the user made. The sheet draws it with a struck-through mark.
  final bool isAbsence;

  const FilterOption({
    required this.key,
    required this.label,
    this.glyph,
    this.isAbsence = false,
  });
}

/// The chips the sheet offers, for one particular set of items.
class FilterOptions {
  final List<FilterOption> categories;
  final List<FilterOption> cycles;
  final List<FilterOption> sources;

  const FilterOptions({
    this.categories = const [],
    this.cycles = const [],
    this.sources = const [],
  });

  /// Every label the sheet can draw, by key, so a summary line can name a
  /// selected chip without searching three lists.
  Map<String, String> get labels => {
    for (final option in [...categories, ...cycles, ...sources])
      option.key: option.label,
  };
}

/// Builds the filter sheet's chips, and the line that says what is on.
///
/// Pure and separate from the sheet for the usual reason: which chips exist is
/// a question about the user's data, and the wording of the summary is the part
/// worth a test. Neither needs a widget to be checked.
abstract final class FilterPresenter {
  /// The chips, built from what the user actually has.
  ///
  /// Type and Billing cycle come from the items, so a shelf nobody uses and a
  /// cycle nobody has never appear -- a chip that can only ever return nothing
  /// is a chip that wasted a tap.
  ///
  /// [items] is every non-archived item, muted ones included, and not the pool
  /// the filter is currently drawing from. Turning "Reminders off" on would
  /// otherwise rebuild the chip rows underneath the user's finger, and half the
  /// chips they had already picked would vanish from the sheet while staying
  /// on in the filter.
  ///
  /// Payment sources are the exception: they are listed in full whether or not
  /// anything is paid from them, because that list is short, the user wrote it
  /// themselves, and "nothing is on this card" is a useful answer to get.
  static FilterOptions options(
    List<TrackedItem> items,
    CategoryBook categories, {
    List<PaymentSource> sources = const [],
  }) {
    final live = items.where((i) => i.state != ItemState.archived).toList();

    final usedCategories = <String>{for (final item in live) item.categoryId};
    final shelves =
        categories.all.where((c) => usedCategories.contains(c.id)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final usedCycles = <String, Cycle?>{
      for (final item in live) UpcomingFilter.cycleKeyOf(item): item.cycle,
    };
    final cycleKeys = usedCycles.keys.toList()
      ..sort(
        (a, b) =>
            _cycleRank(usedCycles[a]).compareTo(_cycleRank(usedCycles[b])),
      );

    return FilterOptions(
      categories: [
        for (final shelf in shelves)
          FilterOption(key: shelf.id, label: shelf.label),
      ],
      cycles: [
        for (final key in cycleKeys)
          FilterOption(
            key: key,
            label: ItemPresenter.cycleLabel(usedCycles[key]),
          ),
      ],
      sources: [
        for (final source in sources)
          FilterOption(key: source.id, label: source.name, glyph: source.glyph),
        // Last, and always present. An item with no source said is the normal
        // state of a freshly added row, so this chip is never the empty one.
        FilterOption(
          key: UpcomingFilter.noSourceKey,
          label: S.t.filterNoSource,
          isAbsence: true,
        ),
      ],
    );
  }

  /// A one-off sorts last. It is not a long interval, it is the absence of one,
  /// and putting it between "Yearly" and nothing would suggest otherwise.
  static int _cycleRank(Cycle? cycle) {
    if (cycle == null) return 1 << 30;
    return switch (cycle.unit) {
      CycleUnit.day => cycle.step,
      // Not a calendar month, just a scale that orders the two units against
      // each other. Nothing downstream reads this number.
      CycleUnit.month => cycle.step * 30,
    };
  }

  /// The line under the title while the list is narrowed:
  /// `3 of 12 items · Streaming · Monthly`.
  ///
  /// The counts come first because they are the part that answers "what am I
  /// not seeing". The conditions follow in the order the sheet lists them, so
  /// the line and the sheet can be read against each other.
  ///
  /// A group with three or more chips on is compressed to `3 types` rather than
  /// spelled out. The row is one line with an ellipsis, and three names spelled
  /// out push the count off the end of it -- which loses the only part the
  /// reader cannot get by opening the sheet.
  static String summary(
    UpcomingFilter filter,
    FilterOptions options, {
    required int shown,
    required int total,
  }) {
    final labels = options.labels;
    final parts = <String>[
      S.t.filterCount(shown, total),
      ..._group(filter.categoryIds, labels, S.t.filterTypes),
      ..._group(filter.cycleKeys, labels, S.t.filterCycles),
      ..._group(filter.sourceIds, labels, S.t.filterSources),
      if (filter.trialOnly) S.t.freeTrials,
      if (filter.noPriceOnly) S.t.filterNoPrice,
      if (filter.mutedOnly) S.t.filterRemindersOff,
    ];
    return parts.join(S.t.bullet);
  }

  /// The chips of one group, named or counted.
  ///
  /// A key with no chip behind it is dropped rather than named: it is a shelf
  /// or a source that has gone away since the filter was stored, and the list
  /// on screen is already behaving as though it were not there.
  static List<String> _group(
    Set<String> keys,
    Map<String, String> labels,
    String Function(int count) counted,
  ) {
    // In the order the sheet draws them, not the order the set iterates.
    final named = labels.keys.where(keys.contains).toList();
    if (named.isEmpty) return const [];
    if (named.length > 2) return [counted(named.length)];
    return [for (final key in named) labels[key]!];
  }
}
