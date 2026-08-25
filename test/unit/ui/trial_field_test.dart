import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/ui/screens/add/trial_field.dart';

/// A trial has a start, a length and a first-charge date, and any two fix the
/// third. These are the cases where getting that wrong would silently move a
/// date the user had entered.
void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  test('off means both dates are unset', () {
    expect(TrialDraft.off.on, isFalse);
    expect(TrialDraft.off.spanDays, isNull);
  });

  test('either date on its own turns it on', () {
    expect(TrialDraft(start: d('2026-08-03')).on, isTrue);
    expect(TrialDraft(firstCharge: d('2026-08-17')).on, isTrue);
  });

  test('two dates compute the length', () {
    final draft = TrialDraft(
      start: d('2026-08-03'),
      firstCharge: d('2026-08-17'),
    );

    expect(draft.spanDays, 14);
  });

  group('with no lock', () {
    test('moving one date leaves the other alone', () {
      final draft = TrialDraft(
        start: d('2026-08-03'),
        firstCharge: d('2026-08-17'),
      ).withStart(d('2026-08-05'));

      expect(draft.firstCharge, d('2026-08-17'));
      expect(draft.spanDays, 12);
    });
  });

  group('with a locked length', () {
    // The lock is the whole point of the control: a user who knows "it started
    // last Tuesday and it is a 14-day trial" should not have to work out the
    // charge date in their head.
    test('moving the start moves the charge date', () {
      final draft = TrialDraft(start: d('2026-08-03'))
          .withLength(14)
          .withStart(d('2026-08-10'));

      expect(draft.firstCharge, d('2026-08-24'));
      expect(draft.lockedDays, 14);
    });

    test('moving the charge date moves the start', () {
      final draft = TrialDraft(start: d('2026-08-03'))
          .withLength(14)
          .withFirstCharge(d('2026-09-01'));

      expect(draft.start, d('2026-08-18'));
    });

    // The start wins when both are set: it is the date the user remembers, and
    // the charge date is the one they are guessing at — which is why they
    // reached for a preset length in the first place.
    test('locking a length moves the charge date, not the start', () {
      final draft = TrialDraft(
        start: d('2026-08-03'),
        firstCharge: d('2026-08-30'),
      ).withLength(7);

      expect(draft.start, d('2026-08-03'));
      expect(draft.firstCharge, d('2026-08-10'));
    });

    test('a length locked with only a charge date works the start back', () {
      final draft = TrialDraft(firstCharge: d('2026-08-17')).withLength(30);

      expect(draft.start, d('2026-07-18'));
    });

    test('unlocking keeps both dates where they are', () {
      final locked = TrialDraft(start: d('2026-08-03')).withLength(14);
      final free = locked.unlocked;

      expect(free.start, locked.start);
      expect(free.firstCharge, locked.firstCharge);
      expect(free.lockedDays, isNull);
    });
  });

  group('the summary', () {
    // The promise of the whole feature is "you will be warned while cancelling
    // is still free", and that is only believable if the dates are on screen.
    test('names the charge date and the reminder date', () {
      final draft = TrialDraft(
        start: d('2026-08-03'),
        firstCharge: d('2026-08-17'),
      );

      expect(
        draft.summary(3),
        'Free for 14 days · charges 17/08 · reminder 3 days before, on 14/08',
      );
    });

    test('asks for what is missing rather than guessing it', () {
      expect(TrialDraft.off.summary(3), 'Set the day the trial started.');
      expect(
        TrialDraft(start: d('2026-08-03')).summary(3),
        'Pick a length, or set the first charge date.',
      );
      expect(
        TrialDraft(firstCharge: d('2026-08-17')).summary(3),
        'Pick a length and the start date is worked out.',
      );
    });

    test('a one-day trial is not called "1 days"', () {
      final draft = TrialDraft(
        start: d('2026-08-03'),
        firstCharge: d('2026-08-04'),
      );

      expect(draft.summary(0), contains('Free for 1 day ·'));
    });
  });
}
