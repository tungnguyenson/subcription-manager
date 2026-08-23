import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  // The bug this whole file exists for. Adding a month at a time from 31 Jan
  // permanently loses the 31st; anchoring does not.
  test('monthly from the 31st returns to the 31st instead of drifting', () {
    final anchor = d('2026-01-31');

    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.monthly, 1),
      d('2026-02-28'),
    );
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.monthly, 2),
      d('2026-03-31'),
    );
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.monthly, 3),
      d('2026-04-30'),
    );
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.monthly, 4),
      d('2026-05-31'),
    );
  });

  test('accumulating one month at a time is what we must not do', () {
    // Documents the wrong approach so the difference stays visible.
    var drifting = d('2026-01-31');
    for (var i = 0; i < 4; i++) {
      drifting = drifting.plusMonths(1);
    }

    expect(drifting, d('2026-05-28'), reason: 'accumulation loses the 31st');
    expect(
      Recurrence.occurrenceAfter(d('2026-01-31'), Cycle.monthly, 4),
      d('2026-05-31'),
      reason: 'anchoring keeps it',
    );
  });

  test('29 February resolves in a leap year and clamps otherwise', () {
    expect(
      Recurrence.occurrenceAfter(d('2024-02-29'), Cycle.yearly, 4),
      d('2028-02-29'),
    );
    expect(
      Recurrence.occurrenceAfter(d('2024-02-29'), Cycle.yearly, 1),
      d('2025-02-28'),
    );
  });

  test('occurrence zero is the anchor itself', () {
    final anchor = d('2026-08-15');
    expect(Recurrence.occurrenceAfter(anchor, Cycle.monthly, 0), anchor);
  });

  test('a negative occurrence is rejected rather than walking backwards', () {
    expect(
      () => Recurrence.occurrenceAfter(d('2026-08-15'), Cycle.monthly, -1),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('weekly steps seven days', () {
    expect(
      Recurrence.occurrenceAfter(d('2026-08-15'), Cycle.weekly, 2),
      d('2026-08-29'),
    );
  });

  test('quarterly and yearly step the right number of months', () {
    final anchor = d('2026-01-15');
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.quarterly, 1),
      d('2026-04-15'),
    );
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.semiannual, 1),
      d('2026-07-15'),
    );
    expect(
      Recurrence.occurrenceAfter(anchor, Cycle.yearly, 1),
      d('2027-01-15'),
    );
  });

  test('cyclesElapsed counts whole cycles only', () {
    final anchor = d('2026-01-15');
    expect(Recurrence.cyclesElapsed(anchor, Cycle.monthly, d('2026-01-15')), 0);
    expect(Recurrence.cyclesElapsed(anchor, Cycle.monthly, d('2026-02-14')), 0);
    expect(Recurrence.cyclesElapsed(anchor, Cycle.monthly, d('2026-02-15')), 1);
    expect(Recurrence.cyclesElapsed(anchor, Cycle.monthly, d('2026-08-15')), 7);
  });

  test('cyclesElapsed is zero before the anchor', () {
    expect(
      Recurrence.cyclesElapsed(d('2026-08-15'), Cycle.monthly, d('2025-01-01')),
      0,
    );
  });

  test('nextDue returns the anchor while it is still ahead', () {
    expect(
      Recurrence.nextDue(d('2026-09-01'), Cycle.monthly, d('2026-08-15')),
      d('2026-09-01'),
    );
  });

  test('nextDue steps past today for a running cycle', () {
    expect(
      Recurrence.nextDue(d('2026-01-15'), Cycle.monthly, d('2026-08-15')),
      d('2026-09-15'),
    );
  });

  test('nextDue on the due date itself moves to the following cycle', () {
    expect(
      Recurrence.nextDue(d('2026-08-15'), Cycle.monthly, d('2026-08-15')),
      d('2026-09-15'),
    );
  });

  test('nextDue for a one-off is null once it has passed', () {
    expect(Recurrence.nextDue(d('2026-01-01'), null, d('2026-08-15')), isNull);
    expect(
      Recurrence.nextDue(d('2026-12-01'), null, d('2026-08-15')),
      d('2026-12-01'),
    );
  });

  test('actBy subtracts the lead so the deadline is actionable', () {
    expect(Recurrence.actBy(d('2026-08-15'), 7), d('2026-08-08'));
    expect(Recurrence.actBy(d('2026-08-15'), 0), d('2026-08-15'));
  });

  test('actBy crosses a month boundary correctly', () {
    expect(Recurrence.actBy(d('2026-08-01'), 1), d('2026-07-31'));
  });

  test('a negative act-by offset is rejected', () {
    expect(
      () => Recurrence.actBy(d('2026-08-15'), -1),
      throwsA(isA<ArgumentError>()),
    );
  });
  test('occurrenceBefore steps back the same number of cycles', () {
    expect(
      Recurrence.occurrenceBefore(d('2026-08-20'), Cycle.monthly, 3),
      d('2026-05-20'),
    );
    expect(
      Recurrence.occurrenceBefore(d('2026-08-20'), Cycle.weekly, 2),
      d('2026-08-06'),
    );
    expect(
      Recurrence.occurrenceBefore(d('2026-08-20'), Cycle.yearly, 1),
      d('2025-08-20'),
    );
  });

  // Stepping back from a date that was itself clamped does not land on the
  // day it was clamped from. The date the user typed is the one worth keeping,
  // so the loss is documented rather than worked around.
  test('occurrenceBefore is not an exact inverse across a clamped month', () {
    final clamped = Recurrence.occurrenceAfter(
      d('2026-01-31'),
      Cycle.monthly,
      1,
    );
    expect(clamped, d('2026-02-28'));
    expect(
      Recurrence.occurrenceBefore(clamped, Cycle.monthly, 1),
      d('2026-01-28'),
    );
  });

  test('a negative step back is rejected', () {
    expect(
      () => Recurrence.occurrenceBefore(d('2026-08-15'), Cycle.monthly, -1),
      throwsA(isA<ArgumentError>()),
    );
  });
}
