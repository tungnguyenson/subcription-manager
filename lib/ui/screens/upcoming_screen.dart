import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/empty_placard.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// A row's presentation, already resolved from the domain. The screen renders
/// what it is handed and computes nothing, so the wording of "4 days" stays
/// testable without a widget test.
class UpcomingEntry {
  final String id;
  final String when;
  final String date;
  final String name;
  final String? subtitle;

  /// Which card or account pays for it, or null when the user has not said.
  final String? sourceName;

  final String? iconName;
  final bool overdue;

  /// In a free trial: nothing has been charged yet, and cancelling before
  /// [date] is free.
  final bool trial;

  const UpcomingEntry({
    required this.id,
    required this.when,
    required this.date,
    required this.name,
    this.subtitle,
    this.sourceName,
    this.iconName,
    this.overdue = false,
    this.trial = false,
  });
}

class UpcomingScreen extends StatefulWidget {
  final UpcomingView view;

  /// Shown above the list when something needs the user before the list does.
  final Widget? banner;

  final void Function(UpcomingEntry entry)? onOpen;
  final VoidCallback? onAdd;

  /// Opens the service list, from the link on the title row. That link is the
  /// only trace on this screen of what it does not show -- switched-off
  /// services, and anything past the horizon.
  final VoidCallback? onOpenServices;

  /// Opens the filter sheet.
  final VoidCallback? onOpenFilter;

  /// Drops every condition at once, from the summary row and from the empty
  /// state. Both need it: by the time the list is empty the summary row is the
  /// only thing left on screen that explains why.
  final VoidCallback? onClearFilter;

  /// `3 of 12 items · Streaming · Monthly`, or null when nothing is filtered.
  ///
  /// Built by [FilterPresenter] rather than here, because naming a category
  /// takes the shelf list and naming a source takes the source list, and this
  /// screen has neither.
  final String? filterSummary;

