import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/upcoming_filter.dart';
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

  static UpcomingView build(
    List<TrackedItem> items,
    LocalDate today, {

    /// Keyed by id. Absent means the source was forgotten between the write
    /// and this read, and the row simply says nothing rather than "unknown".
    Map<String, PaymentSource> sources = const {},

    /// What the user has narrowed the list to, or [UpcomingFilter.none].
    UpcomingFilter filter = UpcomingFilter.none,
  }) {
    // Switched-off items drop out here and leave no trace on this screen.
    // Upcoming used to carry a line naming them, on the theory that a list
    // that quietly got shorter is indistinguishable from the app losing
    // things. It is not: the switch lives on All services, that screen is one
    // tap from this one's own header, and the item is still sitting there with
    // its switch off. A notice here names on the home screen exactly the
    // services the user asked the app to stop mentioning.
    //
    // Which is also why the filter gets to choose the pool rather than only
    // narrow it: "Reminders off" is the one way back to those items from here,
    // and no predicate over this list could ever reach them.
    final pool = filter.pool(items);
    final shown = filter.isEmpty
        ? pool
        : pool.where((i) => filter.matches(i, today)).toList();

    final rows = shown.map((item) => _Row.item(item, sources, today)).toList()
      ..sort((a, b) => a.actBy.compareTo(b.actBy));

    final overdue = <UpcomingEntry>[];
    final trials = <UpcomingEntry>[];
    final thisWeek = <UpcomingEntry>[];
    final thisMonth = <UpcomingEntry>[];
    final later = <UpcomingEntry>[];

    for (final row in rows) {
      final days = today.daysUntil(row.actBy);
      final entry = _entryOf(row, today);

      // Overdue outranks everything, a trial outranks the calendar, and only
      // then does the horizon decide. A trial two weeks out belongs beside the
      // other trials rather than folded into "next 30 days": what makes it
      // urgent is that cancelling is free until that date, which has nothing
      // to do with how far away it is.
      if (days < 0) {
        overdue.add(entry);
      } else if (row.trial) {
        trials.add(entry);
      } else if (days <= weekHorizonDays) {
        thisWeek.add(entry);
      } else if (days <= monthHorizonDays) {
        thisMonth.add(entry);
      } else {
        later.add(entry);
      }
    }

    return UpcomingView(
      overdue: overdue,
      trials: trials,
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      later: later,
      filtering: filter.isNotEmpty,
      shown: shown.length,
      total: pool.length,
    );
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
      sourceName: row.sourceName,
      iconName: row.iconName,
      overdue: overdue,
      trial: row.trial,
    );
  }
}

/// What the screen needs, assembled in one pass.
///
/// There is no summary line here on purpose. One used to sit under the title
/// counting overdue and due-this-week items, and the hand-off drops it: every
/// section heading below already carries its own count, so the line restated
/// the screen at the cost of the first row's place on it.
class UpcomingView {
  final List<UpcomingEntry> overdue;
  final List<UpcomingEntry> trials;
  final List<UpcomingEntry> thisWeek;
  final List<UpcomingEntry> thisMonth;
  final List<UpcomingEntry> later;

  /// At least one filter condition is on.
  ///
  /// The screen needs this and not just the counts, because an empty list means
  /// two different things: nothing tracked at all, or nothing left after the
  /// chips. Those are different screens with different ways out of them.
  final bool filtering;

  /// How many items survived the filter, and how many it drew from.
  ///
  /// Counted over items rather than over the entries below, so the number the
  /// summary line quotes is the same number whatever the buckets did with them.
  final int shown;
  final int total;

  const UpcomingView({
    this.overdue = const [],
    this.trials = const [],
    this.thisWeek = const [],
    this.thisMonth = const [],
    this.later = const [],
    this.filtering = false,
    this.shown = 0,
    this.total = 0,
  });

  bool get isEmpty =>
      overdue.isEmpty &&
      trials.isEmpty &&
      thisWeek.isEmpty &&
      thisMonth.isEmpty &&
      later.isEmpty;

  /// The filter is on and has left nothing. Distinct from [isEmpty] alone,
  /// which on an unfiltered list means the user has not tracked anything.
  bool get noMatches => filtering && isEmpty;
}

/// An item reduced to what the bucketing loop and the row need.
class _Row {
  final String id;
  final String name;
  final String? subtitle;
  final String? sourceName;
  final String? iconName;
  final LocalDate actBy;
  final bool trial;

  const _Row({
    required this.id,
    required this.name,
    this.subtitle,
    this.sourceName,
    this.iconName,
    required this.actBy,
    this.trial = false,
  });

  factory _Row.item(
    TrackedItem item,
    Map<String, PaymentSource> sources,
    LocalDate today,
  ) => _Row(
    id: item.id,
    name: item.name,
    subtitle: subtitleOf(item, today),
    sourceName: sources[item.paymentSourceId]?.name,
    iconName: item.iconName,
    actBy: item.actBy,
    trial: item.isTrialOn(today),
  );

  /// The second line: what it costs, and which instalment this is.
  ///
  /// The instalment clause is the one thing on a list row that is not obvious
  /// from the item's name. "1,200,000 đ" four times in a row looks like a bug;
  /// "1,200,000 đ · payment 4 of 6" is a plan running to schedule.
  ///
  /// A trial says the amount is not being charged yet. "260,000 đ" on a row
  /// whose whole point is that nothing has been taken is the one wrong thing
  /// this line could say.
  static String? subtitleOf(TrackedItem item, LocalDate today) {
    final money = item.money;

    // if (item.isTrialOn(today)) {
    //   return money == null
    //       ? 'Free now'
    //       : 'Free now · then ${MoneyFormat.full(money)}';
    // }

    final parts = <String>[];
    if (money != null) parts.add(MoneyFormat.full(money));

    final position = Instalments.of(item);
    if (position != null) {
      parts.add('payment ${position.index} of ${position.total}');
    }

    return parts.isEmpty ? null : parts.join(' · ');
  }
}
