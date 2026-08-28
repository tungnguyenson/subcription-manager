import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/upcoming_presenter.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item(
    String id, {
    required String expiresOn,
    String categoryId = 'STREAMING',
    int actByOffsetDays = 0,
    int? amountMinor,
    String? currency,
    Cycle? cycle,
    int? repeatCount,
    String? anchorDate,
    ItemState state = ItemState.active,
    bool paused = false,
    bool inTrial = false,
    String? paymentSourceId,
  }) {
    return TrackedItem(
      id: id,
      name: id,
      categoryId: categoryId,
      expiresOn: d(expiresOn),
      actByOffsetDays: actByOffsetDays,
      anchorDate: d(anchorDate ?? expiresOn),
      cycle: cycle,
      repeatCount: repeatCount,
      amountMinor: amountMinor,
      currency: currency,
      state: state,
      paused: paused,
      inTrial: inTrial,
      paymentSourceId: paymentSourceId,
    );
  }

  List<UpcomingEntry> everything(UpcomingView view) => [
    ...view.overdue,
    ...view.thisWeek,
    ...view.thisMonth,
    ...view.later,
  ];

  test('items land in the bucket their act-by date falls in', () {
    final view = UpcomingPresenter.build([
      item('late', expiresOn: '2026-08-11'),
      item('soon', expiresOn: '2026-08-18'),
      item('month', expiresOn: '2026-09-05'),
      item('far', expiresOn: '2027-03-01'),
    ], today);

    expect(view.overdue.map((e) => e.id), ['late']);
    expect(view.thisWeek.map((e) => e.id), ['soon']);
    expect(view.thisMonth.map((e) => e.id), ['month']);
    expect(view.later.map((e) => e.id), ['far']);
  });

  // The bucket is decided by the act-by date, not the expiry. On expiry alone
  // this item is 31 days out and would be filed under "later"; the 30-day
  // cancellation notice makes it tomorrow's problem.
  test('bucketing follows act-by, not expiry', () {
    const trial = 'trial';
    final byExpiry = UpcomingPresenter.build([
      item(trial, expiresOn: '2026-09-15'),
    ], today);
    expect(byExpiry.later.map((e) => e.id), [trial], reason: '31 days out');

    final byActBy = UpcomingPresenter.build([
      item(trial, expiresOn: '2026-09-15', actByOffsetDays: 30),
    ], today);
    expect(byActBy.thisWeek.map((e) => e.id), [trial]);
  });

  test('inactive items do not appear at all', () {
    final view = UpcomingPresenter.build([
      item('gone', expiresOn: '2026-08-18', state: ItemState.inactive),
    ], today);

    expect(view.isEmpty, isTrue);
  });

  // A cancelled plan stays on the list until its period runs out, and the row
  // is the only place that can say so. Its reminders are gone, but a row with
  // no reminders looks exactly like every other quiet row, so without the badge
  // it is indistinguishable from one that is still running.
  group('a cancelled subscription still inside its period', () {
    UpcomingEntry only(TrackedItem tracked) =>
        everything(UpcomingPresenter.build([tracked], today)).single;

    test('is on the list, and says it is cancelled', () {
      final entry = only(
        item(
          'Netflix',
          expiresOn: '2026-08-20',
        ).copyWith(state: ItemState.cancelledStillActive),
      );

      expect(entry.cancelled, isTrue);
    });

    test('an ordinary item claims nothing', () {
      expect(only(item('Netflix', expiresOn: '2026-08-20')).cancelled, isFalse);
    });

    // One badge slot, and cancelled takes it. Two badges after the name leave
    // the name about four characters on the line the row exists to show, and
    // the trial is ending either way -- the cancellation is the fact that
    // changed. `ItemRow` decides which is drawn; both flags travel so it can.
    test('a cancelled trial reports both, and the row picks', () {
      final entry = only(
        item(
          'Netflix',
          expiresOn: '2026-08-20',
          inTrial: true,
        ).copyWith(state: ItemState.cancelledStillActive),
      );

      expect(entry.cancelled, isTrue);
      expect(entry.trial, isTrue);
    });
  });

  // Off means off. Upcoming used to carry a line naming the switched-off
  // services, which put on the home screen exactly the names the user had asked
  // the app to stop mentioning. The switch is on All services and so is the
  // item, still sitting there with its switch off; that is where the state
  // belongs.
  test('a switched-off item leaves no trace on this screen', () {
    final view = UpcomingPresenter.build([
      item('muted', expiresOn: '2026-08-18', paused: true),
    ], today);

    expect(view.isEmpty, isTrue);
  });

  group('wording', () {
    test('the near dates read as phrases, not as dates', () {
      final view = UpcomingPresenter.build([
        item('a', expiresOn: '2026-08-15'),
        item('b', expiresOn: '2026-08-16'),
        item('c', expiresOn: '2026-08-19'),
      ], today);

      // Today and tomorrow are spelled out because they are the two the reader
      // acts on; everything else is abbreviated so the column stays narrow
      // enough to scan straight down.
      expect(everything(view).map((e) => e.when), ['Today', 'Tomorrow', '4d']);
    });

    test('an overdue row says how far past it is', () {
      final view = UpcomingPresenter.build([
        item('late', expiresOn: '2026-08-11'),
      ], today);

      final entry = view.overdue.single;
      expect(entry.when, 'Late');
      expect(entry.date, '4 days ago');
      expect(entry.overdue, isTrue);
    });

    // Abbreviated, never rounded, for as long as the reader is still counting
    // in days. "About a month" on something due in 29 days is the single most
    // common one-star complaint in this category, and it is always the app
    // trying to be reassuring; `29d` is the same exact number.
    test('a distant date is still counted in exact days', () {
      final view = UpcomingPresenter.build([
        item('x', expiresOn: '2026-09-13'),
      ], today);

      expect(everything(view).single.when, '29d');
    });

    // A month and a half is still a number someone plans around, and `1 month`
    // on something 45 days away is exactly the rounding the rule above exists
    // to prevent. The switch waits for the second whole month.
    test('a month and a half is still counted in days', () {
      final view = UpcomingPresenter.build([
        item('x', expiresOn: '2026-09-29'),
      ], today);

      expect(everything(view).single.when, '45d');
    });

    test('past two months the column counts in months', () {
      final view = UpcomingPresenter.build([
        item('a', expiresOn: '2026-10-15'),
        item('b', expiresOn: '2027-07-15'),
      ], today);

      expect(everything(view).map((e) => e.when), ['2 months', '11 months']);
    });

    // Whole calendar months, not days over thirty: `2 months` has to mean two
    // months have to pass, so the column never grants time the reader has not
    // got. One day short of the second month is still a day count.
    test('the month count rounds down, never up', () {
      final view = UpcomingPresenter.build([
        item('short', expiresOn: '2026-10-14'),
        item('exact', expiresOn: '2026-10-15'),
        item('over', expiresOn: '2026-11-14'),
      ], today);

      expect(everything(view).map((e) => e.when), [
        '60d',
        '2 months',
        '2 months',
      ]);
    });

    // A passport renews on a ten-year cycle and `120 months` is not a number
    // anyone reads.
    test('past a year the column counts in years', () {
      final view = UpcomingPresenter.build([
        item('a', expiresOn: '2027-08-15'),
        item('b', expiresOn: '2036-08-15'),
      ], today);

      expect(everything(view).map((e) => e.when), ['1 year', '10 years']);
    });

    // Day-first. Using the device locale would render 17/08 as 08/17 for a
    // reader whose phone is set to English, and the two are indistinguishable.
    test('dates are written day-first', () {
      final view = UpcomingPresenter.build([
        item('x', expiresOn: '2026-09-05'),
      ], today);

      expect(everything(view).single.date, '05/09');
    });

    test('amounts keep their own currency and grouping', () {
      final view = UpcomingPresenter.build([
        item(
          'vnd',
          expiresOn: '2026-08-18',
          amountMinor: 260000,
          currency: 'VND',
        ),
        item(
          'usd',
          expiresOn: '2026-08-19',
          amountMinor: 2000,
          currency: 'USD',
        ),
      ], today);

      expect(view.thisWeek[0].subtitle, '260,000 ₫');
      expect(view.thisWeek[1].subtitle, r'$20.00');
    });

    // Four identical amounts in a row look like a bug. The instalment clause is
    // what makes them read as a plan running to schedule.
    test('a limited series says which payment this one is', () {
      final view = UpcomingPresenter.build([
        item(
          'course',
          anchorDate: '2026-05-21',
          expiresOn: '2026-08-21',
          categoryId: 'UTILITIES',
          cycle: Cycle.monthly,
          repeatCount: 6,
          amountMinor: 1200000,
          currency: 'VND',
        ),
      ], today);

      expect(view.thisWeek.single.subtitle, '1,200,000 ₫ · payment 4 of 6');
    });

    test('an open-ended item says nothing about counts', () {
      final view = UpcomingPresenter.build([
        item(
          'netflix',
          expiresOn: '2026-08-21',
          cycle: Cycle.monthly,
          amountMinor: 260000,
          currency: 'VND',
        ),
      ], today);

      expect(view.thisWeek.single.subtitle, '260,000 ₫');
    });

    // The badge says the state; this line says the amount. It used to say both
    // -- "Free now · then 260,000 đ" -- which spent the whole width restating
    // the badge two millimetres above it and pushed the number the reader came
    // for behind four words.
    test('a trial shows the amount, and leaves the state to the badge', () {
      final view = UpcomingPresenter.build([
        item(
          'Claude Pro',
          expiresOn: '2026-08-21',
          cycle: Cycle.monthly,
          amountMinor: 260000,
          currency: 'VND',
          inTrial: true,
        ),
      ], today);

      expect(view.thisWeek.single.trial, isTrue);
      expect(view.thisWeek.single.subtitle, '260,000 ₫');
    });

    // The one case the line still has to answer for itself. With no amount
    // there is nothing left but the state, so it says that rather than going
    // blank -- a trial row with no second line at all reads as a row the app
    // knows nothing about.
    test('a trial with no amount says it is free rather than nothing', () {
      final view = UpcomingPresenter.build([
        item('Some beta', expiresOn: '2026-08-21', inTrial: true),
      ], today);

      expect(view.thisWeek.single.subtitle, 'Free now');
    });

    test('an item with no amount shows no second line', () {
      final view = UpcomingPresenter.build([
        item('passport', expiresOn: '2026-08-18', categoryId: 'DOCUMENTS'),
      ], today);

      expect(everything(view).single.subtitle, isNull);
    });

    // The summary line the presenter used to build is gone: every section
    // heading carries its own count, so the line restated the screen at the
    // cost of the first row's place on it.
    test('each bucket carries its own count and nothing restates them', () {
      final view = UpcomingPresenter.build([
        item('late', expiresOn: '2026-08-11'),
        item('soon', expiresOn: '2026-08-18'),
        item('far', expiresOn: '2027-01-01'),
      ], today);

      expect(view.overdue.length, 1);
      expect(view.thisWeek.length, 1);
      expect(view.later.length, 1);
    });
  });

  // The row says `FREE TRIAL` in a badge beside the name, so this column is
  // free to go back to saying *when*. It used to read `Trial ends`, which is
  // the same fact told twice -- and two words here cost the name most of its
  // width: `Claude Pro` came out of it as `Claude ...`.
  group('a trial row', () {
    test('counts down like every other row', () {
      final view = UpcomingPresenter.build([
        item('Claude Pro', expiresOn: '2026-08-17', inTrial: true),
      ], today);

      expect(view.thisWeek.single.when, '2d');
      expect(view.thisWeek.single.date, '17/08');
      // The badge is what carries the state now, so the flag has to survive.
      expect(view.thisWeek.single.trial, isTrue);
    });

    // And it sits in the bucket its date puts it in, like every other row.
    // Trials used to be lifted into a section of their own above the dated
    // groups, which put a charge two days out and one two months out in the
    // same block and pushed the item due tomorrow down the screen.
    test('lands in the bucket its date puts it in', () {
      final view = UpcomingPresenter.build([
        item('soon', expiresOn: '2026-08-17', inTrial: true),
        item('far', expiresOn: '2026-09-10', inTrial: true),
      ], today);

      expect(view.thisWeek.map((e) => e.id), ['soon']);
      expect(view.thisMonth.map((e) => e.id), ['far']);
    });

    // A trial whose charge date has already gone by is late like anything
    // else. `Trial ends` on a row that ended two days ago says nothing.
    test('an overdue trial still reads as late', () {
      final view = UpcomingPresenter.build([
        item('Claude Pro', expiresOn: '2026-08-13', inTrial: true),
      ], today);

      expect(view.overdue.single.when, 'Late');
    });

    // And it has stopped being a trial, badge and all. Nobody had to come back
    // to the app and say so: the money left on the 13th whether they did or
    // not, and a row still reading `Free now` after that is the app claiming
    // to know something it does not.
    test('the badge and the free-now line go once the charge date passes', () {
      final view = UpcomingPresenter.build([
        item('Claude Pro', expiresOn: '2026-08-13', inTrial: true),
      ], today);

      expect(view.overdue.single.trial, isFalse);
      expect(view.overdue.single.subtitle, isNot(contains('Free now')));
    });
  });

  // The count on the header chip, which is what replaced the section trials
  // used to get to themselves.
  group('the trial count', () {
    test('counts what is in a trial today', () {
      final view = UpcomingPresenter.build([
        item('claude', expiresOn: '2026-08-17', inTrial: true),
        item('netflix', expiresOn: '2026-08-18'),
      ], today);

      expect(view.trials, 1);
    });

    // Counted over the pool, not over what survived the filter, so pressing
    // the chip cannot move the number printed on it.
    test('does not move when the chip beside it is pressed', () {
      final items = [
        item('claude', expiresOn: '2026-08-17', inTrial: true),
        item('netflix', expiresOn: '2026-08-18'),
      ];

      expect(
        UpcomingPresenter.build(
          items,
          today,
          filter: const UpcomingFilter(trialOnly: true),
        ).trials,
        UpcomingPresenter.build(items, today).trials,
      );
    });

    // The same rule the badge follows: money left on the due date whether the
    // user came back to say so or not.
    test('drops an item whose charge date has gone by', () {
      final view = UpcomingPresenter.build([
        item('claude', expiresOn: '2026-08-13', inTrial: true),
      ], today);

      expect(view.trials, 0);
    });
  });

  // The filter narrows the list without changing its shape: every section the
  // screen draws is still the section it was, and an item that survives lands
  // where its own date puts it.
  group('with a filter on', () {
    final items = [
      item('netflix', expiresOn: '2026-08-18', categoryId: 'STREAMING'),
      item('viettel', expiresOn: '2026-08-19', categoryId: 'PHONE'),
      item('bhyt', expiresOn: '2026-09-20', categoryId: 'INSURANCE'),
      item('muted', expiresOn: '2026-08-17', paused: true),
    ];

    test('nothing selected leaves the list exactly as it was', () {
      final plain = UpcomingPresenter.build(items, today);
      final filtered = UpcomingPresenter.build(
        items,
        today,
        filter: UpcomingFilter.none,
      );

      expect(filtered.filtering, isFalse);
      expect(
        filtered.thisWeek.map((e) => e.id),
        plain.thisWeek.map((e) => e.id),
      );
    });

    test('a shelf chip keeps only that shelf', () {
      final view = UpcomingPresenter.build(
        items,
        today,
        filter: const UpcomingFilter(categoryIds: {'PHONE'}),
      );

      expect(view.thisWeek.map((e) => e.id), ['viettel']);
      expect(view.filtering, isTrue);
      expect(view.shown, 1);
      // Counted against the pool the filter drew from, which is the three
      // items Upcoming would have shown -- not against the muted one too.
      expect(view.total, 3);
    });

    test('a match past the horizon still lands in its own section', () {
      final view = UpcomingPresenter.build(
        items,
        today,
        filter: const UpcomingFilter(categoryIds: {'INSURANCE'}),
      );

      expect(view.later.map((e) => e.id), ['bhyt']);
      expect(view.thisWeek, isEmpty);
    });

    // The one chip that reaches items the screen otherwise refuses to show.
    test(
      'Reminders off brings back the switched-off items, and only those',
      () {
        final view = UpcomingPresenter.build(
          items,
          today,
          filter: const UpcomingFilter(mutedOnly: true),
        );

        expect(view.thisWeek.map((e) => e.id), ['muted']);
        expect(view.total, 1);
      },
    );

    test('a filter that matches nothing is not an untracked app', () {
      final view = UpcomingPresenter.build(
        items,
        today,
        filter: const UpcomingFilter(noPriceOnly: true, trialOnly: true),
      );

      expect(view.isEmpty, isTrue);
      expect(view.noMatches, isTrue);
    });

    test('an empty list with no filter on is not a failed match', () {
      final view = UpcomingPresenter.build(const [], today);
      expect(view.isEmpty, isTrue);
      expect(view.noMatches, isFalse);
    });
  });
}
