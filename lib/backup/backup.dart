import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:subdock/domain/model.dart';

/// Export and restore.
///
/// Ships in the first release, not as later polish. Losing hand-typed data is
/// the most common reason people abandon this category of app, and that is true
/// even of the ones that sync; an offline app with no account has strictly
/// worse odds. "There is no way to get my data out" is separately cited as an
/// uninstall reason. See product-spec.md section 11.2.
///
/// JSON is the restorable format. CSV is export-only, for spreadsheets.
@immutable
class BackupFile {
  /// Bumped to 3 when `kind` and `categoryId` were folded into one `category`
  /// and groups left the product. Older files still restore: a version-1 or -2
  /// item is read through [BackupItem.categoryFromJson], which maps the two
  /// old keys onto the five categories the same way the database migration
  /// does, and its `groups` array is ignored.
  static const int currentSchemaVersion = 3;

  final int schemaVersion;
  final String exportedAt;
  final List<BackupItem> items;
  final List<BackupEvent> history;

  const BackupFile({
    this.schemaVersion = currentSchemaVersion,
    required this.exportedAt,
    required this.items,
    required this.history,
  });

  BackupFile copyWith({List<BackupItem>? items}) => BackupFile(
    schemaVersion: schemaVersion,
    exportedAt: exportedAt,
    items: items ?? this.items,
    history: history,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt,
    'items': items.map((e) => e.toJson()).toList(),
    'history': history.map((e) => e.toJson()).toList(),
  };
}

@immutable
class BackupItem {
  final String id;
  final String name;
  final String category;
  final String? iconName;
  final String expiresOn;
  final int actByOffsetDays;
  final String anchorDate;
  final String? cycle;
  final int? repeatCount;
  final int? amountMinor;
  final String? currency;
  final String? actionUrl;
  final String? actionLabel;
  final String? note;
  final List<int> leadDays;
  final String remindAt;
  final String nagAfterDue;
  final int? verifyEveryDays;
  final String? lastVerifiedAt;
  final String dateSource;
  final String? snoozedUntil;
  final String state;

  const BackupItem({
    required this.id,
    required this.name,
    required this.category,
    this.iconName,
    required this.expiresOn,
    this.actByOffsetDays = 0,
    required this.anchorDate,
    this.cycle,
    this.repeatCount,
    this.amountMinor,
    this.currency,
    this.actionUrl,
    this.actionLabel,
    this.note,
    this.leadDays = const [],
    required this.remindAt,
    required this.nagAfterDue,
    this.verifyEveryDays,
    this.lastVerifiedAt,
    required this.dateSource,
    this.snoozedUntil,
    required this.state,
  });

  factory BackupItem.fromTrackedItem(TrackedItem item) => BackupItem(
    id: item.id,
    name: item.name,
    category: item.category.wireName,
    iconName: item.iconName,
    expiresOn: item.expiresOn.toString(),
    actByOffsetDays: item.actByOffsetDays,
    anchorDate: item.anchorDate.toString(),
    cycle: item.cycle?.wireName,
    repeatCount: item.repeatCount,
    amountMinor: item.amountMinor,
    currency: item.currency,
    actionUrl: item.actionUrl,
    actionLabel: item.actionLabel,
    note: item.note,
    leadDays: item.leadDays,
    remindAt: item.remindAt.toString(),
    nagAfterDue: item.nagAfterDue.wireName,
    verifyEveryDays: item.verifyEveryDays,
    lastVerifiedAt: item.lastVerifiedAt?.toString(),
    dateSource: item.dateSource.wireName,
    snoozedUntil: item.snoozedUntil?.toString(),
    state: item.state.wireName,
  );

  /// Reads the item's one category out of whatever the file happens to carry.
  ///
  /// A schema-3 file has `category` and is read as-is. A schema-1 or -2 file
  /// has `kind` plus an optional `categoryId`, and the two are folded here on
  /// exactly the terms the v2 -> v3 database migration uses. Restoring a file
  /// exported by an older build must not quietly reclassify everything in it.
  @visibleForTesting
  static String categoryFromJson(Map<String, dynamic> json) {
    final current = json['category'];
    if (current is String && current.isNotEmpty) return current;

    final kind = json['kind'] as String?;
    final legacyCategory = json['categoryId'] as String?;
    if (legacyCategory == 'insurance') return 'INSURANCE';
    if (kind == 'DOCUMENT') return 'DOCUMENT';
    if (kind == 'BILL') return 'BILL';
    if (legacyCategory == 'home_bills' || legacyCategory == 'loans') {
      return 'BILL';
    }
    if (kind == null) {
      throw const FormatException('item is missing "category"');
    }
    return 'SUBSCRIPTION';
  }

