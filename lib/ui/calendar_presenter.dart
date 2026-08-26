import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/upcoming_presenter.dart';

/// The month grid on Upcoming, and the day the user has open under it.
///
/// Pure, and separate from the widget for the same reason [UpcomingPresenter]
/// is: the date arithmetic here — which cell a recurring item lands in, which
/// blanks a month starts with — is the part worth testing, and testing it
/// through a widget would be slower and would prove less.
abstract final class CalendarPresenter {
  /// Days per week, Monday first.
  ///
  /// Monday rather than the device locale, for the reason [DateCopy] gives
  /// about dates generally: the app must read the same on every phone, and a
  /// Sunday-first grid would move every mark one column on an en-US device
  /// while the dates underneath stayed put.
  static const int _week = 7;

  /// How many marks one cell draws before it starts counting instead.
  ///
  /// Two, because a cell is about a seventh of the screen wide and three
  /// 16pt marks do not fit in it. Past two the cell draws one mark and `+n`:
  /// a day with five things on it that shows two marks and nothing else is
  /// the app quietly under-reporting, on the one screen whose whole job is to
  /// say what is coming.
  static const int maxMarks = 2;

  static CalendarView build(
    List<TrackedItem> items,
    LocalDate today, {

    /// The month on screen. Defaults to the one [today] is in.
    int? year,
    int? month,

    /// The day whose list is drawn under the grid. Null lets [selectionFor]
    /// pick, which is what has to happen after a page: a day in August is not
    /// one the September grid can show.
    LocalDate? selected,
    Map<String, PaymentSource> sources = const {},
    UpcomingFilter filter = UpcomingFilter.none,
  }) {
    final shownYear = year ?? today.year;
    final shownMonth = month ?? today.month;

    // The same pool and the same predicates as the list. Switching between
    // List and Calendar must not change which items exist -- only how they
    // are laid out.
    final pool = filter.pool(items);
    final shown = filter.isEmpty
        ? pool
        : pool.where((i) => filter.matches(i, today)).toList();

    final first = LocalDate(shownYear, shownMonth, 1);
    final last = LocalDate(
      shownYear,
      shownMonth,
      LocalDate.daysInMonth(shownYear, shownMonth),
    );

    // Keyed by day-of-month. Insertion order is the item list's order, which
    // is what keeps two marks in the same cell from swapping places between
    // rebuilds.
    final byDay = <int, List<TrackedItem>>{};
    for (final item in shown) {
      for (final on in actByDatesIn(item, first, last)) {
        (byDay[on.day] ??= []).add(item);
      }
    }

    final day = selected ?? selectionFor(today, shownYear, shownMonth, byDay);

    final cells = <CalendarCell>[
      // Leading blanks, not the tail of the previous month. A greyed-out 27th
      // of July in the first row is a date the reader can tap by mistake and a
      // number that competes with the ones that belong to the month named
      // above it.
      for (var i = 1; i < first.weekday; i++) const CalendarCell.blank(),
      for (var d = 1; d <= last.day; d++)
        _cell(LocalDate(shownYear, shownMonth, d), today, day, byDay[d]),
    ];
    // Filled out to whole weeks so the grid is a rectangle and the card below
    // it does not move up and down as the user pages between a five-week and
    // a six-week month.
    while (cells.length % _week != 0) {
      cells.add(const CalendarCell.blank());
    }

    return CalendarView(
      year: shownYear,
      month: shownMonth,
      monthLabel: '${DateCopy.month(shownMonth).substring(0, 3)} $shownYear',
      cells: cells,
      selected: day,
      selectedLabel: dayLabel(day),
      entries: [
        for (final item in byDay[day.day] ?? const <TrackedItem>[])
          UpcomingPresenter.entryFor(item, today, sources: sources, actBy: day),
      ],
    );
  }

  /// `Thu 20 Aug 2026`, which the screen draws uppercase.
  ///
  /// Spelled out rather than 20/08/2026 because it is a heading, and the
  /// weekday is the part that ties it back to the column it was tapped in.
  static String dayLabel(LocalDate date) =>
      '${DateCopy.weekday(date).substring(0, 3)} ${date.day} '
      '${DateCopy.month(date.month).substring(0, 3)} ${date.year}';

  /// Which day opens when the user arrives at a month.
  ///
  /// The soonest day from today onward that has something on it, and today
  /// itself when today is one of them. A calendar is opened to find out what
  /// is coming, and landing on a bare `Nothing on this day` under a grid
  /// dotted with marks answers a question nobody asked — the reader can see
  /// perfectly well that today is empty, because the grid draws today as
  /// today whether it is selected or not.
  ///
  /// Falls back to today when the rest of its month is empty, and to the 1st
  /// in a month today is not in. Never to a day earlier than today in the
  /// current month: what has already gone by is not what this screen is for.
  static LocalDate selectionFor(
    LocalDate today,
    int year,
    int month,
    Map<int, List<TrackedItem>> byDay,
  ) {
    final current = today.year == year && today.month == month;
    final floor = current ? today.day : 1;
    final busy = (byDay.keys.where((d) => d >= floor).toList()..sort());
    if (busy.isNotEmpty) return LocalDate(year, month, busy.first);
    return current ? today : LocalDate(year, month, 1);
  }

