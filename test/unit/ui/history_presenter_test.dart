import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/screens/history_screen.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  HistoryEntry entry(String name, String on) =>
      HistoryEntry(itemName: name, on: d(on), what: 'x');

  // The year is spelled out on every month that is not the current one, so
  // this test pins the comparison year rather than depending on the clock.
  test('entries group by month, newest month first', () {
    final months = HistoryPresenter.byMonth(currentYear: 2026, [
      entry('a', '2026-07-17'),
      entry('b', '2026-08-12'),
      entry('c', '2026-08-04'),
    ]);

    expect(months.map((m) => m.$1), ['August', 'July']);
    expect(months.first.$2.map((e) => e.itemName), ['b', 'c']);
  });

  test('within a month the newest is first', () {
    final months = HistoryPresenter.byMonth(currentYear: 2026, [
      entry('old', '2026-08-01'),
      entry('new', '2026-08-28'),
      entry('mid', '2026-08-14'),
    ]);

    expect(months.single.$2.map((e) => e.itemName), ['new', 'mid', 'old']);
  });

  test('an empty log groups to nothing rather than an empty month', () {
    expect(HistoryPresenter.byMonth(currentYear: 2026, []), isEmpty);
  });

  // The log of completed chores is the app's only visible output: it is the
  // evidence that nothing went wrong. The subtitle has to say that, or the
  // screen reads as clutter.
  test('the subtitle says what the list is for', () {
    expect(HistoryPresenter.subtitle(0), contains('Nothing closed yet'));
    expect(HistoryPresenter.subtitle(31), contains('31 closed'));
    expect(HistoryPresenter.subtitle(31), contains('did not happen'));
  });

  group('building entries from stored events', () {
    TrackedItem item(String id, Category category) => TrackedItem(
      id: id,
      name: id,
      category: category,
      expiresOn: d('2026-08-01'),
      anchorDate: d('2026-08-01'),
    );

    test('each category gets wording that says what was avoided', () {
      final items = {
        'sub': item('sub', Category.subscription),
        'power': item('power', Category.bill),
        'passport': item('passport', Category.document),
      };
      final events = [
        for (final id in items.keys)
          HandledEvent(
            id: id,
            itemId: id,
            handledAtEpochSeconds: 1,
            forDueDate: d('2026-08-04'),
          ),
      ];

      final built = HistoryFromEvents.build(events, items);
      expect(built.map((e) => e.what), ['renewed', 'paid', 'renewed']);
    });

    test('an event whose item is gone still reads sensibly', () {
      final built = HistoryFromEvents.build([
        HandledEvent(
          id: 'e',
          itemId: 'deleted',
          handledAtEpochSeconds: 1,
          forDueDate: d('2026-08-04'),
        ),
      ], const {});

      expect(built.single.itemName, 'deleted');
      expect(built.single.what, 'handled');
    });

    // The bank's foreign-currency fee makes the computed figure structurally
    // low, so a real statement figure always wins.
    test('the statement figure wins over the computed one', () {
      final built = HistoryFromEvents.build([
        HandledEvent(
          id: 'e',
          itemId: 'x',
          handledAtEpochSeconds: 1,
          forDueDate: d('2026-08-04'),
          baseAmountMinor: 520920,
          actualChargedMinor: 532745,
        ),
      ], const {});

      expect(built.single.amount, '532,745 ₫');
    });

    test('an event with no money shows no amount', () {
      final built = HistoryFromEvents.build([
        HandledEvent(
          id: 'e',
          itemId: 'x',
          handledAtEpochSeconds: 1,
          forDueDate: d('2026-08-04'),
        ),
      ], const {});

      expect(built.single.amount, isNull);
    });
  });
}