  const UpcomingScreen({
    super.key,
    required this.view,
    this.banner,
    this.onOpen,
    this.onAdd,
    this.onOpenServices,
    this.onOpenFilter,
    this.onClearFilter,
    this.filterSummary,
  });

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  @override
  Widget build(BuildContext context) {
    final view = widget.view;

    // Nothing tracked at all is not a short list, it is a different screen.
    // Built as a column rather than a one-item list so the placard can sit in
    // the middle of what is left instead of clinging to the title.
    //
    // An empty list *while filtering* is a third thing again, and it goes
    // below rather than here: "Nothing tracked yet" beside an offer to add an
    // item is a lie when the user has twelve items and four chips on.
    if (view.isEmpty && !view.filtering) {
      return Padding(
        padding: SubdockSpacing.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleRow(
              onOpenServices: widget.onOpenServices,
              onOpenFilter: widget.onOpenFilter,
            ),
            if (widget.banner != null) ...[
              const SizedBox(height: 18),
              widget.banner!,
            ],
            Expanded(
              child: Center(child: _EmptyState(onAdd: widget.onAdd)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        _TitleRow(
          onOpenServices: widget.onOpenServices,
          onOpenFilter: widget.onOpenFilter,
          filtering: view.filtering,
        ),
        if (view.filtering && widget.filterSummary != null)
          _FilterSummary(
            text: widget.filterSummary!,
            onClear: widget.onClearFilter,
          ),
        if (widget.banner != null) ...[
          const SizedBox(height: 18),
          widget.banner!,
        ],
        if (view.noMatches)
          Padding(
            padding: const EdgeInsets.only(top: SubdockSpacing.sectionTop),
            child: _NoMatches(
              summary: widget.filterSummary,
              onClear: widget.onClearFilter,
            ),
          ),
        if (view.overdue.isNotEmpty)
          _Section(
            title: 'Overdue',
            count: view.overdue.length,
            tint: SubdockColors.danger,
            entries: view.overdue,
            onOpen: widget.onOpen,
          ),
        if (view.trials.isNotEmpty)
          _Section(
            // Says what the section *means*, not what is in it. "Trials" is a
            // category; this is a promise — nothing here has taken money yet.
            title: 'Free trial · not charged yet',
            count: view.trials.length,
            tint: SubdockColors.accent,
            entries: view.trials,
            onOpen: widget.onOpen,
          ),
        if (view.thisWeek.isNotEmpty)
          _Section(
            title: 'Next 7 days',
            count: view.thisWeek.length,
            entries: view.thisWeek,
            onOpen: widget.onOpen,
          ),
        // The same section as the three above it, not a folded summary row.
        // A bucket that arrives closed hides items behind a tap the user has
        // no reason to expect, and the hand-off draws every group on this
        // screen open. Anything further out is further down the scroll, which
        // is the only ranking this list needs.
        if (view.thisMonth.isNotEmpty)
          _Section(
            title: 'Next 30 days',
            count: view.thisMonth.length,
            entries: view.thisMonth,
            onOpen: widget.onOpen,
          ),
        if (view.later.isNotEmpty)
          _Section(
            title: 'Later',
            count: view.later.length,
            entries: view.later,
            onOpen: widget.onOpen,
          ),
      ],
    );
  }
}

/// The title, and the way to the full service list.
///
/// The link is on the title row rather than buried in Settings because Upcoming
/// deliberately does not show everything: a paused service, and anything past
/// the horizon, is not on this screen. Somewhere on it has to say where the
/// rest went.
class _TitleRow extends StatelessWidget {
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenFilter;
  final bool filtering;

  const _TitleRow({
    this.onOpenServices,
    this.onOpenFilter,
    this.filtering = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(child: Text('Upcoming', style: SubdockText.screenTitle)),
        // The two actions sit in a row of their own, centred against each
        // other, and only that row is baselined against the title. The filter
        // button is a circle with no text in it and so has no baseline to
        // offer; left in the outer row it would hang off the top of the line.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpenFilter != null) ...[
              _FilterButton(active: filtering, onTap: onOpenFilter),
              const SizedBox(width: 8),
            ],
            if (onOpenServices != null)
              InkWell(
                onTap: onOpenServices,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.apps_rounded,
                        size: 18,
                        color: SubdockColors.accent,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'All services',
                        style: TextStyle(
                          fontFamily: SubdockText.family,
                          fontSize: 15,
                          height: 1,
                          fontWeight: SubdockWeight.medium,
                          color: SubdockColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The round button that opens the filter sheet.
///
/// Filled with the accent while anything is on, outlined while nothing is.
/// That is the whole state readout on the header: a filter that is on has to
/// be visible from the list, because a list that is quietly short is
/// indistinguishable from an app that has lost things -- the same reason
/// Upcoming stopped hiding switched-off items without saying so.
///
/// The summary row underneath says *what* is on. This says *that* something
/// is, and survives the summary row scrolling away.
class _FilterButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;

  const _FilterButton({required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: active ? SubdockColors.accent : const Color(0x00000000),
        shape: BoxShape.circle,
        border: active ? null : Border.all(color: SubdockColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Icon(
            Icons.filter_list_rounded,
            size: 19,
            color: active ? const Color(0xFFFFFFFF) : SubdockColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// `3 of 12 items · Streaming · Monthly`, with a way out of it.
///
/// One line, ellipsised. It is a reminder of a state the user put themselves
/// in, not a report -- the sheet is one tap away and holds the full answer.
class _FilterSummary extends StatelessWidget {
  final String text;
  final VoidCallback? onClear;

  const _FilterSummary({required this.text, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SubdockText.summary.copyWith(
                fontSize: 14.5,
                color: SubdockColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (onClear != null)
            InkWell(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 14.5,
                    height: 1,
                    fontWeight: SubdockWeight.medium,
                    color: SubdockColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The filter left nothing.
///
/// A card rather than the centred placard [_EmptyState] uses, and that is the
/// point: the placard means "this app has nothing in it", and this means "these
/// four chips have nothing in them". Same emptiness, opposite cause, and the
/// only useful action is the opposite too -- undo, not add.
class _NoMatches extends StatelessWidget {
  final String? summary;
  final VoidCallback? onClear;

  const _NoMatches({this.summary, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.card(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nothing matches these filters',
            style: TextStyle(
              fontFamily: SubdockText.family,
              fontSize: 17,
              height: 1.3,
              fontWeight: SubdockWeight.semibold,
              letterSpacing: -0.17,
              color: SubdockColors.ink,
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text(summary!, style: SubdockText.footnote),
          ],
          const SizedBox(height: 16),
          IntrinsicWidth(
            child: PrimaryButton('Clear filters', onPressed: onClear),
          ),
        ],
      ),
    );
  }
}

/// A heading, then one card per row with a gap between them.
///
/// Not a single [GroupedCard] with hairlines. An overdue row carries the danger
/// edge and the rows around it do not, and one shared card can only have one
/// edge — which would leave text colour as the only signal for overdue.
class _Section extends StatelessWidget {
  final String title;
  final int count;
  final Color? tint;
  final List<UpcomingEntry> entries;
  final void Function(UpcomingEntry)? onOpen;

  const _Section({
    required this.title,
    required this.count,
    required this.entries,
    this.tint,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final label = tint == null
        ? SubdockText.sectionLabel
        : SubdockText.sectionLabel.copyWith(color: tint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: SubdockSpacing.sectionTop,
            bottom: SubdockSpacing.sectionBottom,
          ),
          child: Text.rich(
            TextSpan(
              text: title.toUpperCase(),
              style: label,
              children: [
                // The count in the heading, at 60% of the heading's own colour.
                // It answers "how many" without a second row, and dimming it is
                // what stops a two-digit number outranking the word beside it.
                TextSpan(
                  text: '  $count',
                  style: label.copyWith(
                    color: label.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: SubdockSpacing.rowGap),
          ItemRow(
            name: entries[i].name,
            iconName: entries[i].iconName,
            subtitle: entries[i].subtitle,
            sourceName: entries[i].sourceName,
            when: entries[i].when,
            date: entries[i].date,
            overdue: entries[i].overdue,
            trial: entries[i].trial,
            onTap: () => onOpen?.call(entries[i]),
          ),
        ],
      ],
    );
  }
}

/// Nothing tracked at all.
///
/// Distinct from "nothing due soon", which the sections above already say by
/// being absent. An empty list in a reminder app is ambiguous — it could mean
/// nothing is due, or that the app has stopped working — so this one says
/// outright that there is nothing in it yet, and offers the only useful action.
class _EmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyState({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyPlacard(),
          const SizedBox(height: 20),
          const Text(
            'Nothing tracked yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SubdockText.family,
              fontSize: 15,
              height: 1.4,
              fontWeight: SubdockWeight.semibold,
              letterSpacing: -0.15,
              color: SubdockColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add the first date you keep forgetting.',
            textAlign: TextAlign.center,
            style: SubdockText.summary,
          ),
          const SizedBox(height: 16),
          IntrinsicWidth(child: PrimaryButton('Add an item', onPressed: onAdd)),
        ],
      ),
    );
  }
}

/// Formats the left column of a row. Kept here beside the screen it serves,
/// and pure so the wording can be tested directly.
abstract final class UpcomingCopy {
  /// The countdown, abbreviated the way the Glass design abbreviates it: a
  /// number and a `d`, with today and tomorrow spelled out because they are the
  /// two the reader acts on rather than compares.
  ///
  /// Abbreviated, never rounded. "About a month" on something due in 29 days is
  /// the single most common one-star complaint in this category, and it is
  /// always the app that was trying to be reassuring. `29d` is the same exact
  /// number in fewer glyphs, which is what keeps this column narrow enough to
  /// scan straight down.
  /// [trial] replaces the countdown with `Trial ends`, which is what the
  /// hand-off draws in that column. The swap is worth the width: `2d` on a
  /// trial row says "two days until something happens" and leaves the reader
  /// to work out that the something is a first charge. The date underneath is
  /// unchanged, so nothing exact is lost.
  /// The countdown column: how long, in the fewest characters that say it.
  ///
  /// A trial gets the same countdown as anything else. It used to read `Trial
  /// ends`, which said *what* rather than *when* — and now that the row carries
  /// a `FREE TRIAL` badge beside the name, the what is already said. Two words
  /// in this column also cost the name most of its width: `Claude Pro` came out
  /// as `Claude …` beside them.
  static String when(LocalDate actBy, LocalDate today) {
    final days = today.daysUntil(actBy);
    if (days < 0) return 'Late';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '${days}d';
  }

  static String overdueDetail(LocalDate actBy, LocalDate today) {
    final days = actBy.daysUntil(today);
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  /// Day-first, which is how dates are written in Vietnam. Using the device
  /// locale here would show an American reader 08/17 for a date a Vietnamese
  /// user typed as 17/08, and the two are indistinguishable on screen.
  static String shortDate(LocalDate date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
