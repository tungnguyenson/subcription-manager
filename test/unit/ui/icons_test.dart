import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/ui/icons.dart';

void main() {
  group('detection', () {
    test('a known service is recognised inside a longer name', () {
      expect(SubdockIcons.detect('Netflix Premium'), 'movie');
      expect(SubdockIcons.detect('Claude Pro'), 'ai');
    });

    // The catalog covers global brands; a Vietnamese household bill is typed
    // by hand and is the case a keyword rule has to earn its keep on.
    test('Vietnamese wording is recognised too', () {
      expect(SubdockIcons.detect('Tiền điện tháng 9'), 'power');
      expect(SubdockIcons.detect('Bảo hiểm xe'), 'shield');
      expect(SubdockIcons.detect('Hộ chiếu'), 'passport');
    });

    // A more specific phrase is listed above the word it contains.
    test('a longer phrase beats the word inside it', () {
      expect(SubdockIcons.detect('Visa card'), 'card');
      expect(SubdockIcons.detect('Visa Hàn Quốc'), 'passport');
    });

    // A wrong icon on every row is worse than a letter on some of them,
    // because a wrong icon is read before the name is.
    test('an unrecognised name gets nothing rather than a guess', () {
      expect(SubdockIcons.detect('Quỹ lớp con'), isNull);
    });
  });

  // The key is what gets persisted. Storing the codepoint instead would tie
  // the database to a font version.
  test('every key the detector can return exists in the gallery', () {
    for (final name in const [
      'Netflix',
      'Tiền điện',
      'Hộ chiếu',
      'Visa card',
      'Bảo hiểm',
      'gym',
    ]) {
      final key = SubdockIcons.detect(name);
      expect(SubdockIcons.all, contains(key), reason: name);
    }
    expect(SubdockIcons.all, contains(SubdockIcons.fallback));
  });

  test('an unknown key resolves to nothing rather than crashing', () {
    expect(SubdockIcons.resolve('not_an_icon'), isNull);
    expect(SubdockIcons.resolve(null), isNull);
  });
}
