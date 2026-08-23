import 'package:flutter_test/flutter_test.dart';

import 'package:subdock/ui/widgets/category_glyphs.dart';
import 'package:subdock/ui/widgets/service_mark.dart';
import 'package:subdock/ui/widgets/service_marks.data.dart';

void main() {
  group('detection', () {
    test('a known service is recognised inside a longer name', () {
      expect(SubdockMarks.detectKey('Netflix Premium'), 'netflix');
      expect(SubdockMarks.detectKey('Claude Pro'), 'claude');
    });

    // The catalog covers global brands; a Vietnamese household bill is typed
    // by hand and is the case a keyword rule has to earn its keep on.
    test('Vietnamese wording is recognised too', () {
      expect(SubdockMarks.detectKey('Tiền điện tháng 9'), 'power');
      expect(SubdockMarks.detectKey('Bảo hiểm xe'), 'vehicle');
      expect(SubdockMarks.detectKey('Hộ chiếu'), 'passport');
    });

    // Typing without diacritics is normal on a hurried phone keyboard, and it
    // must not silently drop the row back to a letter.
    test('the same wording without diacritics is recognised', () {
      expect(SubdockMarks.detectKey('Tien dien thang 9'), 'power');
      expect(SubdockMarks.detectKey('Ho chieu'), 'passport');
    });

    // A more specific phrase is listed above the word it contains.
    test('a longer phrase beats the word inside it', () {
      expect(SubdockMarks.detectKey('Visa card'), 'card');
      expect(SubdockMarks.detectKey('Visa Hàn Quốc'), 'passport');
      expect(SubdockMarks.detectKey('Internet Viettel'), 'router');
      expect(SubdockMarks.detectKey('SIM Viettel'), 'sim');
    });

    // A local brand keeps its own colour even though the shape is shared with
    // every other line of its kind -- that colour is the only thing saying
    // whose line it is.
    test('a local brand carries its colour, a household bill does not', () {
      expect(
        SubdockMarks.detect('SIM Viettel'),
        isA<GlyphSpec>()
            .having((s) => s.glyph, 'glyph', CategoryGlyph.sim)
            .having((s) => s.brandColour, 'brandColour', 0xFFEE0033),
      );
      expect(
        SubdockMarks.detect('Tiền nước'),
        isA<GlyphSpec>()
            .having((s) => s.glyph, 'glyph', CategoryGlyph.water)
            .having((s) => s.brandColour, 'brandColour', isNull),
      );
    });

    // A wrong mark on every row is worse than a letter on some of them,
    // because a wrong mark is read before the name is.
    test('an unrecognised name gets nothing rather than a guess', () {
      expect(SubdockMarks.detectKey('Quỹ lớp con'), isNull);
    });
  });

  // The key is what gets persisted, so every key the detector can hand back
  // has to still name something after a refactor, and has to be offerable in
  // the gallery the user overrides it from.
  test('every key the detector returns is pickable and resolves', () {
    for (final name in const [
      'Netflix',
      'Tiền điện',
      'Hộ chiếu',
      'Visa card',
      'Bảo hiểm',
      'SIM Viettel',
      'Xbox Game Pass',
    ]) {
      final key = SubdockMarks.detectKey(name);
      expect(key, isNotNull, reason: name);
      expect(SubdockMarks.pickable, contains(key), reason: name);
      expect(SubdockMarks.forKey(key!), isNotNull, reason: name);
    }
  });

  test('brand keys and glyph names cannot collide', () {
    final glyphNames = {for (final g in CategoryGlyph.values) g.name};
    expect(glyphNames.intersection(brandMarks.keys.toSet()), isEmpty);
  });

  test('an unknown key resolves to nothing rather than crashing', () {
    expect(SubdockMarks.forKey('not_a_mark'), isNull);
  });
}
