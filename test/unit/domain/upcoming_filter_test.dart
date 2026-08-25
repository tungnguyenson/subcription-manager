import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  // Every item below is due 2026-09-01, so this is a day inside the trial.
  final today = d('2026-08-15');

  TrackedItem item(
    String id, {
    String categoryId = 'STREAMING',
    Cycle? cycle,
    int? amountMinor,
    String? currency,
    String? paymentSourceId,
    bool inTrial = false,
    bool paused = false,
    ItemState state = ItemState.active,
  }) => TrackedItem(
    id: id,
    name: id,
    categoryId: categoryId,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-09-01'),
    cycle: cycle,
    amountMinor: amountMinor,
    currency: currency,
    paymentSourceId: paymentSourceId,
    inTrial: inTrial,
    paused: paused,
    state: state,
  );

  List<String> ids(List<TrackedItem> items) => items.map((i) => i.id).toList();

  group('counting', () {
    test('nothing selected is the empty filter', () {
      expect(UpcomingFilter.none.count, 0);
      expect(UpcomingFilter.none.isEmpty, isTrue);
    });

    // Per chip, not per group: the button says "Show 4 items" for a reason,
    // and the summary line has to agree with what the user can see selected.
    test('every selected chip counts once, across all groups', () {
      const filter = UpcomingFilter(
        categoryIds: {'STREAMING', 'PHONE'},
        cycleKeys: {'MONTHLY'},
        trialOnly: true,
      );
      expect(filter.count, 4);
      expect(filter.isNotEmpty, isTrue);
    });
  });

  group('the pool it draws from', () {
    final items = [
      item('live'),
      item('muted', paused: true),
      item('gone', state: ItemState.archived),
      item('muted and gone', paused: true, state: ItemState.archived),
    ];

    test('normally it is the items Upcoming already shows', () {
      expect(ids(UpcomingFilter.none.pool(items)), ['live']);
    });

    // The one condition that widens. Nothing else in the filter could reach a
    // switched-off item, because Upcoming never hands one to a predicate.
    test('Reminders off swaps the pool rather than narrowing it', () {
      const filter = UpcomingFilter(mutedOnly: true);
      expect(ids(filter.pool(items)), ['muted']);
    });

    test('an archived item is out of both pools', () {
      const filter = UpcomingFilter(mutedOnly: true);
      expect(ids(filter.pool(items)), isNot(contains('gone')));
      expect(ids(filter.pool(items)), isNot(contains('muted and gone')));
    });
  });

  group('matching', () {
    test('an empty group constrains nothing', () {
      expect(UpcomingFilter.none.matches(item('any'), today), isTrue);
    });

    test('within a group the keys are or-ed', () {
      const filter = UpcomingFilter(categoryIds: {'STREAMING', 'PHONE'});
      expect(filter.matches(item('a', categoryId: 'STREAMING'), today), isTrue);
      expect(filter.matches(item('b', categoryId: 'PHONE'), today), isTrue);
      expect(
        filter.matches(item('c', categoryId: 'INSURANCE'), today),
        isFalse,
      );
    });

    test('between groups they are and-ed', () {
      const filter = UpcomingFilter(
        categoryIds: {'STREAMING'},
        cycleKeys: {'MONTHLY'},
      );
      expect(
        filter.matches(
          item('both', categoryId: 'STREAMING', cycle: Cycle.monthly),
          today,
        ),
        isTrue,
      );
      expect(
        filter.matches(
          item('half', categoryId: 'STREAMING', cycle: Cycle.yearly),
          today,
        ),
        isFalse,
      );
    });

    // A one-off has no cycle to name, and "no cycle" is a real answer the user
    // wants to be able to ask for.
    test('a one-off matches the Once key', () {
      const filter = UpcomingFilter(cycleKeys: {UpcomingFilter.onceKey});
      expect(filter.matches(item('once'), today), isTrue);
      expect(
        filter.matches(item('monthly', cycle: Cycle.monthly), today),
        isFalse,
      );
    });

    test('a custom interval matches by its own wire name', () {
      final every5Months = Cycle.every(5, CycleField.month);
      final filter = UpcomingFilter(cycleKeys: {every5Months.wireName});
      expect(
        filter.matches(item('custom', cycle: every5Months), today),
        isTrue,
      );
      expect(
        filter.matches(item('yearly', cycle: Cycle.yearly), today),
        isFalse,
      );
    });

    test('an item with no source said matches the No source chip', () {
      const filter = UpcomingFilter(sourceIds: {UpcomingFilter.noSourceKey});
      expect(filter.matches(item('unsaid'), today), isTrue);
      expect(
        filter.matches(item('vcb', paymentSourceId: 'vcb'), today),
        isFalse,
      );
    });

    // "Right now" is the whole condition. The flag alone survives the day the
    // charge lands, so asking it without a date would keep an item on this chip
    // after the money had already gone.
    test('Free trials keeps only what is in a trial right now', () {
      final filter = UpcomingFilter(trialOnly: true);
      final trial = item('trial', inTrial: true);

      expect(filter.matches(trial, today), isTrue);
      expect(filter.matches(trial, d('2026-09-02')), isFalse);
      expect(filter.matches(item('paid'), today), isFalse);
    });

    // The point of the chip is finding the rows to fill in, so it keeps the
    // ones with nothing on them rather than the ones with something.
    test('No price keeps only the rows missing an amount', () {
      const filter = UpcomingFilter(noPriceOnly: true);
      expect(filter.matches(item('blank'), today), isTrue);
      expect(
        filter.matches(
          item('priced', amountMinor: 26000000, currency: 'VND'),
          today,
        ),
        isFalse,
      );
    });
  });

  group('toggling', () {
    test('a key goes on and comes back off', () {
      final on = UpcomingFilter.none.toggleCategory('PHONE');
      expect(on.categoryIds, {'PHONE'});
      expect(on.toggleCategory('PHONE'), UpcomingFilter.none);
    });

    test('toggling leaves the filter it was called on alone', () {
      const original = UpcomingFilter(categoryIds: {'PHONE'});
      original.toggleCategory('STREAMING');
      expect(original.categoryIds, {'PHONE'});
    });
  });

  group('pruning', () {
    // A source deleted in Settings would otherwise leave the list permanently
    // empty, filtered by an id with no chip on screen to explain it.
    test('a source that no longer exists is dropped', () {
      const filter = UpcomingFilter(sourceIds: {'vcb', 'gone'});
      expect(filter.prunedTo({'vcb'}).sourceIds, {'vcb'});
    });

    test('No source survives, having no row behind it to delete', () {
      const filter = UpcomingFilter(
        sourceIds: {UpcomingFilter.noSourceKey, 'gone'},
      );
      expect(filter.prunedTo(const {}).sourceIds, {UpcomingFilter.noSourceKey});
    });

    test('nothing to drop returns the same filter', () {
      const filter = UpcomingFilter(sourceIds: {'vcb'});
      expect(identical(filter.prunedTo({'vcb', 'momo'}), filter), isTrue);
    });
  });

  // Equality decides whether a change is written to storage at all, so two
  // filters that mean the same thing have to compare equal whatever order
  // their keys went in.
  test('two filters with the same keys are equal', () {
    const a = UpcomingFilter(categoryIds: {'A', 'B'});
    const b = UpcomingFilter(categoryIds: {'B', 'A'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
