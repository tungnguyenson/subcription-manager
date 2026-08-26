import 'package:drift/drift.dart';

import 'package:subdock/domain/backup.dart';
import 'package:subdock/domain/local_date.dart';

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

    // The list on screen is now the file's list, so the date beside
    // `Last backup` has to be the file's date. Leaving the old one would say
    // this list is backed up as of a day it did not exist on, and clearing it
    // would say no copy exists while the user is holding one.
    final takenOn = DateTime.tryParse(backup.exportedAt);
    await (takenOn == null
        ? _clearSaved()
        : markSaved(LocalDate.fromDateTime(takenOn.toLocal())));
  });

  /// The key the last backup's date lives under, in `settingRow`.
  ///
  /// Kept here rather than folded into [AppSettings], which says of itself that
  /// every value in it has to be worth a screen and that a preference nobody
  /// changes should have been a decision. This is neither: it is a record of
  /// something that happened, and the class that owns backups should own it.
  static const String _lastSavedKey = 'last_backup_on';

  /// The newest date on which a file existed holding this list, or null if
  /// there has never been one.
  ///
  /// Not "when the user last tapped Export". Restoring counts too, and it
  /// counts as *the restored file's* date rather than today: someone who has
  /// just pulled back a copy taken three months ago should read
  /// `Last backup — 25/05/2026` and know their file is three months stale.
  /// Stamping it today would tell them the opposite of the truth at the one
  /// moment they are thinking about backups.
  ///
  /// A stream so the Settings screen redraws the moment an export lands,
  /// without anyone having to remember to refresh it.
  Stream<LocalDate?> observeLastSaved() =>
      _db.selectAllSettings().watch().map(_readLastSaved);

  Future<LocalDate?> lastSaved() async =>
      _readLastSaved(await _db.selectAllSettings().get());

  /// Records that a file holding this list exists, as of [on].
  ///
  /// After an export, called only when the share sheet reports the file went
  /// somewhere. A user who opened the sheet and closed it again has no backup,
  /// and writing a date here would put something on screen that stands for
  /// nothing.
  Future<void> markSaved(LocalDate on) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_lastSavedKey),
          value: Value(on.toString()),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Forgets the date, for a restored file that does not carry one.
  Future<void> _clearSaved() => (_db.delete(
    _db.settingRow,
  )..where((t) => t.settingKey.equals(_lastSavedKey))).go();

  /// Falls back to null rather than throwing, the same as every other read out
  /// of this table. A corrupted value reads as "never backed up", which is the
  /// pessimistic answer and therefore the safe one.
  static LocalDate? _readLastSaved(List<SettingRowData> rows) {
    for (final row in rows) {
      if (row.settingKey == _lastSavedKey) return LocalDate.tryParse(row.value);
    }
    return null;
  }

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
