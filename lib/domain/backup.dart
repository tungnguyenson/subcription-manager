import 'dart:convert';

import 'package:meta/meta.dart';

import 'local_date.dart';
import 'model.dart';
import 'reminders.dart';

/// Everything the user typed, in one file they can keep.
///
/// This app has no account and no server, so the database file on the device is
/// the only copy of anything. Uninstalling the app deletes it, and iOS deletes
/// it without asking. Without this there is no answer to "my phone died" that
/// does not begin with restoring the whole device from a system backup.
///
/// Deliberately a copy of the *model*, not a dump of the SQLite file. A dump
/// would be exact and would also be unreadable by any build whose schema had
/// moved on, which is every future build. Reading a field that is not there
/// falls back to the same default a new item gets, so a file written months ago
/// still restores into a newer app -- the same forgiving-decode rule the row
/// mappers already follow.
@immutable
class Backup {
  /// Marks the file as this app's. Checked on import so a JSON file picked by
  /// mistake fails with a sentence rather than an exception.
  static const String magic = 'subdock.backup';

  /// The format's own version, not the database schema's.
  ///
  /// Bumped only when the shape here changes in a way an older reader would
  /// get wrong. Adding a field does not count: an older reader that has never
  /// heard of it skips it, and a newer reader that does not find it uses its
  /// default.
  static const int version = 1;

  final List<Category> categories;
  final List<PaymentSource> sources;
  final List<TrackedItem> items;
  final List<HandledEvent> history;

  /// The two app-wide reminder defaults, carried as their own fields rather
  /// than as an [AppSettings]: that class lives in the data layer beside the
  /// store that reads it, and this file has to stay pure Dart so the format is
  /// testable without a database.
  final List<int> defaultLeadDays;
  final LocalTime remindAt;

  /// When the file was written, as an ISO-8601 instant in UTC.
  ///
  /// For the person reading a folder of these, not for the app: nothing in the
  /// import path branches on it. Two backups of the same phone are otherwise
  /// indistinguishable, and the whole point of keeping one is knowing which is
  /// the recent one.
  final String exportedAt;

  /// The creation timestamps, which the domain models do not carry.
  ///
  /// Kept beside the lists rather than folded into them: [PaymentSource] has no
  /// field for this and does not want one -- nothing on screen shows when a
  /// card was added -- but it decides the order sources are listed in, so
  /// dropping it would shuffle the user's list on restore.
  final Map<String, int> createdAt;

  const Backup({
    required this.categories,
    required this.sources,
    required this.items,
    required this.history,
    this.defaultLeadDays = const [3, 0],
    this.remindAt = Reminders.defaultRemindAt,
    required this.exportedAt,
    this.createdAt = const {},
  });

  int createdAtFor(String id, int fallback) => createdAt[id] ?? fallback;

  /// What the file says on the tin, for the confirmation the import shows.
  String get summary {
    final parts = <String>[
      _plural(items.length, 'item'),
      _plural(history.length, 'payment'),
    ];
    if (sources.isNotEmpty) {
      parts.add(_plural(sources.length, 'payment source'));
    }
    return parts.join(', ');
  }

  static String _plural(int n, String noun) =>
      n == 1 ? '1 $noun' : '$n ${noun}s';
}

/// Raised when a file cannot be read as a backup.
///
/// Carries a sentence meant for the user rather than a code. There is exactly
/// one place this surfaces and it is a snackbar, so a message the app has to
/// translate into English later is a message written twice.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Turns a [Backup] into text and back.
///
/// JSON rather than the SQLite file itself, so that a user who opens what they
/// saved can see their own subscriptions in it. A backup nobody can read is one
/// nobody checks, and an unchecked backup is discovered to be empty on the day
/// it is needed.
abstract final class BackupCodec {
  /// Indented, because a person may well open this in a text editor. The file
  /// is a few tens of kilobytes at any realistic list size, so the whitespace
  /// costs nothing worth counting.
  static String encode(Backup backup) =>
      const JsonEncoder.withIndent('  ').convert(toJson(backup));

  static Backup decode(String text) {
    final Object? parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException('That file is not a Subdock backup.');
    }

    if (parsed is! Map<String, dynamic>) {
      throw const BackupFormatException('That file is not a Subdock backup.');
    }
    if (parsed['format'] != Backup.magic) {
      throw const BackupFormatException('That file is not a Subdock backup.');
    }

    // Only a *newer* format is refused. An older one is the normal case for a
    // backup and is handled by every field falling back to its default.
    final version = _int(parsed['version']) ?? 0;
    if (version > Backup.version) {
      throw const BackupFormatException(
        'That backup was written by a newer version of Subdock.',
      );
    }