  static CalendarCell _cell(
    LocalDate date,
    LocalDate today,
    LocalDate selected,
    List<TrackedItem>? on,
  ) {
    final items = on ?? const <TrackedItem>[];
    final drawn = items.length > maxMarks ? 1 : items.length;
    return CalendarCell(
      date: date,
      today: date == today,
      selected: date == selected,
      // A past day is not the same as a late one, and only the second is worth
      // a colour. The grid plots occurrences worked out from the cycle, so a
      // monthly plan anchored a year back fills last year with dates that were
      // paid on time; painting those red would tell the reader they are twelve
      // months behind on a bill they never missed.
      //
      // An item's *own* next act-by, still sitting in the past, is the one
      // case the app is sure about -- it is exactly what the list calls
      // Overdue -- so that is the only one this marks.
      overdue: date < today && items.any((i) => i.actBy == date),
      marks: [
        for (final item in items.take(drawn))
          CalendarMark(name: item.name, iconName: item.iconName),
      ],
      count: items.length,
    );
  }

  /// Every act-by date of [item] landing in [from]..[to], oldest first.
  ///
  /// The calendar plots **act-by**, not the due date, because the list beside
  /// it buckets by act-by. Two views of one item on one screen putting it on
  /// two different days is the same failure the app avoids by giving the list
  /// and the scheduler a single `isLive`.
  ///
  /// Walks forward from `anchorDate` and never behind it, exactly as the
  /// spending chart does: the anchor is the earliest date the app has any
  /// evidence for, and stepping back from the due date would draw months of
  /// history the user never mentioned. A freshly added item therefore has an
  /// empty past, which is correct rather than missing.
  ///
  /// A trial is not special-cased here. Money drops the occurrences before the
  /// first charge because those months were free; a deadline before the first
  /// charge is still a deadline, and in practice a trial's anchor *is* its
  /// first charge, so there is nothing before it to drop.
  static Iterable<LocalDate> actByDatesIn(
    TrackedItem item,
    LocalDate from,
    LocalDate to,
  ) sync* {
    final offset = item.actByOffsetDays;
    final cycle = item.cycle;

    if (cycle == null) {
      // A one-off happens on its own date and never again.
      final on = Recurrence.actBy(item.expiresOn, offset);
      if (on.isBetween(from, to)) yield on;
      return;
    }

    final limit = item.repeatCount;
    // Start at the first occurrence that could reach the window rather than
    // stepping there. A daily item anchored three years back is otherwise a
    // thousand iterations per item on every rebuild, and this screen rebuilds
    // on every tap of an arrow.
    for (var n = _firstIndexNear(item, cycle, from); ; n++) {
      if (limit != null && n >= limit) return;
      final on = Recurrence.actBy(
        Recurrence.occurrenceAfter(item.anchorDate, cycle, n),
        offset,
      );
      if (on > to) return;
      if (on >= from) yield on;
    }
  }

  /// The lowest occurrence index that can still land on or after [from].
  ///
  /// Exact for a day cycle, where the calendar distance divides evenly. Months
  /// clamp — 31 January plus one month is 28 February — so those are stepped
  /// from zero instead; twelve steps a year is not worth being clever about.
  static int _firstIndexNear(TrackedItem item, Cycle cycle, LocalDate from) {
    if (cycle.unit != CycleUnit.day) return 0;
    final start = Recurrence.actBy(item.anchorDate, item.actByOffsetDays);
    final behind = start.daysUntil(from);
    if (behind <= 0) return 0;
    return behind ~/ cycle.step;
  }
}

/// One service on one day of the grid.
class CalendarMark {
  final String name;
  final String? iconName;

  const CalendarMark({required this.name, this.iconName});
}

/// One square of the month grid, blank or dated.
class CalendarCell {
  /// Null on the blanks a month starts and ends with.
  final LocalDate? date;

  final bool today;
  final bool selected;

  /// Something on this day is late: the day has gone and the item still names
  /// it as the date to act by.
  final bool overdue;

  /// The marks to draw, already cut to what fits. See [CalendarPresenter.maxMarks].
  final List<CalendarMark> marks;

  /// Everything on this day, drawn or not.
  final int count;

  const CalendarCell({
    required this.date,
    this.today = false,
    this.selected = false,
    this.overdue = false,
    this.marks = const [],
    this.count = 0,
  });

  const CalendarCell.blank()
    : date = null,
      today = false,
      selected = false,
      overdue = false,
      marks = const [],
      count = 0;

  /// How many items this cell has that it is not drawing a mark for.
  int get extra => count - marks.length;
}

/// The month grid and the day open under it.
class CalendarView {
  final int year;
  final int month;

  /// `Aug 2026`.
  final String monthLabel;

  /// Whole weeks, Monday first: always a multiple of seven.
  final List<CalendarCell> cells;

  final LocalDate selected;

  /// `Thu 20 Aug 2026`.
  final String selectedLabel;

  /// The rows for [selected], counting down to that day rather than to the
  /// item's next one.
  final List<UpcomingEntry> entries;

  const CalendarView({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.cells,
    required this.selected,
    required this.selectedLabel,
    this.entries = const [],
  });

  /// The month before and after this one, for the two arrows.
  (int, int) get previous => month == 1 ? (year - 1, 12) : (year, month - 1);
  (int, int) get next => month == 12 ? (year + 1, 1) : (year, month + 1);
}
