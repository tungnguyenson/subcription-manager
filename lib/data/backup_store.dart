import 'package:drift/drift.dart';

import 'package:subdock/domain/backup.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';

import 'database.dart';
import 'item_repository.dart';
import 'mappers.dart';
import 'settings_store.dart';

/// Where a copy went, or came from.
///
/// The two are recorded separately because they answer different questions and
/// fail in different ways. A file the user exported in May sits wherever they
/// put it whatever the app does afterwards; the copy in iCloud is only as
/// recent as the last write that landed. One date covering both would report
/// the newer of the two beside whichever row the reader happened to look at.
enum BackupChannel { file, cloud }

/// The last moment a copy existed on each channel.
///
/// Kept to the minute rather than to the day, because the cloud channel writes
/// by itself. A row reading `27/08/2026` beside a copy the app wrote four
/// minutes ago and one it wrote at breakfast say the same thing, and the user
/// checking this screen is asking which of the two they have. The file channel
/// keeps the same shape only so one record does not need two storage formats;
/// what it puts on screen is still a day, because a file the user exported in
/// May is a file from May whatever hour they saved it.
class LastBackups {
  /// The newest export the user took to a file.
  final LocalDateTime? fileAt;

  /// The newest write to the user's own cloud that landed.
  final LocalDateTime? cloudAt;

  /// The ids of the costly-to-rebuild items each copy actually contains.
  ///
  /// Ids rather than a count, and this is the whole point of them. A user who
  /// backs up five confirmed dates, deletes one and adds another still has a
  /// count of five, while one of those dates is in no copy anywhere. A count
  /// cannot see that; a set can.
  ///
  /// Only the costly ones are recorded. The set exists to answer "is anything
  /// expensive missing from every copy", and putting the whole list in it
  /// would grow a settings row without changing a single answer.
  ///
  /// Null and empty mean different things, and the difference decides whether
  /// the warning is allowed to speak. Null is a copy written by a build that
  /// did not keep this record, so what it holds is unknown; empty is a copy
  /// known to hold nothing costly. Collapsing the two would fire the warning
  /// at every existing install the moment it upgrades, over copies that are
  /// perfectly good.
  final Set<String>? fileCovered;
  final Set<String>? cloudCovered;

  const LastBackups({
    this.fileAt,
    this.cloudAt,
    this.fileCovered,
    this.cloudCovered,
  });

  static const none = LastBackups();

  LocalDate? get file => fileAt?.date;
  LocalDate? get cloud => cloudAt?.date;

  /// Whether any copy exists at all, which is what the warning turns on.
  bool get any => fileAt != null || cloudAt != null;

  /// Everything that sits in at least one copy.
  ///
  /// The union rather than the newest channel: a date written to a file in May
  /// is still in that file today, whatever the cloud has done since. Asking
  /// only the newest copy would warn about an item the user is holding in
  /// their hand.
  Set<String> get covered => {...?fileCovered, ...?cloudCovered};

