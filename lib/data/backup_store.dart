import 'package:subdock/domain/backup.dart';

import 'database.dart';
import 'item_repository.dart';
import 'mappers.dart';
import 'settings_store.dart';

/// Reads the whole database out as a [Backup], and writes one back in.
///
/// Its own class rather than two more methods on [ItemRepository], because
/// every other method there is about one table and these two are about all of
/// them at once. The restore in particular has to know the order tables
/// reference each other, which is knowledge no per-table method should carry.
class BackupStore {
  final SubdockDatabase _db;
  final ItemRepository _items;
  final SettingsStore _settings;

  BackupStore(this._db, this._items, this._settings);

  /// Everything, in one snapshot.
  ///
  /// Read inside a transaction so the file cannot catch a write half done --
  /// an item saved without the payment it was just marked for would restore as
  /// a list that disagrees with its own history.
  Future<Backup> read({DateTime? clock}) => _db.transaction(() async {
    final categories = await _db.selectAllCategories().get();
    final sources = await _db.selectAllSources().get();
    final items = await _db.selectAll().get();
    final history = await _db.select(_db.handledEventRow).get();
    final settings = await _settings.read();

    return Backup(
      categories: [for (final row in categories) row.toDomain()],
      sources: [for (final row in sources) row.toDomain()],
      items: [for (final row in items) row.toDomain()],
      history: [for (final row in history) row.toDomain()],
      defaultLeadDays: settings.defaultLeadDays,
      remindAt: settings.remindAt,
      exportedAt: (clock ?? DateTime.now()).toUtc().toIso8601String(),
      createdAt: {
        for (final row in sources) row.id: row.createdAt,
        for (final row in items) row.id: row.createdAt,
      },
    );
  });

  /// Replaces the contents of the database with [backup].
  ///
  /// Replace, not merge. This is the operation someone reaches for after
  /// losing a phone, and it has to produce the list they had, not that list
  /// mixed with whatever the fresh install had seeded. Merging by id would
  /// also leave any item added since the backup sitting in a list it was never
  /// part of, with no way to tell which those were.
  ///
  /// One transaction for all of it. A restore that stopped halfway would leave
  /// items pointing at categories that had not been written yet, which is a
  /// database the app cannot open a list from -- and the user's original data
  /// is already gone by then, so there is nothing to fall back to.
  Future<void> restore(Backup backup) => _db.transaction(() async {
    // Children first, then parents: `itemRow.category` references
    // `categoryRow`, and `handledEventRow.itemId` references `itemRow`.
    await _db.delete(_db.handledEventRow).go();
    await _db.delete(_db.itemRow).go();
    await _db.delete(_db.paymentSourceRow).go();
    await _db.delete(_db.categoryRow).go();

    // Parents first on the way back in, for the same reason.
    for (final category in backup.categories) {
      await _items.upsertCategory(category);
    }
    for (final source in backup.sources) {
      await _items.upsertSource(source, backup.createdAtFor(source.id, 0));
    }

    // A file hand-edited into naming a category that is not in it would fail
    // the foreign key and abort the whole restore. Landing those items on a
    // shelf that exists is better than refusing the file: the user can move
    // them afterwards, and cannot recover a restore that did nothing.
    final shelves = {for (final c in backup.categories) c.id};
    final fallback = backup.categories.isEmpty ? null : backup.categories.first;

    for (final item in backup.items) {
      final placed = shelves.contains(item.categoryId) || fallback == null
          ? item
          : item.copyWith(categoryId: fallback.id);
      await _items.upsert(placed, backup.createdAtFor(item.id, 0));
    }

    // After the items, since each event points at one. An event whose item is
    // missing is dropped rather than restored orphaned: nothing can display
    // it, and the foreign key would refuse it anyway.
    final restored = {for (final item in backup.items) item.id};
    for (final event in backup.history) {
      if (restored.contains(event.itemId)) {
        await _items.recordHandled(event);
      }
    }

    await _settings.save(
      AppSettings(
        defaultLeadDays: backup.defaultLeadDays,
        remindAt: backup.remindAt,
      ),
    );
  });

  /// The name the exported file is offered under.
  ///
  /// Dated, and dated in the local zone rather than UTC. The user picks between
  /// these in a file browser by the day they remember taking them, and a backup
  /// made at 1am in Vietnam that files itself under the previous day is a
  /// backup they will not find.
  static String fileNameFor(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = at.toLocal();
    return 'subdock-${local.year}-${two(local.month)}-${two(local.day)}'
        '-${two(local.hour)}${two(local.minute)}.json';
  }
}
