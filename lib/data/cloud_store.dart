import 'package:drift/drift.dart';

import 'database.dart';

/// Remembers which account the user attached the cloud backup to.
///
/// It exists so the app can answer "is Drive connected" **without asking
/// Google**. That sounds like a small saving and is not. The plugin's
/// so-called lightweight sign-in makes two calls on Android: the first only
/// looks at accounts that already authorized this app, and the second, which
/// runs whenever the first finds nothing, opens the one-tap sheet over any
/// Google account on the phone. Calling it at launch therefore puts a sign-in
/// prompt in front of somebody who has never asked for cloud backup, in an app
/// whose first promise is that it needs no account at all.
///
/// So the answer lives here instead. On launch the app reads one row out of
/// its own database and touches nothing else. Google is reached only from the
/// button the user pressed, and afterwards only for a silent token when there
/// is actually something to upload.
///
/// The address is stored rather than a bare flag because the screen has to
/// name it: somebody with two Google accounts has two different backups, and
/// no date tells them which one they are looking at.
///
/// Its own store rather than a field on `AppSettings`, the same as
/// [ThemeStore]: it is a record of something that happened, not a preference
/// about how the app behaves, and it must not travel in a backup. A list
/// restored onto a second phone belongs to whoever is holding that phone.
class CloudStore {
  static const String _key = 'cloud_account';

  final SubdockDatabase _db;

  CloudStore(this._db);

  /// The account attached, or null if the user has never connected one.
  ///
  /// Lenient, like every other read out of this table: an empty or half
  /// written row reads as "not connected", which costs one tap to fix and
  /// cannot break anything.
  Future<String?> read() async {
    final rows = await _db.selectAllSettings().get();
    for (final row in rows) {
      if (row.settingKey == _key) {
        return row.value.isEmpty ? null : row.value;
      }
    }
    return null;
  }

  Future<void> save(String account) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_key),
          value: Value(account),
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Forgets the account. The copy already in the user's Drive stays where it
  /// is; deleting somebody's backup because they turned a switch off is not a
  /// decision this app gets to make.
  Future<void> clear() => (_db.delete(
    _db.settingRow,
  )..where((t) => t.settingKey.equals(_key))).go();
}
