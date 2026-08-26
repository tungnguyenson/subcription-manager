import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/calendar_presenter.dart';

void main() {
  // A Wednesday. August 2026 starts on a Saturday, which is what makes it a
  // useful month to grid: five leading blanks and a six-row month.
  final today = LocalDate.parse('2026-08-26');
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item(
    String id, {
    required String expiresOn,
    String categoryId = 'STREAMING',
    int actByOffsetDays = 0,
    int? amountMinor,
    Cycle? cycle,
    int? repeatCount,
    String? anchorDate,
    bool paused = false,
    bool inTrial = false,
  }) => TrackedItem(
    id: id,
    name: id,
    categoryId: categoryId,
    expiresOn: d(expiresOn),
    actByOffsetDays: actByOffsetDays,
    anchorDate: d(anchorDate ?? expiresOn),
    cycle: cycle,
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: amountMinor == null ? null : 'VND',
    paused: paused,
    inTrial: inTrial,
  );

  /// The day numbers carrying at least one mark, in grid order.
  List<int> busyDays(CalendarView view) => [
    for (final cell in view.cells)
      if (cell.count > 0) cell.date!.day,
  ];

  CalendarCell cellOn(CalendarView view, int day) =>
      view.cells.firstWhere((c) => c.date?.day == day);

  group('the grid', () {
    test('starts with a blank for every weekday before the 1st', () {
      final view = CalendarPresenter.build(const [], today);

      // 1 August 2026 is a Saturday, and the week starts on Monday.
      expect(view.cells.take(5).every((c) => c.date == null), isTrue);
      expect(view.cells[5].date, d('2026-08-01'));
    });

    test('is always whole weeks, so the card cannot change height', () {
      for (final (year, month) in [(2026, 2), (2026, 8), (2027, 3)]) {
        final view = CalendarPresenter.build(
          const [],
          today,
          year: year,
          month: month,
        );
        expect(view.cells.length % 7, 0, reason: '$year-$month');
      }
    });

    test('names the month the way the header draws it', () {
      final view = CalendarPresenter.build(const [], today);
      expect(view.monthLabel, 'Aug 2026');
    });

    test('the two arrows step over the year boundary', () {
      final december = CalendarPresenter.build(
        const [],
        today,
        year: 2026,
        month: 12,
      );
      expect(december.next, (2027, 1));

      final january = CalendarPresenter.build(
        const [],
        today,
        year: 2026,
        month: 1,
      );
      expect(january.previous, (2025, 12));
    });
  });

  group('what lands on a day', () {
    // The whole reason the grid projects rather than plotting `item.actBy`:
    // the list shows only what is next, and a calendar that goes blank in
    // September for a monthly subscription is not a calendar.
    test('a monthly item appears in every month, not only its next one', () {
      final items = [
        item('netflix', expiresOn: '2026-08-20', cycle: Cycle.monthly),
      ];

      expect(busyDays(CalendarPresenter.build(items, today)), [20]);
      expect(
        busyDays(CalendarPresenter.build(items, today, year: 2026, month: 11)),
        [20],
      );
    });

    test('a one-off appears on its own date and nowhere else', () {
      final items = [item('passport', expiresOn: '2026-08-20', cycle: null)];

      expect(busyDays(CalendarPresenter.build(items, today)), [20]);
      expect(
        busyDays(CalendarPresenter.build(items, today, year: 2026, month: 9)),
        isEmpty,
      );
    });

    // The grid plots act-by, because the list buckets by act-by. The two
    // layouts are one screen, and an item cannot sit on two different days
    // depending on which one is drawn.
    test('an act-by offset moves the mark, not just the row', () {
      final view = CalendarPresenter.build([
        item('bhyt', expiresOn: '2026-08-20', actByOffsetDays: 5),
      ], today);

      expect(busyDays(view), [15]);
    });

    // Same rule the spending chart follows: the anchor is the earliest date
    // the app has evidence for, and a subscription entered today did not
    // silently exist last year.
    test('nothing is drawn before the anchor', () {
      final items = [
        item(
          'netflix',
          expiresOn: '2026-08-20',
          anchorDate: '2026-08-20',
          cycle: Cycle.monthly,
        ),
      ];

      expect(
        busyDays(CalendarPresenter.build(items, today, year: 2026, month: 7)),
        isEmpty,
      );
    });

    test('a counted plan stops at its last instalment', () {
      final items = [
        item(
          'laptop',
          expiresOn: '2026-08-10',
          cycle: Cycle.monthly,
          repeatCount: 3,
        ),
      ];

      expect(
        busyDays(CalendarPresenter.build(items, today, year: 2026, month: 10)),
        [10],
      );
      expect(
        busyDays(CalendarPresenter.build(items, today, year: 2026, month: 11)),
        isEmpty,
      );
    });

    // A daily item anchored years back must not be walked one day at a time
    // on every rebuild. The result is what proves the skip landed right.
    test('a daily item fills the month it is asked about', () {
      final view = CalendarPresenter.build(
        [
          item(
            'water',
            expiresOn: '2020-01-01',
            anchorDate: '2020-01-01',
            cycle: Cycle.weekly,
          ),
        ],
        today,
        year: 2026,
        month: 8,
      );

      // Weekly from a Wednesday: every Wednesday of August 2026.
      expect(busyDays(view), [5, 12, 19, 26]);
    });

    test('a switched-off item is absent, exactly as it is from the list', () {
      final view = CalendarPresenter.build([
        item('muted', expiresOn: '2026-08-20', paused: true),
      ], today);

      expect(busyDays(view), isEmpty);
    });

    test('the filter narrows the grid the same way it narrows the list', () {
      final items = [
        item('netflix', expiresOn: '2026-08-18', categoryId: 'STREAMING'),
        item('viettel', expiresOn: '2026-08-19', categoryId: 'PHONE'),
      ];

      final view = CalendarPresenter.build(
        items,
        today,
        filter: const UpcomingFilter(categoryIds: {'PHONE'}),
      );

      expect(busyDays(view), [19]);
    });
  });

  group('a crowded day', () {
    test('draws every mark while they fit', () {
      final view = CalendarPresenter.build([
        item('a', expiresOn: '2026-08-20'),
        item('b', expiresOn: '2026-08-20'),
      ], today);

      final cell = cellOn(view, 20);
      expect(cell.marks.length, 2);
      expect(cell.extra, 0);
    });

    // Two marks and silence would under-report on the one screen whose job is
    // to say what is coming, so past the limit the cell counts instead.
    test('past the limit it draws one mark and says how many it left', () {
      final view = CalendarPresenter.build([
        item('a', expiresOn: '2026-08-20'),
        item('b', expiresOn: '2026-08-20'),
        item('c', expiresOn: '2026-08-20'),
        item('d', expiresOn: '2026-08-20'),
      ], today);

      final cell = cellOn(view, 20);
      expect(cell.marks.length, 1);
      expect(cell.count, 4);
      expect(cell.extra, 3);
    });
  });

  group('which day opens', () {
    test('today, when today has something on it', () {
      final view = CalendarPresenter.build([
        item('netflix', expiresOn: '2026-08-26'),
        item('spotify', expiresOn: '2026-08-29'),
      ], today);

      expect(view.selected, today);
    });

    // A calendar is opened to find out what is next. Landing on a bare
    // `Nothing on this day` under a grid full of marks answers nobody's
    // question -- and today is drawn as today whether it is selected or not.
    test('the soonest day from today on, when today is empty', () {
      final view = CalendarPresenter.build([
        item('spotify', expiresOn: '2026-08-29'),
      ], today);

      expect(view.selected, d('2026-08-29'));
    });

    test('never a day that has already gone by', () {
      final view = CalendarPresenter.build([
        item('viettel', expiresOn: '2026-08-22'),
      ], today);

      expect(view.selected, today);
    });

    test('the first of a month today is not in, when that month is empty', () {
      final view = CalendarPresenter.build(
        const [],
        today,
        year: 2026,
        month: 11,
      );

      expect(view.selected, d('2026-11-01'));
    });

    test('an explicit day wins over all of it', () {
      final view = CalendarPresenter.build(
        [item('spotify', expiresOn: '2026-08-29')],
        today,
        selected: d('2026-08-04'),
      );

      expect(view.selected, d('2026-08-04'));
      expect(cellOn(view, 4).selected, isTrue);
    });
  });

  group('the day open under the grid', () {
    test('is headed the way the design writes it', () {
      final view = CalendarPresenter.build(
        const [],
        today,
        selected: d('2026-08-20'),
      );

      expect(view.selectedLabel, 'Thu 20 Aug 2026');
    });

    // The row counts down to the occurrence the reader tapped, not to whatever
    // the item says is next. A November mark whose row reads `2d` is the grid
    // and the list telling two different stories about one tap.
    test('counts down to the day tapped, not to the item\'s next one', () {
      final view = CalendarPresenter.build(
        [item('netflix', expiresOn: '2026-08-28', cycle: Cycle.monthly)],
        today,
        year: 2026,
        month: 11,
      );

      expect(view.entries.single.date, '28/11');
      expect(view.entries.single.when, '94d');
    });

    test('is empty on a day with nothing on it', () {
      final view = CalendarPresenter.build(
        [item('netflix', expiresOn: '2026-08-28')],
        today,
        selected: d('2026-08-04'),
      );

      expect(view.entries, isEmpty);
    });
  });

  group('a late day', () {
    // What the list calls Overdue, in one number.
    test('is marked when the item still names it as the date to act by', () {
      final view = CalendarPresenter.build([
        item('viettel', expiresOn: '2026-08-22', cycle: null),
      ], today);

      expect(cellOn(view, 22).overdue, isTrue);
    });

    // A monthly plan anchored a year back fills last year with dates that were
    // paid on time. The grid works those out from the cycle and cannot know
    // otherwise, so painting them red would claim twelve missed bills.
    test('is not marked on an occurrence the cycle merely worked out', () {
      final view = CalendarPresenter.build(
        [
          item(
            'netflix',
            expiresOn: '2026-09-20',
            anchorDate: '2025-09-20',
            cycle: Cycle.monthly,
          ),
        ],
        today,
        year: 2026,
        month: 3,
      );

      expect(cellOn(view, 20).count, 1);
      expect(cellOn(view, 20).overdue, isFalse);
    });

    test('is not marked on a day still to come', () {
      final view = CalendarPresenter.build([
        item('spotify', expiresOn: '2026-08-29'),
      ], today);

      expect(cellOn(view, 29).overdue, isFalse);
    });
  });
}
