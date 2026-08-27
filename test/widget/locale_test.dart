import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/default_categories.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/screens/about_screen.dart';
import 'package:subdock/ui/theme.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  /// The app's own shape: the scope above [MaterialApp], which is above the
  /// Navigator. Returns the setter that swaps the language.
  Future<void Function(AppLocale)> host(
    WidgetTester tester,
    Widget home,
  ) async {
    var locale = AppLocale.en;
    late StateSetter rebuild;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return SubdockTheme(
            palette: SubdockPalette.light,
            locale: locale,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: buildSubdockTheme(),
              home: Scaffold(body: home),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    return (next) => rebuild(() => locale = next);
  }

  group('the language reaches what is already on screen', () {
    // The same mechanism the palette relies on, and the reason the two travel
    // in one scope: a route's page is built once and cached, so only the
    // inherited dependency `SubdockTheme.watch` registers reaches inside it. A
    // screen that forgets that line keeps the language it was opened in.
    testWidgets('a screen pushed before the change follows it too', (
      tester,
    ) async {
      final set = await host(tester, const SizedBox.shrink());

      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: AboutScreen(version: '1.0.0', buildNumber: '42'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);

      set(AppLocale.vi);
      await tester.pumpAndSettle();

      expect(find.text('About'), findsNothing);
      expect(find.text('Giới thiệu'), findsOneWidget);
    });
  });

  group('a shipped shelf name', () {
    // Translated at read time, never at seed time. The rows are written by a
    // migration, long before onboarding has asked which language to read in.
    test('follows the language while the user has not renamed it', () {
      final shelf = defaultCategories.firstWhere((c) => c.id == 'STREAMING');

      S.publish(AppLocale.en);
      expect(shelf.displayLabel, 'Streaming');

      S.publish(AppLocale.vi);
      expect(shelf.displayLabel, 'Xem phim');

      S.publish(AppLocale.en);
    });

    // The other half of the rule, and the important half: a category is a row
    // the user owns. The moment they type a name, that name is the name, in
    // either language.
    test('stops following it the moment the user types their own', () {
      const renamed = Category(
        id: 'STREAMING',
        label: 'Phim ảnh nhà tôi',
        builtIn: true,
        sortOrder: 0,
      );

      S.publish(AppLocale.en);
      expect(renamed.displayLabel, 'Phim ảnh nhà tôi');

      S.publish(AppLocale.vi);
      expect(renamed.displayLabel, 'Phim ảnh nhà tôi');

      S.publish(AppLocale.en);
    });

    test('a shelf the user made has no shipped name to fall back to', () {
      const theirs = Category(id: 'x9', label: 'Phí gửi xe', sortOrder: 30);

      S.publish(AppLocale.vi);
      expect(theirs.displayLabel, 'Phí gửi xe');

      S.publish(AppLocale.en);
    });
  });
}

/// `push` returns a future that only completes when the route is popped;
/// awaiting it inside a test would hang.
void unawaited(Future<void> future) {}
