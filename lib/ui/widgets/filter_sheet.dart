import 'package:flutter/material.dart';

import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/filter_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/source_mark.dart';
import 'package:subdock/i18n.dart';

/// The sheet that narrows the Upcoming list.
///
/// **There is no Apply button.** Every tap changes the list behind the sheet
/// immediately, and the button at the bottom only closes it. That is the whole
/// interaction design: a filter sheet with an Apply step makes the user commit
/// to a guess about what five chips will do, and the answer is right there
/// under the sheet if the chips are allowed to act.
///
/// The button still earns its place by *counting* — `Show 5 items` says what
/// closing will reveal, which is the one thing the sheet is covering up.
class FilterSheet extends StatefulWidget {
  final UpcomingFilter filter;
  final FilterOptions options;

  /// How many items a given filter leaves. Asked on every rebuild rather than
  /// handed in as a number, because the sheet's own taps change the answer.
  final int Function(UpcomingFilter) countFor;

  /// Called on every tap, not on close. See the class comment.
  final ValueChanged<UpcomingFilter> onChanged;

  const FilterSheet({
    super.key,
    required this.filter,
    required this.options,
    required this.countFor,
    required this.onChanged,
  });

  /// The overlay behind the sheet — `rgba(20,22,26,.36)`.
  static Color get scrim => SubdockColors.scrim;

  /// How much of the screen the sheet may take before it starts scrolling.
  static const double maxHeightFraction = 0.78;

  static Future<void> show(
    BuildContext context, {
    required UpcomingFilter filter,
    required FilterOptions options,
    required int Function(UpcomingFilter) countFor,
    required ValueChanged<UpcomingFilter> onChanged,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0x00000000),
    barrierColor: scrim,
    // Tapping the gap above the sheet closes it, which is the same "I am done
    // looking" as the button. Nothing here is a commitment that needs
    // confirming — the taps already landed.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
    ),
    builder: (sheet) => FilterSheet(
      filter: filter,
      options: options,
      countFor: countFor,
      onChanged: onChanged,
    ),
  );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late UpcomingFilter _filter = widget.filter;

  void _set(UpcomingFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    final options = widget.options;
    final shown = widget.countFor(_filter);

    return BlurLayer(
      sigma: 22,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SubdockRadius.sheet),
      ),
      child: Container(
        decoration: SubdockSurface.sheet(),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SubdockColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _Header(
                  active: _filter.isNotEmpty,
                  // Clear leaves the sheet open. The user came here to pick,
                  // and closing on a clear would make starting over cost two
                  // extra taps.
                  onClear: () => _set(UpcomingFilter.none),
                ),
                if (options.categories.isNotEmpty)
                  _Group(
                    title: S.t.filterType,
                    children: [
                      for (final option in options.categories)
                        ChoiceChipPill(
                          option.label,
                          selected: _filter.categoryIds.contains(option.key),
                          onTap: () => _set(_filter.toggleCategory(option.key)),
                        ),
                    ],
                  ),
                if (options.cycles.isNotEmpty)
                  _Group(
                    title: S.t.filterBillingCycle,
                    children: [
                      for (final option in options.cycles)
                        ChoiceChipPill(
                          option.label,
                          selected: _filter.cycleKeys.contains(option.key),
                          onTap: () => _set(_filter.toggleCycle(option.key)),
                        ),
                    ],
                  ),
                _Group(
                  title: S.t.filterPaysFrom,
                  children: [
                    for (final option in options.sources)
                      ChoiceChipPill(
                        option.label,
                        selected: _filter.sourceIds.contains(option.key),
                        icon: _sourceIcon(option),
                        onTap: () => _set(_filter.toggleSource(option.key)),
                      ),
                  ],
                ),
                _Group(
                  title: S.t.filterOnlyShow,
                  children: [
                    ChoiceChipPill(
                      S.t.freeTrials,
                      selected: _filter.trialOnly,
                      onTap: () =>
                          _set(_filter.withTrialOnly(!_filter.trialOnly)),
                    ),
                    ChoiceChipPill(
                      S.t.filterNoPrice,
                      selected: _filter.noPriceOnly,
                      onTap: () =>
                          _set(_filter.withNoPriceOnly(!_filter.noPriceOnly)),
                    ),
                    ChoiceChipPill(
                      // Says what the items are, not what the chip does to the
                      // pool. That it *widens* rather than narrows is a fact
                      // about the implementation; what the user asked for is
                      // "the ones I switched off".
                      S.t.filterRemindersOff,
                      selected: _filter.mutedOnly,
                      onTap: () =>
                          _set(_filter.withMutedOnly(!_filter.mutedOnly)),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                PrimaryButton(
                  _filter.isEmpty ? S.t.done : S.t.filterShow(shown),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A struck-through circle for "No source", the source's own mark otherwise.
  ///
  /// Only this group carries icons, and only because the labels in it are
  /// nicknames the user wrote: "VCB 4412" and "Momo" are not words, and the
  /// glyph is what makes the row read as a list of ways to pay.
  static Widget? _sourceIcon(FilterOption option) {
    if (option.isAbsence) return const Icon(Icons.block_rounded);
    final glyph = option.glyph;
    return glyph == null ? null : Icon(SourceMark.iconFor(glyph));
  }
}

/// `Filter` on the left, `Clear all` on the right.
class _Header extends StatelessWidget {
  final bool active;
  final VoidCallback onClear;

  const _Header({required this.active, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            S.t.filterTitle,
            style: SubdockText.detailTitle.copyWith(fontSize: 25),
          ),
        ),
        // Dimmed rather than hidden when nothing is on. A control that appears
        // only once there is something to clear moves the header's layout the
        // moment the first chip is tapped.
        InkWell(
          onTap: active ? onClear : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              S.t.filterClearAll,
              style: TextStyle(
                fontFamily: SubdockText.family,
                fontSize: 15,
                height: 1,
                fontWeight: SubdockWeight.medium,
                color: active ? SubdockColors.accent : SubdockColors.inkMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// An uppercase heading with a wrapping block of chips under it.
///
/// A wrap, not a [ChipRail]. The rail exists for rows whose options are a
/// short fixed set the user pushes sideways through; these lists are as long
/// as the user's own data, and a chip half off the right edge of a sheet has
/// nothing beside it to say the row keeps going.
class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(title.toUpperCase(), style: SubdockText.sectionLabel),
        const SizedBox(height: 10),
        Wrap(spacing: 9, runSpacing: 9, children: children),
      ],
    );
  }
}
