import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/upcoming_presenter.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item(
    String id, {
    required String expiresOn,
    Category category = Category.subscription,
    int actByOffsetDays = 0,
    int? amountMinor,
    String? currency,
    Cycle? cycle,
    int? repeatCount,
    String? anchorDate,
    ItemState state = ItemState.active,
  }) {
    return TrackedItem(
      id: id,
      name: id,
      category: category,
      expiresOn: d(expiresOn),
      actByOffsetDays: actByOffsetDays,
      anchorDate: d(anchorDate ?? expiresOn),
      cycle: cycle,
      repeatCount: repeatCount,
      amountMinor: amountMinor,
      currency: currency,
      state: state,
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

  test('archived items do not appear at all', () {
    final view = UpcomingPresenter.build([
      item('gone', expiresOn: '2026-08-18', state: ItemState.archived),
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

      expect(everything(view).map((e) => e.when), [
        'Today',
        'Tomorrow',
        '4 days',
      ]);
    });

    test('an overdue row says how far past it is', () {
      final view = UpcomingPresenter.build([
        item('late', expiresOn: '2026-08-11'),
      ], today);

      final entry = view.overdue.single;
      expect(entry.when, 'Overdue');
      expect(entry.date, '4 days ago');
      expect(entry.overdue, isTrue);
    });

    // Never rounded up into a friendlier unit. "About a month" on something due
    // in 29 days is the single most common one-star complaint in this category.
    test('a distant date is still counted in days', () {
      final view = UpcomingPresenter.build([
        item('x', expiresOn: '2026-09-13'),
      ], today);

      expect(everything(view).single.when, '29 days');
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
          category: Category.bill,
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

    test('an item with no amount shows no second line', () {
      final view = UpcomingPresenter.build([
        item('passport', expiresOn: '2026-08-18', category: Category.document),
      ], today);

      expect(everything(view).single.subtitle, isNull);
    });

    test('the summary counts what is urgent and nothing else', () {
      final view = UpcomingPresenter.build([
        item('late', expiresOn: '2026-08-11'),
        item('soon', expiresOn: '2026-08-18'),
        item('far', expiresOn: '2027-01-01'),
      ], today);

      expect(view.summary, '1 overdue · 1 item within 7 days');
    });

    test('an empty list says so rather than showing a bare zero', () {
      expect(
        UpcomingPresenter.build([], today).summary,
        'Nothing due in the next 7 days',
      );
    });
  });
}
