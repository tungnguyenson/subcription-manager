import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';

/// Turns the item list into the buckets the Upcoming screen renders.
///
/// Pure, and deliberately separate from the widget: the bucket boundaries and
/// the wording are the parts worth testing, and a widget test would verify them
/// far more slowly and far less directly.
abstract final class UpcomingPresenter {
  /// The list shows this week in full. Everything past it collapses to a
  /// one-line summary the user opens, because a list that shows a year of
  /// renewals is a list nobody scans.
  static const int weekHorizonDays = 7;

  /// Past this, an item is "later" rather than "next 30 days".
  static const int monthHorizonDays = 30;

  static UpcomingView build(List<TrackedItem> items, LocalDate today) {
    final rows =
        items
            .where((item) => item.state != ItemState.archived)
            .map(_Row.item)
            .toList()
          ..sort((a, b) => a.actBy.compareTo(b.actBy));

    final overdue = <UpcomingEntry>[];
    final thisWeek = <UpcomingEntry>[];
    final thisMonth = <UpcomingEntry>[];
    final later = <UpcomingEntry>[];

    for (final row in rows) {
      final days = today.daysUntil(row.actBy);
      final entry = _entryOf(row, today);

      if (days < 0) {
        overdue.add(entry);
      } else if (days <= weekHorizonDays) {
        thisWeek.add(entry);
      } else if (days <= monthHorizonDays) {
        thisMonth.add(entry);
      } else {
        later.add(entry);
      }
    }

    return UpcomingView(
      summary: summaryLine(overdue.length, thisWeek.length),
      overdue: overdue,
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      later: later,
    );
  }

  /// The line under the title. Counts only what is actually pressing: an item
  /// eleven months out is real but is not what this line is for.
  static String summaryLine(int overdue, int thisWeek) {
    final parts = <String>[];
    if (overdue > 0) parts.add('$overdue overdue');
    if (thisWeek > 0) {
      parts.add('$thisWeek ${thisWeek == 1 ? "item" : "items"} within 7 days');
    }
    return parts.isEmpty ? 'Nothing due in the next 7 days' : parts.join(' · ');
  }

  static UpcomingEntry _entryOf(_Row row, LocalDate today) {
    final overdue = row.actBy < today;
    return UpcomingEntry(
      id: row.id,
      when: UpcomingCopy.when(row.actBy, today),
      date: overdue
          ? UpcomingCopy.overdueDetail(row.actBy, today)
          : UpcomingCopy.shortDate(row.actBy),
      name: row.name,
      subtitle: row.subtitle,
      iconName: row.iconName,
      overdue: overdue,
    );
  }
}

/// What the screen needs, assembled in one pass.
class UpcomingView {
  final String summary;
  final List<UpcomingEntry> overdue;
  final List<UpcomingEntry> thisWeek;
  final List<UpcomingEntry> thisMonth;
  final List<UpcomingEntry> later;

  const UpcomingView({
    required this.summary,
    this.overdue = const [],
    this.thisWeek = const [],
    this.thisMonth = const [],
    this.later = const [],
  });

  bool get isEmpty =>
      overdue.isEmpty && thisWeek.isEmpty && thisMonth.isEmpty && later.isEmpty;
}

/// An item reduced to what the bucketing loop and the row need.
class _Row {
  final String id;
  final String name;
  final String? subtitle;
  final String? iconName;
  final LocalDate actBy;

  const _Row({
    required this.id,
    required this.name,
    this.subtitle,
    this.iconName,
    required this.actBy,
  });

  factory _Row.item(TrackedItem item) => _Row(
    id: item.id,
    name: item.name,
    subtitle: subtitleOf(item),
    iconName: item.iconName,
    actBy: item.actBy,
  );

  /// The second line: what it costs, and which instalment this is.
  ///
  /// The instalment clause is the one thing on a list row that is not obvious
  /// from the item's name. "1,200,000 đ" four times in a row looks like a bug;
  /// "1,200,000 đ · payment 4 of 6" is a plan running to schedule.
  static String? subtitleOf(TrackedItem item) {
    final parts = <String>[];

    final money = item.money;
    if (money != null) parts.add(MoneyFormat.full(money));

    final position = Instalments.of(item);
    if (position != null) {
      parts.add('payment ${position.index} of ${position.total}');
    }

    return parts.isEmpty ? null : parts.join(' · ');
  }
}
