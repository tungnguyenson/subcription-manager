import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

/// A known service, used to prefill the add form.
///
/// This is the highest-leverage fix for entry friction, and it beats the image
/// scanner on every axis that matters: deterministic, effectively perfect on a
/// hit, no network, no API key, no privacy exposure. Service names are a small
/// closed set of global brands, so a lookup table is enough; no model required.
///
/// Crucially it also carries a [category], so the add form never has to ask
/// the user to classify anything. See product-spec.md 4.2.
@immutable
class CatalogEntry {
  final String id;
  final String name;

  /// Lowercase strings the user might type. Matched as prefixes and substrings.
  final List<String> aliases;

  final Category category;
  final Cycle? defaultCycle;

  /// Indicative price in minor units. Shown as a suggestion, never as fact.
  final int? typicalAmountMinor;
  final String? currency;

  /// Opens the page where the subscription is actually cancelled.
  final String? cancelUrl;
  final String? noteVi;

  const CatalogEntry({
    required this.id,
    required this.name,
    this.aliases = const [],
    required this.category,
    this.defaultCycle,
    this.typicalAmountMinor,
    this.currency,
    this.cancelUrl,
    this.noteVi,
  });

  /// Throws [FormatException] on a malformed entry rather than filling in a
  /// guess. A half-parsed catalog row would prefill the add form with a wrong
  /// category, and the user has no way to tell it came from bad data.
  factory CatalogEntry.fromJson(Map<String, dynamic> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException(
          'catalog entry is missing "$key"',
          json.toString(),
        );
      }
      return value;
    }

    final categoryWire = required('category');
    final category = Category.values
        .where((c) => c.wireName == categoryWire)
        .firstOrNull;
    if (category == null) {
      throw FormatException(
        'unknown category "$categoryWire"',
        json.toString(),
      );
    }

    final cycleWire = json['defaultCycle'] as String?;
    final cycle = CycleWire.fromWire(cycleWire);
    if (cycleWire != null && cycle == null) {
      throw FormatException('unknown cycle "$cycleWire"', json.toString());
    }

    return CatalogEntry(
      id: required('id'),
      name: required('name'),
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      category: category,
      defaultCycle: cycle,
      typicalAmountMinor: (json['typicalAmountMinor'] as num?)?.toInt(),
      currency: json['currency'] as String?,
      cancelUrl: json['cancelUrl'] as String?,
      noteVi: json['noteVi'] as String?,
    );
  }
}

@immutable
class CatalogBundle {
  final int schemaVersion;
  final String generatedAt;
  final List<CatalogEntry> entries;

  const CatalogBundle({
    required this.schemaVersion,
    required this.generatedAt,
    required this.entries,
  });
}

/// Lookup over the bundled entries.
///
/// Matching is deliberately forgiving because the user is typing on a phone:
/// case-insensitive, diacritic-insensitive, prefix before substring.
class ServiceCatalog {
  final List<CatalogEntry> _entries;

  ServiceCatalog(List<CatalogEntry> entries)
    : _entries = List.unmodifiable(entries);

  List<CatalogEntry> all() => _entries;

  CatalogEntry? byId(String id) =>
      _entries.where((e) => e.id == id).firstOrNull;

  /// Type-ahead suggestions. Exact name matches first, then prefix matches,
  /// then substring matches, so typing "net" surfaces Netflix before
  /// Vietnamobile.
  List<CatalogEntry> search(String query, {int limit = 8}) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];

    final scored = <(CatalogEntry, int)>[];
    for (final entry in _entries) {
      final score = _score(entry, q);
      if (score != null) scored.add((entry, score));
    }

    scored.sort((a, b) {
      final byScore = a.$2.compareTo(b.$2);
      return byScore != 0 ? byScore : a.$1.name.compareTo(b.$1.name);
    });

    return scored.take(limit).map((e) => e.$1).toList(growable: false);
  }

  /// Lower is better. Null means no match at all.
  int? _score(CatalogEntry entry, String q) {
    final haystacks = [entry.name, ...entry.aliases].map(_normalize);
    if (haystacks.any((h) => h == q)) return 0;
    if (haystacks.any((h) => h.startsWith(q))) return 1;
    if (haystacks.any((h) => h.contains(q))) return 2;
    return null;
  }

  /// Strips Vietnamese diacritics and case so "viettel" matches "Viettel" and
  /// "dien" matches "điện".
  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      buffer.write(
        _foldMap[String.fromCharCode(rune)] ?? String.fromCharCode(rune),
      );
    }
    return buffer.toString().trim();
  }

  /// Built once from the same grouped source the Kotlin build used, expanded to
  /// a character map so folding is a single pass rather than seven regex
  /// rewrites of the whole string.
  static final Map<String, String> _foldMap = {
    for (final entry in const {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    }.entries)
      for (final accented in entry.value.split('')) accented: entry.key,
  };
}
