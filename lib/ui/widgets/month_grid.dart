import 'package:flutter/material.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/calendar_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The month, with an arrow either side of it.
///
/// Above the card rather than inside it, which is what the design draws: the
/// card is the grid, and the two arrows are controls acting on it. Putting
/// them inside would make the first row of the card a toolbar and push the
/// weekday header down a step.
class MonthBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const MonthBar({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Arrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: SubdockText.family,
              fontSize: 16,
              height: 1,
              fontWeight: SubdockWeight.semibold,
              color: SubdockColors.ink,
            ),
          ),
        ),
        _Arrow(icon: Icons.chevron_right_rounded, onTap: onNext),
      ],
    );
  }
}

/// The same circle the filter button is, carrying a chevron instead.
class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Arrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SubdockColors.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 22, color: SubdockColors.inkSecondary),
        ),
      ),
    );
  }
}

/// The grid: a weekday header and whole weeks of days beneath it.
class MonthGrid extends StatelessWidget {
  final CalendarView view;
  final ValueChanged<LocalDate>? onSelect;

  const MonthGrid({super.key, required this.view, this.onSelect});

  /// Monday first, matching [CalendarPresenter].
  static const List<String> _weekdays = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  /// Every cell is this tall whether or not it carries a mark.
  ///
  /// Fixed, not sized to its contents. A grid whose rows breathe with the
  /// number of marks in them changes height as the reader pages between
  /// months, which moves the day list underneath out from under their thumb —
  /// the same reason the Money card holds the same number of lines in every
  /// month.
  static const double _cellHeight = 46;

  @override
  Widget build(BuildContext context) {
    final weeks = view.cells.length ~/ 7;

    return Container(
      decoration: SubdockSurface.card(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in _weekdays)
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: SubdockText.family,
                      fontSize: 10.5,
                      height: 1,
                      fontWeight: SubdockWeight.semibold,
                      letterSpacing: 0.6,
                      color: SubdockColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: SizedBox(
                      height: _cellHeight,
                      child: _Cell(
                        cell: view.cells[w * 7 + i],
                        onSelect: onSelect,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One day, or one of the blanks a month starts and ends with.
class _Cell extends StatelessWidget {
  final CalendarCell cell;
  final ValueChanged<LocalDate>? onSelect;

  const _Cell({required this.cell, this.onSelect});

  /// The mark's drawn size inside a cell about a seventh of the screen wide.
  ///
  /// Two of these plus the gap between them is what sets the ceiling: a cell
  /// on a 390pt screen is roughly 45pt of drawable width, and 18+3+18 is what
  /// fits in it. Smaller reads as a smudge rather than as a logo, which on a
  /// grid whose whole content is logos is the difference between a calendar
  /// and a pattern.
  static const double _markSize = 18;

  @override
  Widget build(BuildContext context) {
    final date = cell.date;
    if (date == null) return const SizedBox.shrink();

    // Three states, and only the selected one fills. Today is a place on the
    // calendar, not a thing the reader chose, so it is drawn as a tint the
    // selection can be moved on top of and still be told apart from.
    final decoration = cell.selected
        ? BoxDecoration(
            color: SubdockColors.accent,
            borderRadius: BorderRadius.circular(SubdockRadius.chip),
          )
        : cell.today
        ? BoxDecoration(
            color: SubdockColors.accentFaint,
            borderRadius: BorderRadius.circular(SubdockRadius.chip),
            border: Border.all(color: SubdockColors.accentSoft),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: decoration,
        child: Material(
          color: const Color(0x00000000),
          child: InkWell(
            // The ripple carries the rounding instead of the box clipping it:
            // a plain day has no decoration at all, and a Container cannot
            // clip what it does not draw.
            borderRadius: BorderRadius.circular(SubdockRadius.chip),
            onTap: onSelect == null ? null : () => onSelect!(date),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 14.5,
                    height: 1,
                    // The days carrying something are the ones worth finding,
                    // so an empty day steps back rather than the busy day
                    // stepping forward: everything is legible, and the grid is
                    // not a field of highlights.
                    fontWeight: cell.count > 0
                        ? SubdockWeight.semibold
                        : SubdockWeight.regular,
                    // Danger outranks everything but the selection, which
                    // has to keep its number readable on a filled box. The
                    // list says the same thing with a whole section; here it
                    // is one number, because a grid has no room for a heading.
                    color: cell.selected
                        ? const Color(0xFFFFFFFF)
                        : cell.overdue
                        ? SubdockColors.danger
                        : cell.count > 0
                        ? SubdockColors.ink
                        : SubdockColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: _markSize,
                  child: _Marks(cell: cell),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The marks under a day's number, and the tally when they do not all fit.
class _Marks extends StatelessWidget {
  final CalendarCell cell;

  const _Marks({required this.cell});

  @override
  Widget build(BuildContext context) {
    if (cell.marks.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cell.marks.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          ServiceTile(
            cell.marks[i].name,
            iconName: cell.marks[i].iconName,
            size: _Cell._markSize,
            radius: 4,
            fontSize: 8,
          ),
        ],
        // What the cell is not drawing. A day with five things on it that
        // shows two marks and stops has under-reported on the one screen whose
        // job is to say what is coming.
        if (cell.extra > 0) ...[
          const SizedBox(width: 3),
          Text(
            '+${cell.extra}',
            style: TextStyle(
              fontFamily: SubdockText.family,
              fontSize: 10,
              height: 1,
              fontWeight: SubdockWeight.medium,
              color: cell.selected
                  ? const Color(0xCCFFFFFF)
                  : SubdockColors.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}
