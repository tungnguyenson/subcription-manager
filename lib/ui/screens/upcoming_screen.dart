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
  final String? iconName;
  final bool overdue;

  const UpcomingEntry({
    required this.id,
    required this.when,
    required this.date,
    required this.name,
    this.subtitle,
    this.iconName,
    this.overdue = false,
  });
}

class UpcomingScreen extends StatefulWidget {
  final UpcomingView view;

  /// Shown above the list when something needs the user before the list does.
  final Widget? banner;

  final void Function(UpcomingEntry entry)? onOpen;
  final VoidCallback? onAdd;

  const UpcomingScreen({
    super.key,
    required this.view,
    this.banner,
    this.onOpen,
    this.onAdd,
  });

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen> {
  /// Which of the collapsed summary rows are open. Closed on every launch:
  /// things a month out are real, but they must not compete with this week for
  /// the first screenful.
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final view = widget.view;

    // Nothing tracked at all is not a short list, it is a different screen.
    // Built as a column rather than a one-item list so the placard can sit in
    // the middle of what is left instead of clinging to the title.
    if (view.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          SubdockSpacing.screenH,
          6,
          SubdockSpacing.screenH,
          SubdockSpacing.contentBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upcoming', style: SubdockText.screenTitle),
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
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        const Text('Upcoming', style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(view.summary, style: SubdockText.summary),
        if (widget.banner != null) ...[
          const SizedBox(height: 18),
          widget.banner!,
        ],
        if (view.overdue.isNotEmpty)
          _Section(
            title: 'Overdue',
            danger: true,
            entries: view.overdue,
            onOpen: widget.onOpen,
          ),
        if (view.thisWeek.isNotEmpty)
          _Section(
            title: 'Next 7 days',
            entries: view.thisWeek,
            onOpen: widget.onOpen,
          ),
        if (view.thisMonth.isNotEmpty)
          _Fold(
            id: 'month',
            label: 'Next 30 days',
            entries: view.thisMonth,
            open: _open.contains('month'),
            onToggle: () => _toggle('month'),
            onOpen: widget.onOpen,
          ),
        if (view.later.isNotEmpty)
          _Fold(
            id: 'later',
            label: 'Later',
            entries: view.later,
            open: _open.contains('later'),
            onToggle: () => _toggle('later'),
            onOpen: widget.onOpen,
          ),
      ],
    );
  }

  void _toggle(String id) => setState(() {
    if (!_open.remove(id)) _open.add(id);
  });
}

class _Section extends StatelessWidget {
  final String title;
  final bool danger;
  final List<UpcomingEntry> entries;
  final void Function(UpcomingEntry)? onOpen;

  const _Section({
    required this.title,
    required this.entries,
    this.danger = false,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: SubdockSpacing.sectionTop,
            bottom: SubdockSpacing.sectionBottom,
          ),
          child: Text(
            title.toUpperCase(),
            style: danger
                ? SubdockText.sectionLabel.copyWith(color: SubdockColors.danger)
                : SubdockText.sectionLabel,
          ),
        ),
        GroupedCard(
          children: [
            for (final entry in entries)
              ItemRow(
                name: entry.name,
                iconName: entry.iconName,
                subtitle: entry.subtitle,
                when: entry.when,
                date: entry.date,
                overdue: entry.overdue,
                onTap: () => onOpen?.call(entry),
              ),
          ],
        ),
      ],
    );
  }
}

/// A whole bucket folded into one line: `Next 30 days   3 items ›`.
///
/// The count is on the closed row rather than hidden behind it. A collapsed
/// section with no number reads as a section that might be empty, and the user
/// has to open it to find out — which is the tap this fold exists to save.
class _Fold extends StatelessWidget {
  final String id;
  final String label;
  final List<UpcomingEntry> entries;
  final bool open;
  final VoidCallback onToggle;
  final void Function(UpcomingEntry)? onOpen;

  const _Fold({
    required this.id,
    required this.label,
    required this.entries,
    required this.open,
    required this.onToggle,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: GroupedCard(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SubdockSpacing.rowH,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: SubdockText.rowLink)),
                  Text(
                    '${entries.length} ${entries.length == 1 ? "item" : "items"}',
                    style: SubdockText.rowLabel.copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  if (open)
                    const Caret(up: true)
                  else
                    const Text(
                      '›',
                      style: TextStyle(
                        fontFamily: SubdockText.family,
                        fontSize: 12,
                        height: 1,
                        color: SubdockColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (open)
            for (final entry in entries)
              ItemRow(
                name: entry.name,
                iconName: entry.iconName,
                subtitle: entry.subtitle,
                when: entry.when,
                date: entry.date,
                overdue: entry.overdue,
                onTap: () => onOpen?.call(entry),
              ),
        ],
      ),
    );
  }
}

/// Nothing tracked at all.
///
/// Distinct from "nothing due soon", which is a state the folds already
/// describe. An empty list in a reminder app is ambiguous — it could mean
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
              fontWeight: FontWeight.w600,
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
  static String when(LocalDate actBy, LocalDate today) {
    final days = today.daysUntil(actBy);
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    // Never rounded up into a friendlier unit. "About a month" on something
    // due in 29 days is the single most common one-star complaint in this
    // category, and it is always the app that was trying to be reassuring.
    return '$days days';
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