  /// Whether every copy that exists has said what it holds.
  ///
  /// False only for a copy written before this record existed. While it is
  /// false the app cannot tell a missing date from a recorded one, so it says
  /// nothing rather than guessing, and the next write settles it.
  bool get coverageKnown =>
      (fileAt == null || fileCovered != null) &&
      (cloudAt == null || cloudCovered != null);
}

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
      defaultSourceId: settings.defaultSourceId,
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
  /// [from] is the channel the file came off, and is what gets stamped: a copy
  /// pulled out of iCloud says iCloud is up to date, not that a file exists on
  /// disk.
  Future<void> restore(
    Backup backup, {
    BackupChannel from = BackupChannel.file,
  }) => _db.transaction(() async {
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
        defaultSourceId: backup.defaultSourceId,
      ),
    );

    // The list on screen is now the file's list, so the date beside
    // `Last backup` has to be the file's date. Leaving the old one would say
    // this list is backed up as of a day it did not exist on, and clearing it
    // would say no copy exists while the user is holding one.
    final takenOn = DateTime.tryParse(backup.exportedAt);
    await (takenOn == null ? _clearSaved(from) : markSaved(takenOn, from));
  });

  /// The key the last backup's date lives under, in `settingRow`.
  ///
  /// Kept here rather than folded into [AppSettings], which says of itself that
  /// every value in it has to be worth a screen and that a preference nobody
  /// changes should have been a decision. This is neither: it is a record of
  /// something that happened, and the class that owns backups should own it.
  static const String _lastSavedKey = 'last_backup_on';

  /// The cloud's own date. A second key rather than a second table: the whole
  /// record is one date per channel, and the key the file already used stays
  /// what it was so an existing install keeps its date.
  static const String _lastCloudKey = 'last_cloud_backup_on';

  /// What each copy covered, beside the date it was taken.
  ///
  /// Separate keys rather than one row holding a date and a list, so an install
  /// written by a build that only knew the date keeps that date. A missing ids
  /// row reads as an empty set, and an empty set is the pessimistic answer: it
  /// says the copy covers nothing, so the warning speaks up until the next
  /// write records what it actually contains. Erring the other way would go
  /// quiet for someone whose copy is genuinely short.
  static const String _lastSavedIdsKey = 'last_backup_covered';
  static const String _lastCloudIdsKey = 'last_cloud_backup_covered';

  static String _keyFor(BackupChannel channel) => switch (channel) {
    BackupChannel.file => _lastSavedKey,
    BackupChannel.cloud => _lastCloudKey,
  };

  static String _idsKeyFor(BackupChannel channel) => switch (channel) {
    BackupChannel.file => _lastSavedIdsKey,
    BackupChannel.cloud => _lastCloudIdsKey,
  };

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
  Stream<LastBackups> observeLastSaved() =>
      _db.selectAllSettings().watch().map(_readLastSaved);

  Future<LastBackups> lastSaved() async =>
      _readLastSaved(await _db.selectAllSettings().get());

  /// Records that a file holding this list exists, as of [on].
  ///
  /// After an export, called only when the share sheet reports the file went
  /// somewhere. A user who opened the sheet and closed it again has no backup,
  /// and writing a date here would put something on screen that stands for
  /// nothing.
  /// The set of costly ids is read here rather than passed in, deliberately.
  /// An optional parameter is the shape that has already gone wrong twice in
  /// this repository: the call compiles without it, the copy is written, and
  /// the record quietly says the copy covers nothing. Reading the list inside
  /// means no caller can forget.
  Future<void> markSaved(
    DateTime at, [
    BackupChannel channel = BackupChannel.file,
  ]) => _db.transaction(() async {
    await _write(_keyFor(channel), _stamp(at));
    await _write(_idsKeyFor(channel), _joinIds(await costlyIds()));
  });

  Future<void> _write(String key, String value) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(settingKey: Value(key), value: Value(value)),
        mode: InsertMode.insertOrReplace,
      );

  /// The items in the database right now whose dates cost something to get.
  ///
  /// Reads through the domain model rather than testing columns, so this and
  /// the warning on screen apply one rule: [TrackedItem.isCostlyToRebuild].
  Future<Set<String>> costlyIds() async {
    final rows = await _db.selectAll().get();
    return {
      for (final row in rows)
        if (row.toDomain().isCostlyToRebuild) row.id,
    };
  }

  /// Ids are separated by newlines rather than commas, since an id is generated
  /// from a timestamp and can never contain one, and a newline survives being
  /// read back by a human staring at the settings table.
  static String _joinIds(Set<String> ids) => ids.join('\n');

  static Set<String> _splitIds(String text) =>
      text.split('\n').where((id) => id.isNotEmpty).toSet();

  /// Written in the device's own zone and without a `Z`, because it is read
  /// back as a wall clock. Storing UTC would put a copy written at 01:00 in
  /// Vietnam on the previous day's row, which is the same mistake
  /// [fileNameFor] already refuses to make.
  static String _stamp(DateTime at) => at.toLocal().toIso8601String();

  /// Forgets the date, for a restored file that does not carry one.
  Future<void> _clearSaved(BackupChannel channel) => _db.transaction(() async {
    // Both rows, together. A date without its set would read as a copy that
    // covers nothing, and a set without its date as a copy that never
    // happened; either half left behind describes a copy that does not exist.
    for (final key in [_keyFor(channel), _idsKeyFor(channel)]) {
      await (_db.delete(
        _db.settingRow,
      )..where((t) => t.settingKey.equals(key))).go();
    }
  });

  /// Falls back to null rather than throwing, the same as every other read out
  /// of this table. A corrupted value reads as "never backed up", which is the
  /// pessimistic answer and therefore the safe one.
  static LastBackups _readLastSaved(List<SettingRowData> rows) {
    LocalDateTime? file;
    LocalDateTime? cloud;
    Set<String>? fileCovered;
    Set<String>? cloudCovered;
    for (final row in rows) {
      if (row.settingKey == _lastSavedKey) file = _readStamp(row.value);
      if (row.settingKey == _lastCloudKey) cloud = _readStamp(row.value);
      if (row.settingKey == _lastSavedIdsKey) {
        fileCovered = _splitIds(row.value);
      }
      if (row.settingKey == _lastCloudIdsKey) {
        cloudCovered = _splitIds(row.value);
      }
    }
    return LastBackups(
      fileAt: file,
      cloudAt: cloud,
      fileCovered: fileCovered,
      cloudCovered: cloudCovered,
    );
  }

  /// Reads either shape. Installs from before this record kept the hour hold a
  /// bare `2026-08-27` under the same key, and that is a real date the user is
  /// entitled to keep seeing -- rejecting it would report `Never` to someone
  /// who has a copy. It reads back as midnight, which is the only hour the
  /// stored value can honestly claim.
  static LocalDateTime? _readStamp(String text) {
    final at = DateTime.tryParse(text);
    if (at == null) return null;
    final local = at.isUtc ? at.toLocal() : at;
    return LocalDateTime(
      LocalDate.fromDateTime(local),
      LocalTime(local.hour, local.minute),
    );
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
