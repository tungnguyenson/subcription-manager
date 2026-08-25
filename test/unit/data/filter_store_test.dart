import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/domain/upcoming_filter.dart';

void main() {
  late SubdockDatabase db;
  late FilterStore store;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    store = FilterStore(db);
  });

  tearDown(() => db.close());

  test('nothing stored reads back as no filter', () async {
    expect(await store.read(), UpcomingFilter.none);
  });

  test('every group survives the round trip', () async {
    const filter = UpcomingFilter(
      categoryIds: {'PHONE', 'STREAMING'},
      cycleKeys: {'MONTHLY', UpcomingFilter.onceKey},
      sourceIds: {'vcb', UpcomingFilter.noSourceKey},
      trialOnly: true,
      noPriceOnly: true,
      mutedOnly: true,
    );

    await store.save(filter);
    expect(await store.read(), filter);
  });

  test('saving again replaces rather than adding a second row', () async {
    await store.save(const UpcomingFilter(categoryIds: {'PHONE'}));
    await store.save(const UpcomingFilter(categoryIds: {'STREAMING'}));

    expect(
      await store.read(),
      const UpcomingFilter(categoryIds: {'STREAMING'}),
    );
  });

  test(
    'clearing is a value that is stored, not a row that is missing',
    () async {
      await store.save(const UpcomingFilter(categoryIds: {'PHONE'}));
      await store.save(UpcomingFilter.none);

      expect(await store.read(), UpcomingFilter.none);
    },
  );

  // The worst outcome of a bad value here is a longer list than the user left
  // behind. The worst outcome of throwing is an app that cannot open.
  group('a row this build cannot read', () {
    test('is not JSON at all', () {
      expect(FilterStore.decode('not json'), UpcomingFilter.none);
    });

    test('is JSON of the wrong shape', () {
      expect(FilterStore.decode('[1,2,3]'), UpcomingFilter.none);
    });

    test('has a group holding something other than strings', () {
      expect(
        FilterStore.decode('{"cat": [1, "PHONE", null]}'),
        const UpcomingFilter(categoryIds: {'PHONE'}),
      );
    });

    test('has a flag that is not a boolean', () {
      expect(FilterStore.decode('{"trial": "yes"}'), UpcomingFilter.none);
    });
  });
}
