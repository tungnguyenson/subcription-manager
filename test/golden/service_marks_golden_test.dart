import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/category_glyphs.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/service_mark.dart';
import 'package:subdock/ui/widgets/service_marks.data.dart';

/// The whole mark set, drawn once, in the tile the list actually uses.
///
/// A per-mark unit test can only say that a path parsed; it cannot say that the
/// Netflix mark looks like Netflix, or that the SIM glyph and the ID-card glyph
/// are still telling apart at 40px. Those are the two ways this can fail, and
/// both are visible in one image.
void main() {
  test('every brand mark parses to a non-empty path', () {
    expect(brandMarks, isNotEmpty);
    for (final MapEntry(key: name, value: mark) in brandMarks.entries) {
      final bounds = mark.toPath().getBounds();
      expect(bounds.isEmpty, isFalse, reason: '$name drew nothing');
      // Generated onto a 24-unit square, with a pixel of slack for the
      // rounding the generator does when it writes the coordinates out.
      expect(bounds.left, greaterThan(-1), reason: '$name overflows left');
      expect(bounds.top, greaterThan(-1), reason: '$name overflows top');
      expect(bounds.right, lessThan(BrandMark.grid + 1), reason: '$name right');
      expect(
        bounds.bottom,
        lessThan(BrandMark.grid + 1),
        reason: '$name bottom',
      );
    }
  });

  test('every catalog entry resolves to a mark, not to a letter', () {
    final raw = jsonDecode(File('assets/services.json').readAsStringSync());
    final entries = (raw as Map<String, dynamic>)['entries'] as List;

    final unmatched = <String>[];
    for (final entry in entries) {
      final name = (entry as Map<String, dynamic>)['name'] as String;
      if (SubdockMarks.detect(name) == null) unmatched.add(name);
    }

    // The letter tile is the fallback for what the user types, not for what the
    // app ships. Anything in the bundled catalog is a name the rules were
    // written against, so a miss here means a rule was dropped or reordered.
    expect(unmatched, isEmpty, reason: 'no mark for: ${unmatched.join(', ')}');
  });

  testWidgets('the mark sheet', (tester) async {
    final raw = jsonDecode(File('assets/services.json').readAsStringSync());
    final names = [
      for (final entry in (raw as Map<String, dynamic>)['entries'] as List)
        (entry as Map<String, dynamic>)['name'] as String,
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: SubdockColors.canvas,
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in names) ServiceTile(name, size: 40),
              // The glyphs no catalog name reaches, so a regression in one is
              // still caught: they are only in reach of names the user types.
              for (final glyph in CategoryGlyph.values)
                ServiceTile('', iconName: glyph.name, size: 40),
              // And the fallback itself.
              const ServiceTile('Quán cà phê', size: 40),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('service_marks.png'),
    );
  });
}
