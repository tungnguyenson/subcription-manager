import 'package:flutter/material.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One closed occurrence as the screen shows it.
class HistoryEntry {
  final String itemName;
  final LocalDate on;

  /// What happened, in the user's words: renewed, cancelled before the charge,
  /// topped up. Never just "done": the point of this screen is that the record
  /// says what was avoided.
  final String what;

  final String? amount;

  const HistoryEntry({
    required this.itemName,
    required this.on,
    required this.what,
    this.amount,
  });
}

/// Groups closed occurrences by month, newest first.
abstract final class HistoryPresenter {
  /// [currentYear] decides which months get their year spelled out. Passed in
  /// rather than read from the clock so the labelling is testable and so one
  /// screen cannot disagree with another mid-render on New Year's Eve.
  static List<(String, List<HistoryEntry>)> byMonth(
    List<HistoryEntry> entries, {
    required int currentYear,
  }) {
    final sorted = [...entries]..sort((a, b) => b.on.compareTo(a.on));

    final buckets = <String, List<HistoryEntry>>{};
    for (final entry in sorted) {
      buckets
          .putIfAbsent(monthLabel(entry.on, currentYear: currentYear), () => [])
          .add(entry);
    }
    return buckets.entries.map((e) => (e.key, e.value)).toList();
  }

  /// `July` while it is still this year, `July 2025` once it is not. A bare
  /// month name on a two-year-old row reads as this year's.
  static String monthLabel(LocalDate date, {required int currentYear}) {
    final name = DateCopy.month(date.month);
    return date.year == currentYear ? name : '$name ${date.year}';
  }

  /// The subtitle at the top. Names what the list is *for*, because a log of
  /// completed chores is otherwise just clutter: it is the evidence that
  /// nothing went wrong, which is the only output this app has.
  static String subtitle(int count) => count == 0
      ? 'Nothing closed yet. What you deal with in time is recorded here.'
      : '$count closed. This is the record of what did not happen.';
}

class HistoryScreen extends StatelessWidget {
  final List<HistoryEntry> done;

  /// Which year counts as "this year" for the month headings.
  final int currentYear;

  /// Occurrences the user skipped. Kept in their own section, never mixed with
  /// the handled ones: skipping mutes one cycle, it does not close anything.
  final List<HistoryEntry> skipped;

  final VoidCallback? onBack;

  const HistoryScreen({
    super.key,
    this.done = const [],
    this.skipped = const [],
    required this.currentYear,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final months = HistoryPresenter.byMonth(done, currentYear: currentYear);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        BackLink(onTap: onBack),
        const Text('History', style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(
          HistoryPresenter.subtitle(done.length),
          style: SubdockText.summary,
        ),
        for (final (label, entries) in months) ...[
          SectionLabel(label),
          GroupedCard(
            children: [for (final entry in entries) _HistoryRow(entry: entry)],
          ),
        ],
        if (skipped.isNotEmpty) ...[
          const SectionLabel('Skipped'),
          GroupedCard(
            children: [for (final entry in skipped) _HistoryRow(entry: entry)],
          ),
        ],
      ],
    );
  }
}

/// Date, name, what happened. The date column is a fixed width so the month's
/// rows line up down the left edge rather than starting wherever the name ends.
class _HistoryRow extends StatelessWidget {
  final HistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SubdockSpacing.rowH),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              MoneyFormat.shortDate(entry.on),
              style: SubdockText.whenDate.copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.itemName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SubdockText.rowLink,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.amount ?? entry.what,
            style: SubdockText.rowLabel.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Builds the screen's entries straight from stored events.
///
/// Kept out of [HistoryScreen] so the wording is testable, and so the screen
/// can also be handed hand-written entries in a test.
abstract final class HistoryFromEvents {
  static List<HistoryEntry> build(
    List<HandledEvent> events,
    Map<String, TrackedItem> items,
  ) {
    return [
      for (final event in events)
        HistoryEntry(
          itemName: items[event.itemId]?.name ?? event.itemId,
          on: event.forDueDate,
          what: _what(items[event.itemId]),
          amount: _amount(event),
        ),
    ];
  }

  static String _what(TrackedItem? item) => switch (item?.category) {
    Category.subscription => 'renewed',
    Category.bill => 'paid',
    Category.insurance => 'paid',
    Category.document => 'renewed',
    Category.other => 'handled',
    null => 'handled',
  };

  /// Shows the figure from the bank statement when there is one. It always
  /// wins over the computed amount, because the bank's foreign-currency fee
  /// makes the computed figure structurally low.
  static String? _amount(HandledEvent event) {
    final minor = event.actualChargedMinor ?? event.baseAmountMinor;
    if (minor == null) return null;
    return '${MoneyFormat.grouped(minor)} ₫';
  }
}
