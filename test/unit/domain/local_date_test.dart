import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  group('LocalDate exists because DateTime is wrong for dates', () {
    // This is the whole reason for the class. Dart's constructor normalises
    // out-of-range components by rolling forward, so the obvious way to add a
    // month to 31 January lands in March.
    test('DateTime rolls a short month over into the next one', () {
      expect(DateTime(2026, 2, 31).month, 3);
      expect(DateTime(2026, 2, 31).day, 3);
    });

    test('LocalDate clamps to the last real day instead', () {
      expect(d('2026-01-31').plusMonths(1), d('2026-02-28'));
      expect(d('2026-01-31').plusMonths(3), d('2026-04-30'));
    });

    test('a date that does not exist is refused, not silently moved', () {
      expect(() => LocalDate.parse('2026-02-31'), throwsFormatException);
      expect(() => LocalDate.parse('2026-13-01'), throwsFormatException);
      expect(LocalDate.tryParse('2026-02-31'), isNull);
    });
  });

  group('parsing and formatting', () {
    test('round-trips ISO-8601', () {
      expect(d('2026-08-15').toString(), '2026-08-15');
      expect(d('0999-01-02').toString(), '0999-01-02');
    });

    test('rejects anything that is not YYYY-MM-DD', () {
      for (final bad in ['15/08/2026', '2026-8-15', '2026-08-15T00:00', '']) {
        expect(() => LocalDate.parse(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('arithmetic', () {
    test('day arithmetic crosses months and years', () {
      expect(d('2026-08-31').plusDays(1), d('2026-09-01'));
      expect(d('2026-12-31').plusDays(1), d('2027-01-01'));
      expect(d('2026-01-01').minusDays(1), d('2025-12-31'));
    });

    test('leap day is handled in both directions', () {
      expect(d('2024-02-28').plusDays(1), d('2024-02-29'));
      expect(d('2024-02-29').plusYears(1), d('2025-02-28'));
      expect(d('2024-02-29').plusYears(4), d('2028-02-29'));
    });

    test('negative months walk backwards with the same clamping', () {
      expect(d('2026-03-31').plusMonths(-1), d('2026-02-28'));
      expect(d('2026-01-15').plusMonths(-1), d('2025-12-15'));
    });

    // Day arithmetic through local time would return 0 or 2 here on a device
    // whose zone observes daylight saving. Doing it in UTC does not.
    test('daysUntil is exact across a daylight-saving boundary', () {
      expect(d('2026-03-08').daysUntil(d('2026-03-09')), 1);
      expect(d('2026-11-01').daysUntil(d('2026-11-02')), 1);
      expect(d('2026-01-01').daysUntil(d('2026-12-31')), 364);
      expect(d('2026-08-15').daysUntil(d('2026-08-15')), 0);
    });

    test('daysUntil is negative going backwards', () {
      expect(d('2026-08-15').daysUntil(d('2026-08-10')), -5);
    });
  });

  group('comparison', () {
    test('orders by year then month then day', () {
      expect(d('2026-08-15') < d('2026-08-16'), isTrue);
      expect(d('2026-08-15') < d('2026-09-01'), isTrue);
      expect(d('2026-08-15') < d('2027-01-01'), isTrue);
      expect(d('2026-08-15') <= d('2026-08-15'), isTrue);
      expect(d('2026-08-15') > d('2026-08-14'), isTrue);
    });

    test('equal dates are equal values, not equal references', () {
      expect(d('2026-08-15'), LocalDate(2026, 8, 15));
      expect(d('2026-08-15').hashCode, LocalDate(2026, 8, 15).hashCode);
    });

    test('isBetween is inclusive at both ends', () {
      final from = d('2026-08-01');
      final to = d('2026-08-31');
      expect(d('2026-08-01').isBetween(from, to), isTrue);
      expect(d('2026-08-31').isBetween(from, to), isTrue);
      expect(d('2026-07-31').isBetween(from, to), isFalse);
      expect(d('2026-09-01').isBetween(from, to), isFalse);
    });

    test('sorting a list uses calendar order', () {
      final dates = [d('2026-12-01'), d('2026-01-15'), d('2026-08-15')]..sort();
      expect(dates.map((e) => e.toString()).toList(), [
        '2026-01-15',
        '2026-08-15',
        '2026-12-01',
      ]);
    });
  });

  group('LocalTime', () {
    test('round-trips and pads', () {
      expect(LocalTime.parse('08:30').toString(), '08:30');
      expect(const LocalTime(8, 5).toString(), '08:05');
    });

    test('tolerates a seconds field that storage may carry', () {
      expect(LocalTime.parse('08:30:00'), const LocalTime(8, 30));
    });

    test('rejects impossible times', () {
      expect(() => LocalTime.parse('24:00'), throwsFormatException);
      expect(() => LocalTime.parse('08:60'), throwsFormatException);
      expect(() => LocalTime.parse('8:30'), throwsFormatException);
    });

    test('orders by minute of day', () {
      expect(
        const LocalTime(8, 30).compareTo(const LocalTime(9, 0)),
        lessThan(0),
      );
      expect(const LocalTime(8, 30).minuteOfDay, 510);
    });

    test('compares with operators, like LocalDate', () {
      const half8 = LocalTime(8, 30);
      expect(half8 < const LocalTime(8, 31), isTrue);
      expect(half8 <= half8, isTrue);
      expect(half8 > const LocalTime(8, 29), isTrue);
      expect(half8 >= half8, isTrue);
      expect(half8 < half8, isFalse);
    });
  });

  group('LocalDateTime', () {
    // Truncated, not rounded. The planner compares this against a reminder
    // time that has no seconds either, and rounding up would call an alert set
    // for this very minute one that has already gone.
    test('now drops the seconds off the clock', () {
      final at = LocalDateTime.now(DateTime(2026, 8, 25, 18, 40, 59));
      expect(at.date, LocalDate.parse('2026-08-25'));
      expect(at.time, const LocalTime(18, 40));
    });
  });
}
