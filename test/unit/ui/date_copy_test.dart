import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/date_copy.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  // The list is indexed by ISO weekday, which starts at 1 on Monday. An
  // off-by-one here shifts every weekday name by a day and nothing complains.
  test('weekday names line up with the calendar', () {
    expect(DateCopy.weekday(d('2026-08-17')), 'Monday');
    expect(DateCopy.weekday(d('2026-08-22')), 'Saturday');
    expect(DateCopy.weekday(d('2026-08-23')), 'Sunday');
  });

  test('month names line up with the calendar', () {
    expect(DateCopy.month(1), 'January');
    expect(DateCopy.month(8), 'August');
    expect(DateCopy.month(12), 'December');
  });

  test('the long form pairs the weekday with a day-first date', () {
    expect(DateCopy.longDate(d('2026-08-29')), 'Saturday, 29/08/2026');
  });

  test('the lock-screen form drops the year', () {
    expect(DateCopy.lockScreenDate(d('2026-08-16')), 'Sunday 16 August');
  });

  group('shortcuts', () {
    final today = d('2026-08-15');

    test('each one resolves to the date it names', () {
      final resolved = {
        for (final s in DateCopy.shortcuts) s.label: s.resolve(today),
      };

      expect(resolved['Today'], d('2026-08-15'));
      expect(resolved['Tomorrow'], d('2026-08-16'));
      expect(resolved['+7'], d('2026-08-22'));
      expect(resolved['+14'], d('2026-08-29'));
      expect(resolved['+30'], d('2026-09-14'));
    });

    // Five short chips, so the rail never scrolls. A rail that scrolls is a
    // rail whose last shortcuts nobody sees.
    test('there are five of them, in the build file order', () {
      expect(DateCopy.shortcuts.map((s) => s.label), [
        'Today',
        'Tomorrow',
        '+7',
        '+14',
        '+30',
      ]);
    });

    // Days, not months: `+30` from 31 January is 2 March, and it says so
    // rather than clamping the way a month step would.
    test('the offsets are whole days and never clamp', () {
      final shortcut = DateCopy.shortcuts.firstWhere((s) => s.label == '+30');
      expect(shortcut.resolve(d('2026-01-31')), d('2026-03-02'));
    });
  });

  group('act-by line', () {
    test('states the date and how much earlier it is', () {
      expect(DateCopy.actByLine(d('2026-08-29'), 1), '28/08 · 1 day earlier');
      expect(DateCopy.actByLine(d('2026-09-14'), 7), '07/09 · 7 days earlier');
    });

    // Printing "act by 17/08, expires 17/08" reads as two facts and teaches
    // the reader to skim both.
    test('returns nothing when the two dates coincide', () {
      expect(DateCopy.actByLine(d('2026-08-29'), 0), isNull);
      expect(DateCopy.actByLine(d('2026-08-29'), -3), isNull);
    });

    test('crosses a month boundary correctly', () {
      expect(DateCopy.actByLine(d('2026-08-01'), 1), '31/07 · 1 day earlier');
    });
  });
}
