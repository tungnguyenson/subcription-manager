import 'dart:convert';

import 'service_catalog.dart';

/// Parsing for the bundled service catalog.
///
/// Ships inside the binary so the app works with no network, and is shaped so a
/// newer copy can override it at runtime without an App Store release.
abstract final class BundledData {
  /// Lenient on unknown keys so a config written by a newer build does not make
  /// an older build refuse to start. Strict on missing required fields, because
  /// a half-parsed entry is worse than none: it would prefill the add form with
  /// a wrong kind and look exactly like a correct one.
  static CatalogBundle parseCatalog(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('catalog root must be an object');
    }

    final entries = decoded['entries'];
    if (entries is! List) {
      throw const FormatException('catalog is missing an "entries" list');
    }

    return CatalogBundle(
      schemaVersion: (decoded['schemaVersion'] as num?)?.toInt() ?? 0,
      generatedAt: decoded['generatedAt'] as String? ?? '',
      entries: entries
          .map((e) => CatalogEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
