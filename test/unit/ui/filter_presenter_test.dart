import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/filter_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  final book = CategoryBook([
    const Category(id: 'PHONE', label: 'Phone', sortOrder: 0),
    const Category(id: 'STREAMING', label: 'Streaming', sortOrder: 1),
    const Category(id: 'INSURANCE', label: 'Insurance', sortOrder: 2),
  ]);

  TrackedItem item(
    String id, {
    String categoryId = 'STREAMING',
    Cycle? cycle,
    String? paymentSourceId,
    bool paused = false,
    ItemState state = ItemState.active,
  }) => TrackedItem(
    id: id,
    name: id,
    categoryId: categoryId,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-09-01'),
    cycle: cycle,
    paymentSourceId: paymentSourceId,
    paused: paused,
    state: state,
  );

  const vcb = PaymentSource(id: 'vcb', name: 'VCB 4412');
  const momo = PaymentSource(
    id: 'momo',
    name: 'Momo',
    glyph: SourceGlyph.wallet,
  );

  List<String> keys(List<FilterOption> options) =>
      options.map((o) => o.key).toList();

  group('which chips exist', () {
    test('only the shelves something actually sits on', () {
      final options = FilterPresenter.options([
        item('a', categoryId: 'STREAMING'),
        item('b', categoryId: 'PHONE'),
      ], book);

      expect(keys(options.categories), ['PHONE', 'STREAMING']);
    });

    test('shelves come in the order the user put them in', () {
      final options = FilterPresenter.options([
        item('a', categoryId: 'INSURANCE'),
        item('b', categoryId: 'PHONE'),
      ], book);

      expect(keys(options.categories), ['PHONE', 'INSURANCE']);
    });

    // A chip row that rebuilt itself when "Reminders off" was tapped would drop
    // chips the user had already picked, out from under their finger.
    test('a muted item still contributes its chips', () {
      final options = FilterPresenter.options([
        item('off', categoryId: 'PHONE', paused: true),
      ], book);

      expect(keys(options.categories), ['PHONE']);
    });

    test('an archived item contributes nothing', () {
      final options = FilterPresenter.options([
        item('gone', categoryId: 'PHONE', state: ItemState.archived),
      ], book);

      expect(options.categories, isEmpty);
    });

    test('cycles run short to long, with the one-off last', () {
      final options = FilterPresenter.options([
        item('once'),
        item('year', cycle: Cycle.yearly),
        item('week', cycle: Cycle.weekly),
        item('month', cycle: Cycle.monthly),
      ], book);

      expect(keys(options.cycles), [
        'WEEKLY',
        'MONTHLY',
        'YEARLY',
        UpcomingFilter.onceKey,
      ]);
      expect(options.cycles.last.label, 'Once');
    });

    test('a cycle nobody uses gets no chip', () {
      final options = FilterPresenter.options([
        item('month', cycle: Cycle.monthly),
      ], book);

      expect(keys(options.cycles), ['MONTHLY']);
    });

    // Unlike the other two groups: the source list is short, the user wrote it,
    // and "nothing is on this card" is a useful answer to get back.
    test('every payment source is offered, used or not', () {
      final options = FilterPresenter.options(
        [item('a', paymentSourceId: 'vcb')],
        book,
        sources: [vcb, momo],
      );

      expect(keys(options.sources), [
        'vcb',
        'momo',
        UpcomingFilter.noSourceKey,
      ]);
      expect(options.sources[1].glyph, SourceGlyph.wallet);
      expect(options.sources.last.isAbsence, isTrue);
    });

    test('No source is there even with no sources at all', () {
      final options = FilterPresenter.options([item('a')], book);
      expect(keys(options.sources), [UpcomingFilter.noSourceKey]);
    });
  });

  group('the summary line', () {
    final options = FilterPresenter.options(
      [
        item('a', categoryId: 'STREAMING', cycle: Cycle.monthly),
        item('b', categoryId: 'PHONE', cycle: Cycle.yearly),
        item('c', categoryId: 'INSURANCE'),
      ],
      book,
      sources: [vcb],
    );

    String line(UpcomingFilter filter, {int shown = 3, int total = 12}) =>
        FilterPresenter.summary(filter, options, shown: shown, total: total);

    test('leads with the counts', () {
      expect(
        line(const UpcomingFilter(categoryIds: {'STREAMING'})),
        '3 of 12 items · Streaming',
      );
    });

    test('one item is not "items"', () {
      expect(
        line(const UpcomingFilter(trialOnly: true), shown: 1, total: 1),
        startsWith('1 of 1 item ·'),
      );
    });

    test('groups are named in the order the sheet lists them', () {
      expect(
        line(
          const UpcomingFilter(
            categoryIds: {'PHONE'},
            cycleKeys: {'MONTHLY'},
            sourceIds: {'vcb'},
            mutedOnly: true,
          ),
        ),
        '3 of 12 items · Phone · Monthly · VCB 4412 · Reminders off',
      );
    });

    // Three names spelled out push the counts off the end of a one-line row,
    // and the counts are the part the sheet cannot tell the reader.
    test('three or more chips in a group are counted, not listed', () {
      expect(
        line(
          const UpcomingFilter(
            categoryIds: {'PHONE', 'STREAMING', 'INSURANCE'},
          ),
        ),
        '3 of 12 items · 3 types',
      );
    });

    test('a key whose chip has gone is not named', () {
      expect(
        line(const UpcomingFilter(categoryIds: {'DELETED'})),
        '3 of 12 items',
      );
    });
  });
}