  factory BackupItem.fromJson(Map<String, dynamic> json) => BackupItem(
    id: _requireString(json, 'id'),
    name: _requireString(json, 'name'),
    category: categoryFromJson(json),
    iconName: json['iconName'] as String?,
    expiresOn: _requireString(json, 'expiresOn'),
    actByOffsetDays: (json['actByOffsetDays'] as num?)?.toInt() ?? 0,
    anchorDate: _requireString(json, 'anchorDate'),
    cycle: json['cycle'] as String?,
    repeatCount: (json['repeatCount'] as num?)?.toInt(),
    amountMinor: (json['amountMinor'] as num?)?.toInt(),
    currency: json['currency'] as String?,
    actionUrl: json['actionUrl'] as String?,
    actionLabel: json['actionLabel'] as String?,
    note: json['note'] as String?,
    leadDays: (json['leadDays'] as List<dynamic>? ?? const [])
        .map((e) => (e as num).toInt())
        .toList(growable: false),
    remindAt: _requireString(json, 'remindAt'),
    nagAfterDue: _requireString(json, 'nagAfterDue'),
    verifyEveryDays: (json['verifyEveryDays'] as num?)?.toInt(),
    lastVerifiedAt: json['lastVerifiedAt'] as String?,
    dateSource: _requireString(json, 'dateSource'),
    snoozedUntil: json['snoozedUntil'] as String?,
    state: _requireString(json, 'state'),
  );

  BackupItem copyWith({String? id, String? expiresOn}) => BackupItem(
    id: id ?? this.id,
    name: name,
    category: category,
    iconName: iconName,
    expiresOn: expiresOn ?? this.expiresOn,
    actByOffsetDays: actByOffsetDays,
    anchorDate: anchorDate,
    cycle: cycle,
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: currency,
    actionUrl: actionUrl,
    actionLabel: actionLabel,
    note: note,
    leadDays: leadDays,
    remindAt: remindAt,
    nagAfterDue: nagAfterDue,
    verifyEveryDays: verifyEveryDays,
    lastVerifiedAt: lastVerifiedAt,
    dateSource: dateSource,
    snoozedUntil: snoozedUntil,
    state: state,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'iconName': iconName,
    'expiresOn': expiresOn,
    'actByOffsetDays': actByOffsetDays,
    'anchorDate': anchorDate,
    'cycle': cycle,
    'repeatCount': repeatCount,
    'amountMinor': amountMinor,
    'currency': currency,
    'actionUrl': actionUrl,
    'actionLabel': actionLabel,
    'note': note,
    'leadDays': leadDays,
    'remindAt': remindAt,
    'nagAfterDue': nagAfterDue,
    'verifyEveryDays': verifyEveryDays,
    'lastVerifiedAt': lastVerifiedAt,
    'dateSource': dateSource,
    'snoozedUntil': snoozedUntil,
    'state': state,
  };
}

@immutable
class BackupEvent {
  final String id;
  final String itemId;
  final int handledAt;
  final String forDueDate;
  final int? amountMinor;
  final String? currency;
  final int? fxRateScaled;
  final int? fxRateScale;
  final String? fxRateDate;
  final String? fxSource;
  final int? baseAmountMinor;
  final int? actualChargedMinor;

  const BackupEvent({
    required this.id,
    required this.itemId,
    required this.handledAt,
    required this.forDueDate,
    this.amountMinor,
    this.currency,
    this.fxRateScaled,
    this.fxRateScale,
    this.fxRateDate,
    this.fxSource,
    this.baseAmountMinor,
    this.actualChargedMinor,
  });

  factory BackupEvent.fromHandledEvent(HandledEvent event) => BackupEvent(
    id: event.id,
    itemId: event.itemId,
    handledAt: event.handledAtEpochSeconds,
    forDueDate: event.forDueDate.toString(),
    amountMinor: event.amountMinor,
    currency: event.currency,
    fxRateScaled: event.fxRateScaled,
    fxRateScale: event.fxRateScale,
    fxRateDate: event.fxRateDate?.toString(),
    fxSource: event.fxSource,
    baseAmountMinor: event.baseAmountMinor,
    actualChargedMinor: event.actualChargedMinor,
  );

