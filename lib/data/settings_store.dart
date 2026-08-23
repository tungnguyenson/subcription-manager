import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import 'package:subdock/data/mappers.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/reminders.dart';

import 'database.dart';

/// The preferences that apply to the app rather than to one item.
///
/// Deliberately small. Every value here has to be worth a screen, and a
/// preference nobody changes is a preference that should have been a decision.
@immutable
class AppSettings {
  /// How many days before the date a new item is reminded, by default.
  ///
  /// A ladder rather than a single value: the design's Reminders screen offers
  /// three independent switches, and two of them being on at once is the
  /// normal case, not a conflict to resolve.
  final List<int> defaultLeadDays;

  /// What time of day every reminder is sent.
  final LocalTime remindAt;

  static const List<int> offeredLeads = [7, 3, 0];

  const AppSettings({
    this.defaultLeadDays = const [3, 0],
    this.remindAt = Reminders.defaultRemindAt,
  });

  AppSettings withLead(int lead, bool on) {
    final next = {...defaultLeadDays};
    if (on) {
      next.add(lead);
    } else {
      next.remove(lead);
    }
    // Sorted furthest-out first, which is the order they fire in.
    final sorted = next.toList()..sort((a, b) => b.compareTo(a));
    return AppSettings(defaultLeadDays: sorted, remindAt: remindAt);
  }

  AppSettings withRemindAt(LocalTime time) =>
      AppSettings(defaultLeadDays: defaultLeadDays, remindAt: time);
}

/// Reads and writes [AppSettings] as key-value rows.
///
/// Every read falls back to the default rather than throwing. A settings row
/// written by a newer build, or corrupted, must not stop the app from starting:
/// the worst outcome of a bad value here is a reminder at the wrong hour, and
/// the worst outcome of throwing is an app that cannot open.
class SettingsStore {
  static const String _leadDaysKey = 'default_lead_days';
  static const String _remindAtKey = 'remind_at';

  final SubdockDatabase _db;

  SettingsStore(this._db);

  Stream<AppSettings> observe() => _db.selectAllSettings().watch().map(_decode);

  Future<AppSettings> read() async =>
      _decode(await _db.selectAllSettings().get());

  Future<void> save(AppSettings settings) async {
    await _write(_leadDaysKey, encodeLeadDays(settings.defaultLeadDays));
    await _write(_remindAtKey, settings.remindAt.toString());
  }

  Future<void> _write(String key, String value) => _db
      .into(_db.settingRow)
      .insert(
        SettingRowCompanion(settingKey: Value(key), value: Value(value)),
        mode: InsertMode.insertOrReplace,
      );

  AppSettings _decode(List<SettingRowData> rows) {
    final map = {for (final row in rows) row.settingKey: row.value};

    final leads = map[_leadDaysKey];
    final at = map[_remindAtKey];

    return AppSettings(
      defaultLeadDays: leads == null
          ? const AppSettings().defaultLeadDays
          : decodeLeadDays(leads),
      remindAt:
          (at == null ? null : LocalTime.tryParse(at)) ??
          Reminders.defaultRemindAt,
    );
  }
}
