import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  late SubdockDatabase db;
  late ItemRepository repo;

  LocalDate d(String iso) => LocalDate.parse(iso);

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

  TrackedItem sampleItem({
    String id = 'netflix',
    String name = 'Netflix Premium',
    Category category = Category.subscription,
    String? iconName,
    ItemState state = ItemState.active,
  }) {
    return TrackedItem(
      id: id,
      name: name,
      category: category,
      iconName: iconName,
      expiresOn: d('2026-09-01'),
      anchorDate: d('2026-01-01'),
      cycle: Cycle.monthly,
      amountMinor: 260000,
      currency: 'VND',
      actionUrl: 'https://netflix.com/cancelplan',
      actionLabel: 'Hủy Netflix',
      state: state,
    );
  }

  test('an item round-trips through storage unchanged', () async {
    final item = sampleItem();
    await repo.upsert(item, 1755000000);

    final loaded = await repo.findById('netflix');
    expect(loaded, isNotNull);
    expect(loaded!.name, item.name);
    expect(loaded.category, item.category);
    expect(loaded.expiresOn, item.expiresOn);
    expect(loaded.anchorDate, item.anchorDate);
    expect(loaded.cycle, item.cycle);
    expect(loaded.amountMinor, item.amountMinor);
    expect(loaded.currency, item.currency);
    expect(loaded.actionUrl, item.actionUrl);
    expect(loaded.leadDays, item.leadDays);
    expect(loaded.remindAt, item.remindAt);
    expect(loaded.nagAfterDue, item.nagAfterDue);
  });

  test('a limited repeat count survives a round trip', () async {
    // Null and a number mean genuinely different things here — forever versus
    // six payments — so the absent case is asserted alongside the present one.
    await repo.upsert(
      sampleItem(id: 'course').copyWith(repeatCount: () => 6),
      1,
    );
    await repo.upsert(sampleItem(id: 'forever'), 1);

    expect((await repo.findById('course'))?.repeatCount, 6);
    expect((await repo.findById('forever'))?.repeatCount, isNull);
  });

  test('lead days survive as a list including the empty case', () async {
    await repo.upsert(
      sampleItem(id: 'a').copyWith(leadDays: [30, 14, 7, 3, 1, 0]),
      1,
    );
    await repo.upsert(sampleItem(id: 'b').copyWith(leadDays: []), 1);

    expect((await repo.findById('a'))?.leadDays, [30, 14, 7, 3, 1, 0]);
    expect((await repo.findById('b'))?.leadDays, isEmpty);
  });

  test('only active items appear in the active query', () async {
    await repo.upsert(sampleItem(id: 'live'), 1);
    await repo.upsert(sampleItem(id: 'gone', state: ItemState.archived), 1);

    expect((await repo.observeActive().first).map((e) => e.id), ['live']);
    expect((await repo.observeAll().first).length, 2);
  });

  test(
    'cancelled but still active is a distinct state, not a deletion',
    () async {
      await repo.upsert(sampleItem(), 1);
      await repo.setState('netflix', ItemState.cancelledStillActive);

      final loaded = await repo.findById('netflix');
      expect(loaded, isNotNull, reason: 'the row must still exist');
      expect(loaded!.state, ItemState.cancelledStillActive);
    },
  );

  test('recording a new expiry also records where it came from', () async {
    await repo.upsert(sampleItem(), 1);
    await repo.setExpiry('netflix', d('2026-10-01'), DateSource.userConfirmed);

    final loaded = await repo.findById('netflix');
    expect(loaded?.expiresOn, d('2026-10-01'));
    expect(loaded?.dateSource, DateSource.userConfirmed);
  });

  // SQLite does not enforce foreign keys unless the connection asks it to, so
  // this passing is evidence that `PRAGMA foreign_keys = ON` actually ran.
  test('deleting an item takes its history with it', () async {
    await repo.upsert(sampleItem(id: 'netflix'), 1);
    await repo.recordHandled(
      HandledEvent(
        id: 'e1',
        itemId: 'netflix',
        handledAtEpochSeconds: 1755000000,
        forDueDate: d('2026-08-01'),
      ),
    );
    await repo.delete('netflix');

    expect(await repo.observeHistory('netflix').first, isEmpty);
  });

  // A chosen icon is an override the app must never re-guess, so it has to
  // survive the round trip through storage.
  test('a chosen icon survives storage', () async {
    await repo.upsert(sampleItem(id: 'netflix', iconName: 'movie'), 1);
    expect((await repo.findById('netflix'))?.iconName, 'movie');
  });

  test('history stores the FX snapshot so past totals never move', () async {
    await repo.upsert(sampleItem(id: 'claude', name: 'Claude'), 1);
    await repo.recordHandled(
      HandledEvent(
        id: 'e1',
        itemId: 'claude',
        handledAtEpochSeconds: 1755000000,
        forDueDate: d('2026-08-01'),
        amountMinor: 2000,
        currency: 'USD',
        fxRateScaled: 260460000,
        fxRateScale: 4,
        fxRateDate: d('2026-08-01'),
        fxSource: 'bundled',
        baseAmountMinor: 520920,
      ),
    );

    final event = (await repo.observeHistory('claude').first).single;
    expect(event.baseAmountMinor, 520920);
    expect(event.fxSource, 'bundled');
    expect(event.fxRateDate, d('2026-08-01'));
  });

  // The unique index is on (itemId, forDueDate), not on the primary key, so a
  // second event with a different id but the same occurrence must replace the
  // first rather than sit beside it.
  test('one occurrence cannot be recorded twice', () async {
    await repo.upsert(sampleItem(), 1);
    final event = HandledEvent(
      id: 'e1',
      itemId: 'netflix',
      handledAtEpochSeconds: 1,
      forDueDate: d('2026-08-01'),
    );
    await repo.recordHandled(event);
    await repo.recordHandled(event.copyWith(id: 'e2'));

    expect((await repo.observeHistory('netflix').first).length, 1);
  });

  test('the user can correct a figure from their bank statement', () async {
    await repo.upsert(sampleItem(id: 'claude'), 1);
    await repo.recordHandled(
      HandledEvent(
        id: 'e1',
        itemId: 'claude',
        handledAtEpochSeconds: 1,
        forDueDate: d('2026-08-01'),
        baseAmountMinor: 520920,
      ),
    );
    // The bank's foreign-currency fee makes the computed figure structurally low.
    await repo.setActualCharged('e1', 532745);

    expect(
      (await repo.observeHistory('claude').first).single.actualChargedMinor,
      532745,
    );
  });

  test('deleting an item removes its history', () async {
    await repo.upsert(sampleItem(), 1);
    await repo.recordHandled(
      HandledEvent(
        id: 'e1',
        itemId: 'netflix',
        handledAtEpochSeconds: 1,
        forDueDate: d('2026-08-01'),
      ),
    );
    await repo.delete('netflix');

    expect(await repo.observeHistory('netflix').first, isEmpty);
  });

  test('marking verified records the date the user last checked', () async {
    await repo.upsert(
      sampleItem(id: 'sim', category: Category.subscription),
      1,
    );
    await repo.markVerified('sim', d('2026-08-15'));

    expect((await repo.findById('sim'))?.lastVerifiedAt, d('2026-08-15'));
  });

  // Storage must not upgrade the trust level of a value it cannot read.
  test('an unknown enum falls back to the least trusted value', () async {
    await repo.upsert(sampleItem(), 1);
    await db.customStatement(
      "UPDATE itemRow SET dateSource = 'FROM_A_NEWER_BUILD' WHERE id = 'netflix'",
    );

    expect(
      (await repo.findById('netflix'))?.dateSource,
      DateSource.userEstimated,
    );
  });
}
