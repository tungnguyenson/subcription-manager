import 'package:drift/drift.dart';

import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';

import 'database.dart';
import 'mappers.dart';

/// The single way the rest of the app reaches storage.
///
/// Reads come back as [Stream] so the UI can listen directly and drift re-emits
/// whenever a write touches a table the query reads. Writes are [Future]s.
///
/// Reads use the hand-written SQL in `tables.drift` because their ordering is
/// part of the contract. Writes deliberately use drift's typed Dart API
/// instead: the generated helper for the item upsert takes 23 positional
/// arguments, thirteen of them `String`, so transposing `expiresOn` and
/// `anchorDate` would compile cleanly and silently corrupt every row. Named
/// companion fields make that transposition a compile error.
class ItemRepository {
  final SubdockDatabase _db;

  ItemRepository(this._db);

  // ---- categories ----

  Stream<List<Category>> observeCategories() => _db
      .selectAllCategories()
      .watch()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  Future<List<Category>> allCategories() async =>
      (await _db.selectAllCategories().get())
          .map((r) => r.toDomain())
          .toList(growable: false);

  Future<void> upsertCategory(Category category) => _db
      .into(_db.categoryRow)
      .insert(category.toCompanion(), mode: InsertMode.insertOrReplace);

  /// Moves every item off [id] and onto [onto], then forgets the shelf.
  ///
  /// One transaction because the two halves are one decision. Halfway through
  /// is a database where the foreign key points at a row that is gone, and the
  /// app opens on a list that cannot say where anything lives.
  Future<void> deleteCategory(String id, {required String onto}) =>
      _db.transaction(() async {
        await (_db.update(_db.itemRow)..where((t) => t.category.equals(id)))
            .write(ItemRowCompanion(category: Value(onto)));
        await (_db.delete(_db.categoryRow)..where((t) => t.id.equals(id))).go();
      });

  /// Writes a whole new order in one transaction, so no redraw ever sees two
  /// shelves claiming the same position.
  Future<void> reorderCategories(List<String> idsInOrder) =>
      _db.transaction(() async {
        for (var i = 0; i < idsInOrder.length; i++) {
          await (_db.update(_db.categoryRow)
                ..where((t) => t.id.equals(idsInOrder[i])))
              .write(CategoryRowCompanion(sortOrder: Value(i)));
        }
      });

  // ---- items ----

  Stream<List<TrackedItem>> observeAll() => _db.selectAll().watch().map(
    (rows) => rows.map((r) => r.toDomain()).toList(),
  );

  Stream<List<TrackedItem>> observeActive() => _db.selectActive().watch().map(
    (rows) => rows.map((r) => r.toDomain()).toList(),
  );

  Stream<TrackedItem?> observeById(String id) =>
      _db.selectById(id).watchSingleOrNull().map((row) => row?.toDomain());

  Future<TrackedItem?> findById(String id) async =>
      (await _db.selectById(id).getSingleOrNull())?.toDomain();