    return Backup(
      categories: _list(parsed['categories']).map(_category).toList(),
      sources: _list(parsed['paymentSources']).map(_source).toList(),
      items: _list(parsed['items']).map(_item).toList(),
      history: _list(parsed['history']).map(_event).toList(),
      defaultLeadDays: _leadDefaults(parsed['settings']),
      remindAt: _remindAt(parsed['settings']),
      exportedAt: _string(parsed['exportedAt']) ?? '',
      createdAt: {
        for (final row in [
          ..._list(parsed['paymentSources']),
          ..._list(parsed['items']),
        ])
          ?_string(row['id']): ?_int(row['createdAt']),
      },
    );
  }

  static Map<String, dynamic> toJson(Backup backup) => {
    'format': Backup.magic,
    'version': Backup.version,
    'exportedAt': backup.exportedAt,
    'settings': {
      'defaultLeadDays': backup.defaultLeadDays,
      'remindAt': backup.remindAt.toString(),
    },
    'categories': [for (final c in backup.categories) _categoryJson(c)],
    'paymentSources': [
      for (final s in backup.sources)
        {..._sourceJson(s), 'createdAt': backup.createdAtFor(s.id, 0)},
    ],
    'items': [
      for (final i in backup.items)
        {..._itemJson(i), 'createdAt': backup.createdAtFor(i.id, 0)},
    ],
    'history': [for (final e in backup.history) _eventJson(e)],
  };

  // ---- writing ----

  static Map<String, dynamic> _categoryJson(Category c) => {
    'id': c.id,
    'label': c.label,
    'iconName': c.iconName,
    'wording': c.wording.wireName,
    'nag': c.nag.wireName,
    'leadDays': c.leadDays,
    'verifyEveryDays': c.verifyEveryDays,
    'countsTowardSpend': c.countsTowardSpend,
    'builtIn': c.builtIn,
    'sortOrder': c.sortOrder,
  };

  static Map<String, dynamic> _sourceJson(PaymentSource s) => {
    'id': s.id,
    'name': s.name,
    'glyph': s.glyph.wireName,
  };

  static Map<String, dynamic> _itemJson(TrackedItem i) => {
    'id': i.id,
    'name': i.name,
    'categoryId': i.categoryId,
    'iconName': i.iconName,
    'expiresOn': i.expiresOn.toString(),
    'actByOffsetDays': i.actByOffsetDays,
    'anchorDate': i.anchorDate.toString(),
    'cycle': i.cycle?.wireName,
    'repeatCount': i.repeatCount,
    'amountMinor': i.amountMinor,
    'currency': i.currency,
    'actionUrl': i.actionUrl,
    'actionLabel': i.actionLabel,
    'note': i.note,
    'leadDays': i.leadDays,
    'remindAt': i.remindAt.toString(),
    'nagAfterDue': i.nagAfterDue.wireName,
    'verifyEveryDays': i.verifyEveryDays,
    'lastVerifiedAt': i.lastVerifiedAt?.toString(),
    'dateSource': i.dateSource.wireName,
    'snoozedUntil': i.snoozedUntil?.toString(),
    'state': i.state.wireName,
    'purchaseChannel': i.purchaseChannel.wireName,
    'inTrial': i.inTrial,
    'paymentSourceId': i.paymentSourceId,
    'paused': i.paused,
    'yearlyChoice': i.yearlyChoice.wireName,
  };

  static Map<String, dynamic> _eventJson(HandledEvent e) => {
    'id': e.id,
    'itemId': e.itemId,
    'handledAt': e.handledAtEpochSeconds,
    'forDueDate': e.forDueDate.toString(),
    'amountMinor': e.amountMinor,
    'currency': e.currency,
    'fxRateScaled': e.fxRateScaled,
    'fxRateScale': e.fxRateScale,
    'fxRateDate': e.fxRateDate?.toString(),
    'fxSource': e.fxSource,
    'baseAmountMinor': e.baseAmountMinor,
    'actualChargedMinor': e.actualChargedMinor,
  };

  // ---- reading ----
  //
  // Every enum goes through `enumFromWire` with the same fallback the row
  // mappers use, and every date through `tryParse`. A hand-edited file with one
  // bad line restores everything else rather than nothing: this is the copy
  // someone reaches for on a bad day, and refusing the whole file over a typo
  // in one note is the wrong trade.

  static Category _category(Map<String, dynamic> row) => Category(
    id: _required(row['id'], 'a category with no id'),
    label: _string(row['label']) ?? _required(row['id'], 'a category'),
    iconName: _string(row['iconName']),
    wording: enumFromWire(
      CategoryWording.values,
      _string(row['wording']),
      CategoryWording.due,
    ),
    nag: enumFromWire(NagPolicy.values, _string(row['nag']), NagPolicy.none),
    leadDays: _ints(row['leadDays']),
    verifyEveryDays: _int(row['verifyEveryDays']),
    countsTowardSpend: _bool(row['countsTowardSpend']) ?? true,
    builtIn: _bool(row['builtIn']) ?? false,
    sortOrder: _int(row['sortOrder']) ?? 0,
  );

  static PaymentSource _source(Map<String, dynamic> row) => PaymentSource(
    id: _required(row['id'], 'a payment source with no id'),
    name: _string(row['name']) ?? '',
    glyph: enumFromWire(
      SourceGlyph.values,
      _string(row['glyph']),
      SourceGlyph.card,
    ),
  );

  static TrackedItem _item(Map<String, dynamic> row) {
    final id = _required(row['id'], 'an item with no id');
    // The two dates the item cannot exist without. Everything else has a
    // sensible blank; a row with no expiry is not an item at all.
    final expiresOn = _date(row['expiresOn']);
    if (expiresOn == null) {
      throw BackupFormatException('An item has no date: ${row['name'] ?? id}.');
    }

    return TrackedItem(
      id: id,
      name: _string(row['name']) ?? '',
      categoryId: _string(row['categoryId']) ?? '',
      iconName: _string(row['iconName']),
      expiresOn: expiresOn,
      actByOffsetDays: _int(row['actByOffsetDays']) ?? 0,
      // Falls back to the expiry rather than to today. The anchor is what
      // every cycle counts from, and today would silently re-date the
      // series to the day of the restore.
      anchorDate: _date(row['anchorDate']) ?? expiresOn,
      cycle: CycleWire.fromWire(_string(row['cycle'])),
      repeatCount: _int(row['repeatCount']),
      amountMinor: _int(row['amountMinor']),
      currency: _string(row['currency']),
      actionUrl: _string(row['actionUrl']),
      actionLabel: _string(row['actionLabel']),
      note: _string(row['note']),
      leadDays: _ints(row['leadDays']),
      remindAt:
          LocalTime.tryParse(_string(row['remindAt']) ?? '') ??
          Reminders.defaultRemindAt,
      nagAfterDue: enumFromWire(
        NagPolicy.values,
        _string(row['nagAfterDue']),
        NagPolicy.none,
      ),
      verifyEveryDays: _int(row['verifyEveryDays']),
      lastVerifiedAt: _date(row['lastVerifiedAt']),
      dateSource: enumFromWire(
        DateSource.values,
        _string(row['dateSource']),
        DateSource.userEstimated,
      ),
      snoozedUntil: _date(row['snoozedUntil']),
      state: enumFromWire(
        ItemState.values,
        _string(row['state']),
        ItemState.active,
      ),
      purchaseChannel: enumFromWire(
        PurchaseChannel.values,
        _string(row['purchaseChannel']),
        PurchaseChannel.unknown,
      ),
      inTrial: _bool(row['inTrial']) ?? false,
      paymentSourceId: _string(row['paymentSourceId']),
      paused: _bool(row['paused']) ?? false,
      yearlyChoice: enumFromWire(
        YearlyChoice.values,
        _string(row['yearlyChoice']),
        YearlyChoice.undecided,
      ),
    );
  }

  static HandledEvent _event(Map<String, dynamic> row) {
    final forDueDate = _date(row['forDueDate']);
    if (forDueDate == null) {
      throw const BackupFormatException(
        'A recorded payment has no date on it.',
      );
    }
    return HandledEvent(
      id: _required(row['id'], 'a recorded payment with no id'),
      itemId: _required(row['itemId'], 'a recorded payment with no item'),
      handledAtEpochSeconds: _int(row['handledAt']) ?? 0,
      forDueDate: forDueDate,
      amountMinor: _int(row['amountMinor']),
      currency: _string(row['currency']),
      fxRateScaled: _int(row['fxRateScaled']),
      fxRateScale: _int(row['fxRateScale']),
      fxRateDate: _date(row['fxRateDate']),
      fxSource: _string(row['fxSource']),
      baseAmountMinor: _int(row['baseAmountMinor']),
      actualChargedMinor: _int(row['actualChargedMinor']),
    );
  }

  /// An empty ladder is read as "not in the file" rather than as "remind me
  /// never". The switches that produce it cannot all be off in the app, so an
  /// empty list here is a file missing the key, and restoring silence is worse
  /// than restoring the default.
  static List<int> _leadDefaults(Object? raw) {
    const fallback = [3, 0];
    if (raw is! Map<String, dynamic>) return fallback;
    final leads = _ints(raw['defaultLeadDays']);
    return leads.isEmpty ? fallback : leads;
  }

  static LocalTime _remindAt(Object? raw) {
    if (raw is! Map<String, dynamic>) return Reminders.defaultRemindAt;
    return LocalTime.tryParse(_string(raw['remindAt']) ?? '') ??
        Reminders.defaultRemindAt;
  }

  // ---- coercion ----

  static List<Map<String, dynamic>> _list(Object? raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
      : const [];

  static String? _string(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  static int? _int(Object? raw) =>
      raw is int ? raw : (raw is num ? raw.toInt() : null);

  static bool? _bool(Object? raw) => raw is bool ? raw : null;

  static LocalDate? _date(Object? raw) {
    final text = _string(raw);
    return text == null ? null : LocalDate.tryParse(text);
  }

  static List<int> _ints(Object? raw) => raw is List
      ? raw.map(_int).whereType<int>().toList(growable: false)
      : const [];

  static String _required(Object? raw, String what) {
    final value = _string(raw);
    if (value == null) throw BackupFormatException('The file contains $what.');
    return value;
  }
}
