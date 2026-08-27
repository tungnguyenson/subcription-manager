import 'package:flutter/material.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// Which rows the user is looking at.
enum HistoryFilter {
  all('All'),
  paid('Paid'),
  missed('Missed');

  final String label;

  const HistoryFilter(this.label);
}

/// One closed occurrence as the screen shows it.
class HistoryEntry {
  final String itemName;
  final LocalDate on;

  /// What happened, in the user's words: renewed, cancelled before the charge,
  /// topped up. Never just "done": the point of this screen is that the record
  /// says what was avoided.
  final String what;

  final String? amount;

  /// Closed after its own due date had passed.
  ///
  /// This is the whole of what the app can honestly call *missed*. It never
  /// records a due date going by untouched — an unhandled occurrence simply
  /// stays on Upcoming as overdue, so there is no row to write for it. What is
  /// on record is the day the user closed it, and a closing stamped later than
  /// the date it was for is a date that went past. Anything more would be the
  /// app inventing occurrences it never saw.
  final bool missed;

  const HistoryEntry({
    required this.itemName,
    required this.on,
    required this.what,
    this.amount,
    this.missed = false,
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
  static String subtitle(
    int count, {
    HistoryFilter filter = HistoryFilter.all,
    int missed = 0,
  }) {
    if (count > 0) {
      return switch (filter) {
        // "The record of what did not happen" is only true while nothing on
        // the list went past its date. Said over a list with six misses in it,
        // the screen is contradicting its own rows.
        HistoryFilter.all when missed == 0 =>
          '$count closed. This is the record of what did not happen.',
        HistoryFilter.all =>
          '$count closed · $missed after the date had passed.',
        HistoryFilter.paid => '$count closed on time or before.',
        HistoryFilter.missed => '$count closed after the date had passed.',
      };
    }
    return switch (filter) {
      HistoryFilter.all =>
        'Nothing closed yet. What you deal with in time is recorded here.',
      HistoryFilter.paid => 'Nothing closed on time yet.',
      // Says what it means rather than "nothing here". An empty Missed list is
      // the one result on this screen that is good news.
      HistoryFilter.missed => 'Nothing has gone past its date unhandled.',
    };
  }
}

class HistoryScreen extends StatefulWidget {
  final List<HistoryEntry> done;

  /// Which year counts as "this year" for the month headings.
  final int currentYear;

  final VoidCallback? onBack;

  const HistoryScreen({
    super.key,
    this.done = const [],
    required this.currentYear,
    this.onBack,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    final all = widget.done;
    final rows = switch (_filter) {
      HistoryFilter.all => all,
      HistoryFilter.paid => [
        for (final e in all)
          if (!e.missed) e,
      ],
      HistoryFilter.missed => [
        for (final e in all)
          if (e.missed) e,
      ],
    };
    final months = HistoryPresenter.byMonth(
      rows,
      currentYear: widget.currentYear,
    );

    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: widget.onBack),
        Text('History', style: SubdockText.screenTitle),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final filter in HistoryFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChipPill(
                  filter.label,
                  selected: filter == _filter,
                  onTap: () => setState(() => _filter = filter),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // The line under the chips counts the rows actually on screen, not the
        // whole log. A subtitle saying "12 closed" over a filtered list of two
        // is the screen contradicting itself.
        Text(
          HistoryPresenter.subtitle(
            rows.length,
            filter: _filter,
            missed: [
              for (final e in rows)
                if (e.missed) e,
            ].length,
          ),
          style: SubdockText.summary,
        ),
        for (final (label, entries) in months) ...[
          SectionLabel(label),
          GroupedCard(
            children: [for (final entry in entries) _HistoryRow(entry: entry)],
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
          // The word, not the amount. The hand-off puts the outcome in this
          // column, and it is the only thing on the row that differs between
          // two occurrences of the same service.
          Text(
            entry.what,
            style: SubdockText.rowLabel.copyWith(
              fontSize: 11.5,
              color: entry.missed ? SubdockColors.danger : null,
            ),
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
    CategoryBook categories,
  ) {
    return [
      for (final event in events)
        HistoryEntry(
          itemName: items[event.itemId]?.name ?? event.itemId,
          on: event.forDueDate,
          what: _missed(event)
              ? 'missed'
              : _what(items[event.itemId], categories),
          amount: _amount(event),
          missed: _missed(event),
        ),
    ];
  }

  /// Closed on a day later than the one it was for.
  ///
  /// Compared as whole days in local time, not as instants: an occurrence
  /// closed at nine in the evening of its own due date is not late, and
  /// comparing epoch seconds against midnight would call it late by twenty-one
  /// hours.
  static bool _missed(HandledEvent event) {
    final closedAt = DateTime.fromMillisecondsSinceEpoch(
      event.handledAtEpochSeconds * 1000,
    );
    final closedOn = LocalDate(closedAt.year, closedAt.month, closedAt.day);
    return event.forDueDate < closedOn;
  }

  /// The verb for a closed occurrence: "Netflix renewed", "Electricity paid".
  ///
  /// Two answers where there used to be six, because the shelf is the user's
  /// now and cannot be asked for a verb. What it can be asked is whether money
  /// was owed: a shelf whose amounts are spending *and* which keeps asking
  /// after the date was *paid*; everything else was *renewed*. A passport
  /// therefore renews even though it nags, because its fee is not spending --
  /// and an item that is no longer around at all is *handled*, which claims
  /// nothing.
  static String _what(TrackedItem? item, CategoryBook categories) {
    if (item == null) return 'handled';
    final shelf = categories[item.categoryId];
    return shelf.isObligation && shelf.countsTowardSpend ? 'paid' : 'renewed';
  }

  /// Shows the figure from the bank statement when there is one. It always
  /// wins over the computed amount, because the bank's foreign-currency fee
  /// makes the computed figure structurally low.
  static String? _amount(HandledEvent event) {
    final minor = event.actualChargedMinor ?? event.baseAmountMinor;
    if (minor == null) return null;
    return '${MoneyFormat.grouped(minor)} ₫';
  }
}
