import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/calendar_presenter.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/empty_placard.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/month_grid.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The two ways Upcoming draws the same items.
///
/// Two layouts of one list, not two lists: every condition the filter holds
/// applies to both, and an item hidden from one is hidden from the other. The
/// list answers "what is next"; the calendar answers "what does August look
/// like", which is the question a list ordered by distance cannot answer.
enum UpcomingMode { list, calendar }

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

  /// Cancelled, and still on the list because the paid-up period has not run
  /// out. Nothing about the row says so otherwise: the reminders are gone but
  /// silence is what an item with none looks like anyway, so without this the
  /// row is indistinguishable from one that is still running.
  final bool cancelled;

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
    this.cancelled = false,
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

  /// Which layout is drawn. See [UpcomingMode].
  final UpcomingMode mode;

  final ValueChanged<UpcomingMode>? onMode;

  /// The month grid, built only while [mode] is [UpcomingMode.calendar].
  final CalendarView? calendar;

  /// A different month, as `(year, month)`.
  final void Function((int, int) month)? onMonth;

  final ValueChanged<LocalDate>? onSelectDay;

  /// Turns the `Free trials` condition on and off from the header.
  ///
  /// The same condition the filter sheet holds, not a second one: a trial that
  /// is filtered out by the sheet cannot be filtered back in from here.
  final bool trialOnly;
  final VoidCallback? onToggleTrial;

  /// How the three lists on this screen separate their rows. See
  /// [ItemRowStyle]; the default is a rule under each row.
  final ItemRowStyle rowStyle;

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
    this.mode = UpcomingMode.list,
    this.onMode,
    this.calendar,
    this.onMonth,
    this.onSelectDay,
    this.trialOnly = false,
    this.onToggleTrial,
    this.rowStyle = ItemRowStyle.dividers,
  });

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
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
            _TitleRow(onOpenServices: widget.onOpenServices),
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
        _TitleRow(onOpenServices: widget.onOpenServices),
        _ControlRow(
          mode: widget.mode,
          onMode: widget.onMode,
          trials: view.trials,
          trialOnly: widget.trialOnly,
          onToggleTrial: widget.onToggleTrial,
          filtering: view.filtering,
          onOpenFilter: widget.onOpenFilter,
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
        // Neither layout is drawn once the filter has emptied the list: an
        // empty grid under a line explaining why the list is empty says the
        // same thing twice, and the second time in a shape that looks broken.
        if (!view.noMatches)
          ...switch (widget.mode) {
            UpcomingMode.list => _sections(view),
            UpcomingMode.calendar => _month(),
          },
      ],
    );
  }

  /// The dated groups: the list layout.
  List<Widget> _sections(UpcomingView view) => [
    if (view.overdue.isNotEmpty)
      _Section(
        title: S.t.bucketOverdue,
        count: view.overdue.length,
        tint: SubdockColors.danger,
        entries: view.overdue,
        onOpen: widget.onOpen,
        rowStyle: widget.rowStyle,
      ),
    // No section of its own for trials. One used to sit here, above the
    // dated groups, and it cost the trial row the only thing this screen
    // ranks by: a charge two days out and one two months out shared a
    // block, while the item due tomorrow was read past on the way to them.
    // The `FREE TRIAL` badge beside the name says the same thing from
    // wherever the date puts the row, and the header chip is what gathers
    // them when that is what the reader wants.
    if (view.thisWeek.isNotEmpty)
      _Section(
        title: S.t.bucketNext7,
        count: view.thisWeek.length,
        entries: view.thisWeek,
        onOpen: widget.onOpen,
        rowStyle: widget.rowStyle,
      ),
    // The same section as the three above it, not a folded summary row.
    // A bucket that arrives closed hides items behind a tap the user has
    // no reason to expect, and the hand-off draws every group on this
    // screen open. Anything further out is further down the scroll, which
    // is the only ranking this list needs.
    if (view.thisMonth.isNotEmpty)
      _Section(
        title: S.t.bucketNext30,
        count: view.thisMonth.length,
        entries: view.thisMonth,
        onOpen: widget.onOpen,
        rowStyle: widget.rowStyle,
      ),
    if (view.later.isNotEmpty)
      _Section(
        title: S.t.bucketLater,
        count: view.later.length,
        entries: view.later,
        onOpen: widget.onOpen,
        rowStyle: widget.rowStyle,
      ),
  ];

  /// The month grid, and the day open under it.
  ///
  /// The day's list is a section like any other, heading and all, so the two
  /// layouts read as one screen: tapping the 20th and scrolling to `Next 7
  /// days` put the same row in front of the reader in the same shape.
  List<Widget> _month() {
    final calendar = widget.calendar;
    if (calendar == null) return const [];

    return [
      const SizedBox(height: 18),
      MonthBar(
        label: calendar.monthLabel,
        onPrevious: widget.onMonth == null
            ? null
            : () => widget.onMonth!(calendar.previous),
        onNext: widget.onMonth == null
            ? null
            : () => widget.onMonth!(calendar.next),
      ),
      const SizedBox(height: 10),
      MonthGrid(view: calendar, onSelect: widget.onSelectDay),
      _Section(
        title: calendar.selectedLabel,
        count: calendar.entries.length,
        entries: calendar.entries,
        onOpen: widget.onOpen,
        rowStyle: widget.rowStyle,
        // A day with nothing on it still gets its heading. Dropping the whole
        // block would leave the reader who just tapped a date with no sign
        // that the tap landed.
        emptyLine: S.t.nothingOnThisDay,
      ),
    ];
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

  const _TitleRow({this.onOpenServices});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(S.t.upcomingTitle, style: SubdockText.screenTitle),
        ),
        // One link, and it is a link rather than a button: it leaves the
        // screen. The controls that act *on* this screen -- the layout, the
        // trial shortcut, the filter -- moved down to the row below, where
        // they sit together and read as one set.
        if (onOpenServices != null)
          InkWell(
            onTap: onOpenServices,
            child: Padding(
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
                    S.t.allServices,
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
    );
  }
}