  factory BackupEvent.fromJson(Map<String, dynamic> json) => BackupEvent(
    id: _requireString(json, 'id'),
    itemId: _requireString(json, 'itemId'),
    handledAt:
        (json['handledAt'] as num?)?.toInt() ??
        (throw const FormatException('backup event is missing handledAt')),
    forDueDate: _requireString(json, 'forDueDate'),
    amountMinor: (json['amountMinor'] as num?)?.toInt(),
    currency: json['currency'] as String?,
    fxRateScaled: (json['fxRateScaled'] as num?)?.toInt(),
    fxRateScale: (json['fxRateScale'] as num?)?.toInt(),
    fxRateDate: json['fxRateDate'] as String?,
    fxSource: json['fxSource'] as String?,
    baseAmountMinor: (json['baseAmountMinor'] as num?)?.toInt(),
    actualChargedMinor: (json['actualChargedMinor'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'handledAt': handledAt,
    'forDueDate': forDueDate,
    'amountMinor': amountMinor,
    'currency': currency,
    'fxRateScaled': fxRateScaled,
    'fxRateScale': fxRateScale,
    'fxRateDate': fxRateDate,
    'fxSource': fxSource,
    'baseAmountMinor': baseAmountMinor,
    'actualChargedMinor': actualChargedMinor,
  };
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('backup record is missing "$key"', json.toString());
  }
  return value;
}

abstract final class Backup {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  static String encode(BackupFile file) => _encoder.convert(file.toJson());

  /// Returns the parsed file, or throws [FormatException].
  ///
  /// Unknown keys are ignored so a file written by a newer build still restores
  /// on an older one. A newer *schema version* is refused outright, because
  /// that is the case where the older build would drop data it cannot see.
  static BackupFile decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('backup file is not in the right shape');
    }

    final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt();
    if (schemaVersion == null) {
      throw const FormatException('backup file has no schemaVersion');
    }
    if (schemaVersion > BackupFile.currentSchemaVersion) {
      throw FormatException(
        'backup file is from a newer version ($schemaVersion) — update the app',
      );
    }

    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = decoded[key];
      if (raw is! List) {
        throw FormatException('backup file has no "$key" list');
      }
      return raw
          .map((e) => parse(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return BackupFile(
      schemaVersion: schemaVersion,
      exportedAt: _requireString(decoded, 'exportedAt'),
      items: parseList('items', BackupItem.fromJson),
      history: parseList('history', BackupEvent.fromJson),
    );
  }

  static BackupFile build(
    String exportedAt,
    List<TrackedItem> items,
    List<HandledEvent> history,
  ) => BackupFile(
    exportedAt: exportedAt,
    items: items.map(BackupItem.fromTrackedItem).toList(growable: false),
    history: history.map(BackupEvent.fromHandledEvent).toList(growable: false),
  );

  /// Spreadsheet export. One row per item.
  ///
  /// Money stays in minor units with the currency in its own column rather than
  /// being formatted: a spreadsheet would otherwise reinterpret "231.000" as a
  /// decimal and silently divide a Vietnamese amount by a thousand.
  static String toCsv(List<TrackedItem> items) {
    const header = [
      'id', 'name', 'category', //
      'expires_on', 'act_by_offset_days', 'anchor_date', 'cycle',
      'repeat_count', 'amount_minor', 'currency', 'state', 'date_source',
    ];

    final rows = items.map(
      (item) => [
        item.id,
        item.name,
        item.category.wireName,
        item.expiresOn.toString(),
        item.actByOffsetDays.toString(),
        item.anchorDate.toString(),
        item.cycle?.wireName ?? '',
        item.repeatCount?.toString() ?? '',
        item.amountMinor?.toString() ?? '',
        item.currency ?? '',
        item.state.wireName,
        item.dateSource.wireName,
      ],
    );

    return [
      header,
      ...rows,
    ].map((row) => row.map(_csvEscaped).join(',')).join('\n');
  }

  /// RFC 4180: wrap in quotes when the value contains a comma, quote or
  /// newline.
  static String _csvEscaped(String value) {
    final needsQuoting =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    return needsQuoting ? '"${value.replaceAll('"', '""')}"' : value;
  }
}