  Future<void> upsert(TrackedItem item, int createdAtEpochSeconds) {
    return _db
        .into(_db.itemRow)
        .insert(
          ItemRowCompanion(
            id: Value(item.id),
            name: Value(item.name),
            category: Value(item.categoryId),
            iconName: Value(item.iconName),
            expiresOn: Value(item.expiresOn.toString()),
            actByOffsetDays: Value(item.actByOffsetDays),
            anchorDate: Value(item.anchorDate.toString()),
            cycle: Value(item.cycle?.wireName),
            repeatCount: Value(item.repeatCount),
            amountMinor: Value(item.amountMinor),
            currency: Value(item.currency),
            actionUrl: Value(item.actionUrl),
            actionLabel: Value(item.actionLabel),
            note: Value(item.note),
            leadDays: Value(encodeLeadDays(item.leadDays)),
            remindAt: Value(item.remindAt.toString()),
            nagAfterDue: Value(item.nagAfterDue.wireName),
            verifyEveryDays: Value(item.verifyEveryDays),
            lastVerifiedAt: Value(item.lastVerifiedAt?.toString()),
            dateSource: Value(item.dateSource.wireName),
            snoozedUntil: Value(item.snoozedUntil?.toString()),
            state: Value(item.state.wireName),
            purchaseChannel: Value(item.purchaseChannel.wireName),
            trialStart: Value(item.trialStart?.toString()),
            paymentSourceId: Value(item.paymentSourceId),
            paused: Value(item.paused),
            yearlyChoice: Value(item.yearlyChoice.wireName),
            createdAt: Value(createdAtEpochSeconds),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> setState(String id, ItemState state) async {
    await (_db.update(_db.itemRow)..where((t) => t.id.equals(id))).write(
      ItemRowCompanion(state: Value(state.wireName)),
    );
  }

  /// Records a new expiry together with where it came from. Provenance is not
  /// optional: a date the user confirmed with their provider and one they typed
  /// from memory must not look alike downstream.
  Future<void> setExpiry(
    String id,
    LocalDate expiresOn,
    DateSource source,
  ) async {
    await (_db.update(_db.itemRow)..where((t) => t.id.equals(id))).write(
      ItemRowCompanion(
        expiresOn: Value(expiresOn.toString()),
        dateSource: Value(source.wireName),
      ),
    );
  }

  Future<void> markVerified(String id, LocalDate on) async {
    await (_db.update(_db.itemRow)..where((t) => t.id.equals(id))).write(
      ItemRowCompanion(lastVerifiedAt: Value(on.toString())),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.itemRow)..where((t) => t.id.equals(id))).go();
  }

  // ---- payment sources ----

  Stream<List<PaymentSource>> observeSources() => _db
      .selectAllSources()
      .watch()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  Future<void> upsertSource(PaymentSource source, int createdAtEpochSeconds) {
    return _db
        .into(_db.paymentSourceRow)
        .insert(
          PaymentSourceRowCompanion(
            id: Value(source.id),
            name: Value(source.name),
            glyph: Value(source.glyph.wireName),
            createdAt: Value(createdAtEpochSeconds),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Forgets a source. Every item that pointed at it goes back to "not said".
  ///
  /// The items are not touched here — `ON DELETE SET NULL` in the schema does
  /// it, which is the only way it stays true for a write that comes from
  /// anywhere else too. It needs `PRAGMA foreign_keys = ON`, which `beforeOpen`
  /// sets on every connection.
  Future<void> deleteSource(String id) async {
    await (_db.delete(
      _db.paymentSourceRow,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Turns an item's reminders off, or back on. See [TrackedItem.paused].
  Future<void> setPaused(String id, bool paused) async {
    await (_db.update(_db.itemRow)..where((t) => t.id.equals(id))).write(
      ItemRowCompanion(paused: Value(paused)),
    );
  }

  /// Records what the user said about the yearly suggestion for one item.
  Future<void> setYearlyChoice(String id, YearlyChoice choice) async {
    await (_db.update(_db.itemRow)..where((t) => t.id.equals(id))).write(
      ItemRowCompanion(yearlyChoice: Value(choice.wireName)),
    );
  }

  /// Un-skips every suggestion at once, behind the "N skipped — show again"
  /// line. A per-item undo would need the user to remember which ones they
  /// dismissed, which is the thing they dismissed them to stop doing.
  Future<void> clearSkippedYearly() async {
    await (_db.update(_db.itemRow)
          ..where((t) => t.yearlyChoice.equals(YearlyChoice.skipped.wireName)))
        .write(
          ItemRowCompanion(
            yearlyChoice: Value(YearlyChoice.undecided.wireName),
          ),
        );
  }

  // ---- history ----

  Stream<List<HandledEvent>> observeHistory(String itemId) => _db
      .selectForItem(itemId)
      .watch()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  Stream<List<HandledEvent>> observeHistorySince(LocalDate from) => _db
      .selectSince(from.toString())
      .watch()
      .map((rows) => rows.map((r) => r.toDomain()).toList());

  /// Writes one completed occurrence.
  ///
  /// `insertOrReplace` rather than an upsert on the primary key, because the
  /// row that must not duplicate is the *occurrence*: one item on one due date.
  /// That is a unique index, not the key, and only OR REPLACE honours it.
  ///
  /// The FX snapshot on the event is what makes "how much have I spent on this"
  /// stable: history reads the stored figure and never recomputes it.
  Future<void> recordHandled(HandledEvent event) {
    return _db
        .into(_db.handledEventRow)
        .insert(
          HandledEventRowCompanion(
            id: Value(event.id),
            itemId: Value(event.itemId),
            handledAt: Value(event.handledAtEpochSeconds),
            forDueDate: Value(event.forDueDate.toString()),
            amountMinor: Value(event.amountMinor),
            currency: Value(event.currency),
            fxRateScaled: Value(event.fxRateScaled),
            fxRateScale: Value(event.fxRateScale),
            fxRateDate: Value(event.fxRateDate?.toString()),
            fxSource: Value(event.fxSource),
            baseAmountMinor: Value(event.baseAmountMinor),
            actualChargedMinor: Value(event.actualChargedMinor),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// The user correcting a figure from their bank statement.
  Future<void> setActualCharged(String eventId, int minor) async {
    await (_db.update(_db.handledEventRow)..where((t) => t.id.equals(eventId)))
        .write(HandledEventRowCompanion(actualChargedMinor: Value(minor)));
  }

  Future<T> transaction<T>(Future<T> Function() body) => _db.transaction(body);
}