/// The layout tray, the trial shortcut and the filter button, in one row.
///
/// Under the title rather than on it. Three controls that change what the list
/// below shows, gathered where the reader's eye lands before the first row --
/// and the title row keeps its whole width for the title, which is what stops
/// `Upcoming` competing with a tray of buttons for the same line.
class _ControlRow extends StatelessWidget {
  final UpcomingMode mode;
  final ValueChanged<UpcomingMode>? onMode;

  /// How many items are in a trial today, over the unfiltered pool.
  final int trials;
  final bool trialOnly;
  final VoidCallback? onToggleTrial;

  final bool filtering;
  final VoidCallback? onOpenFilter;

  const _ControlRow({
    required this.mode,
    this.onMode,
    this.trials = 0,
    this.trialOnly = false,
    this.onToggleTrial,
    this.filtering = false,
    this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // The tray is the one thing here that gives way, and it gives way
          // last: a loose Flexible takes its own width whenever that fits, so
          // the gap between the two halves of this row is what absorbs a wide
          // screen and the segment labels are what absorb a narrow one. A
          // Spacer here instead would split the leftover with the chip and
          // clip `Free trial` down to `Fre...` on every phone.
          Flexible(
            child: SegmentedRow(
              labels: [S.t.layoutList, S.t.layoutCalendar],
              icons: const [
                Icons.view_agenda_outlined,
                Icons.calendar_month_outlined,
              ],
              tight: true,
              selected: mode.index,
              onSelect: onMode == null
                  ? null
                  : (i) => onMode!(UpcomingMode.values[i]),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hidden at zero rather than drawn empty. `Free trial 0` is a
              // control that does nothing beside a number that says so, on a
              // header with no room to spare.
              //
              // Unless it is switched on, which is the case where the count
              // reaching zero is the chip's own doing: the last trial was
              // charged this morning. A control that vanishes while it is
              // still filtering leaves the reader looking at an empty list
              // with no visible cause.
              if (trials > 0 || trialOnly) ...[
                ChoiceChipPill(
                  S.t.freeTrials,
                  count: trials,
                  selected: trialOnly,
                  onTap: onToggleTrial,
                ),
                const SizedBox(width: 8),
              ],
              if (onOpenFilter != null)
                _FilterButton(active: filtering, onTap: onOpenFilter),
            ],
          ),
        ],
      ),
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
            color: active ? SubdockColors.onAccent : SubdockColors.inkMuted,
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
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  S.t.filterClear,
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
          Text(
            S.t.nothingMatchesFilters,
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
            child: PrimaryButton(S.t.clearFilters, onPressed: onClear),
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

  /// Drawn in place of the rows when there are none. Null means a section with
  /// nothing in it is not drawn at all, which is what the dated groups want:
  /// `Next 30 days  0` is a heading that reports on nothing.
  final String? emptyLine;

  /// Passed straight to every [ItemRow] below the heading.
  final ItemRowStyle rowStyle;

  const _Section({
    required this.title,
    required this.count,
    required this.entries,
    this.tint,
    this.onOpen,
    this.emptyLine,
    this.rowStyle = ItemRowStyle.dividers,
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
                //
                // Dropped at zero: the only heading that survives an empty
                // section is the calendar's day, and the line under it already
                // says the day is empty. `0` beside it is the same fact in a
                // shape the reader has to decode.
                if (count > 0)
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
        if (entries.isEmpty && emptyLine != null)
          Text(emptyLine!, style: SubdockText.summary),
        for (var i = 0; i < entries.length; i++) ...[
          // No gap under the divider style: the rule is the separation, and a
          // 10px moat on top of it would say it twice.
          if (i > 0 && rowStyle == ItemRowStyle.cards)
            const SizedBox(height: SubdockSpacing.rowGap),
          ItemRow(
            name: entries[i].name,
            iconName: entries[i].iconName,
            subtitle: entries[i].subtitle,
            sourceName: entries[i].sourceName,
            when: entries[i].when,
            date: entries[i].date,
            overdue: entries[i].overdue,
            trial: entries[i].trial,
            cancelled: entries[i].cancelled,
            style: rowStyle,
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
          Text(
            S.t.nothingTracked,
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
          Text(
            S.t.nothingTrackedBody,
            textAlign: TextAlign.center,
            style: SubdockText.summary,
          ),
          const SizedBox(height: 16),
          IntrinsicWidth(child: PrimaryButton(S.t.addAnItem, onPressed: onAdd)),
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
  /// Exact days for everything a reader still counts in days, which is why the
  /// switch to months waits until [_monthsFrom] whole months rather than one.
  /// "About a month" on something due in 29 days is the single most common
  /// one-star complaint in this category, and it is always the app that was
  /// trying to be reassuring; `29d` is the same exact number in fewer glyphs.
  /// `45d` is still a number someone plans around. `312d` is not: past two
  /// months nobody subtracts that from today, they read it as "far away", and
  /// a column of three-digit day counts costs the name beside it its width to
  /// say so.
  ///
  /// Rounded down, never up, and always by whole calendar months. `2 months`
  /// means [LocalDate.plusMonths] twice lands on or before the date, so the
  /// column never grants time the reader does not have. The exact date sits
  /// directly under it either way, which is what makes dropping the remainder
  /// safe here and nowhere else.
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
    if (days < 0) return S.t.late;
    if (days == 0) return S.t.today;
    if (days == 1) return S.t.tomorrow;

    final months = today.monthsUntil(actBy);
    if (months < _monthsFrom) return S.t.daysShort(days);
    if (months < _monthsPerYear) return S.t.monthsShort(months);
    return S.t.yearsShort(months ~/ _monthsPerYear);
  }

  /// Two, not one: a month and a half is still counted in days by the person
  /// holding the phone, and `1 month` on something 45 days out is the rounding
  /// that gets an app one star.
  static const int _monthsFrom = 2;

  static const int _monthsPerYear = 12;

  static String overdueDetail(LocalDate actBy, LocalDate today) =>
      S.t.overdueAgo(actBy.daysUntil(today));

  /// Day-first, which is how dates are written in Vietnam. Using the device
  /// locale here would show an American reader 08/17 for a date a Vietnamese
  /// user typed as 17/08, and the two are indistinguishable on screen.
  static String shortDate(LocalDate date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}
