import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:subdock/domain/upcoming_filter.dart';

import 'database.dart';

/// Remembers what the Upcoming list is filtered to, between launches.
///
/// Its own store rather than a field on [AppSettings], because it is not a
/// preference. A preference is a decision the user made about how the app
/// should behave; this is the state of one screen, and the only reason it is
/// written down at all is that the app being killed in the background must not
/// silently change what the home screen shows. A filter that vanishes on
/// relaunch is a list that quietly grew, which is the same failure as a list
/// that quietly shrank.
///
/// Both directions are lenient. A row written by a newer build, or half
/// overwritten, reads back as "no filter" -- the worst outcome of that is a
/// longer list than the user left behind, and the worst outcome of throwing
/// here is an app that cannot open.
class FilterStore {
  static const String _key = 'upcoming_filter';

  /// JSON rather than a delimited string. The values in here are ids the app
  /// generates and labels nobody escapes, and picking a separator they cannot
  /// contain is a bet this saves us from making.
  static const String _categories = 'cat';
  static const String _cycles = 'cycle';
  static const String _sources = 'src';
  static const String _trial = 'trial';
  static const String _noPrice = 'noPrice';
  static const String _muted = 'mutedOnly';

  final SubdockDatabase _db;

  FilterStore(this._db);

  Future<UpcomingFilter> read() async {
    final rows = await _db.selectAllSettings().get();
    for (final row in rows) {
      if (row.settingKey == _key) return decode(row.value);
    }
    return UpcomingFilter.none;
  }

  Future<void> save(UpcomingFilter filter) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(
          settingKey: const Value(_key),
          value: Value(encode(filter)),
        ),
        mode: InsertMode.insertOrReplace,
      );

  static String encode(UpcomingFilter filter) => jsonEncode({
    _categories: filter.categoryIds.toList(),
    _cycles: filter.cycleKeys.toList(),
    _sources: filter.sourceIds.toList(),
    _trial: filter.trialOnly,
    _noPrice: filter.noPriceOnly,
    _muted: filter.mutedOnly,
  });

  static UpcomingFilter decode(String? value) {
    if (value == null) return UpcomingFilter.none;

    final Object? parsed;
    try {
      parsed = jsonDecode(value);
    } on FormatException {
      return UpcomingFilter.none;
    }
    if (parsed is! Map) return UpcomingFilter.none;

    return UpcomingFilter(
      categoryIds: _strings(parsed[_categories]),
      cycleKeys: _strings(parsed[_cycles]),
      sourceIds: _strings(parsed[_sources]),
      trialOnly: parsed[_trial] == true,
      noPriceOnly: parsed[_noPrice] == true,
      mutedOnly: parsed[_muted] == true,
    );
  }

  /// Anything that is not a list of strings reads as an empty group, which is
  /// the value that constrains nothing.
  static Set<String> _strings(Object? value) => value is List
      ? {
          for (final entry in value)
            if (entry is String) entry,
        }
      : const {};
}
