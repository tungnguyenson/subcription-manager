import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/screens/about_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  /// Builds the app the way [SubdockApp] does: the scope above the
  /// [MaterialApp], which is above the Navigator. Returns the setter that
  /// swaps the palette, standing in for the user tapping the tray or the
  /// phone going dark on its own.
  Future<void Function(SubdockPalette)> host(
    WidgetTester tester,
    Widget home,
  ) async {
    var palette = SubdockPalette.light;
    late StateSetter rebuild;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return SubdockTheme(
            palette: palette,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: buildSubdockTheme(palette),
              home: Scaffold(body: home),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    return (next) => rebuild(() => palette = next);
  }

  Color colourOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.color!;

  group('the palette reaches what is already on screen', () {
    testWidgets('a screen on the first route follows it', (tester) async {
      final set = await host(
        tester,
        const AboutScreen(version: '1.0.0', buildNumber: '42'),
      );

      expect(colourOf(tester, 'About'), SubdockPalette.light.ink);

      set(SubdockPalette.dark);
      await tester.pumpAndSettle();

      expect(colourOf(tester, 'About'), SubdockPalette.dark.ink);
    });

    // The one that matters, and the one the architecture is built around: a
    // route's page is built once and cached, so nothing an ancestor does will
    // rebuild it. Only the inherited dependency `SubdockTheme.watch` registers
    // reaches inside. A screen that forgets that line goes on painting the old
    // palette until something else happens to rebuild it -- which on a
    // system-driven change is a half-dark screen.
    testWidgets('a screen pushed before the change follows it too', (
      tester,
    ) async {
      final set = await host(tester, const SizedBox.shrink());

      unawaitedPush(
        navigator,
        const AboutScreen(version: '1.0.0', buildNumber: '42'),
      );
      await tester.pumpAndSettle();

      expect(colourOf(tester, 'About'), SubdockPalette.light.ink);

      set(SubdockPalette.dark);
      await tester.pumpAndSettle();

      expect(colourOf(tester, 'About'), SubdockPalette.dark.ink);
    });

    // The chrome is baked into the pushed route beside the screen, so it needs
    // its own dependency: the gradient and the tab bar are drawn by widgets
    // the screen does not own.
    testWidgets('the gradient under a pushed route follows it', (tester) async {
      final set = await host(tester, const SizedBox.shrink());

      unawaitedPush(navigator, const GlassBackground(child: SizedBox.shrink()));
      await tester.pumpAndSettle();

      LinearGradient painted() =>
          tester
                  .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                  .map((box) => box.decoration)
                  .whereType<BoxDecoration>()
                  .firstWhere((d) => d.gradient != null)
                  .gradient!
              as LinearGradient;

      expect(painted().colors, SubdockPalette.light.page.colors);

      set(SubdockPalette.dark);
      await tester.pumpAndSettle();

      expect(painted().colors, SubdockPalette.dark.page.colors);
    });

    testWidgets('the tab bar under a pushed route follows it', (tester) async {
      final set = await host(tester, const SizedBox.shrink());

      unawaitedPush(
        navigator,
        AppShell(
          current: ShellTab.upcoming,
          onSelect: (_) {},
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      Color barFill() => tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null && d.gradient == null)
          .color!;

      expect(barFill(), SubdockPalette.light.tabBar);

      set(SubdockPalette.dark);
      await tester.pumpAndSettle();

      expect(barFill(), SubdockPalette.dark.tabBar);
    });
  });

  group('the Settings tray', () {
    Future<void> showTall(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSubdockTheme(),
          home: Scaffold(body: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers all three answers, not a switch', (tester) async {
      await showTall(tester, const SettingsScreen());

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('a tap reports the choice it names', (tester) async {
      ThemeChoice? chosen;
      await showTall(
        tester,
        SettingsScreen(onThemeChoice: (choice) => chosen = choice),
      );

      await tester.tap(find.text('Dark'));
      expect(chosen, ThemeChoice.dark);

      await tester.tap(find.text('Light'));
      expect(chosen, ThemeChoice.light);
    });

    // The tray can say which one is picked. It cannot say that System means
    // the app will change on its own later, which is the one thing about this
    // setting a user can be surprised by.
    testWidgets('says out loud that System changes on its own', (tester) async {
      await showTall(tester, const SettingsScreen());

      expect(find.textContaining('Following the phone'), findsOneWidget);
    });

    // One line in all three states. A footnote that comes and goes moves the
    // Backup rows under the reader's thumb while they are choosing.
    testWidgets('the note is one line whichever is picked', (tester) async {
      for (final choice in ThemeChoice.values) {
        await showTall(tester, SettingsScreen(themeChoice: choice));
        expect(
          find
                  .textContaining('whatever the phone is set to')
                  .evaluate()
                  .length +
              find.textContaining('Following the phone').evaluate().length,
          1,
          reason: '$choice should say exactly one thing about itself',
        );
      }
    });
  });

  group('the two palettes', () {
    // A drop shadow needs something to darken, and a dark ground has nothing.
    // Elevation in the dark variant is carried by a border instead -- see
    // SubdockPalette.sheetEdge.
    testWidgets('dark draws elevation with a border, not a shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SubdockTheme(
          palette: SubdockPalette.dark,
          child: SizedBox.shrink(),
        ),
      );

      expect(SubdockShadow.sheet, isEmpty);
      expect(SubdockShadow.knob, isEmpty);
      expect(SubdockShadow.toast, isEmpty);
      // What takes their place.
      expect(SubdockColors.sheetEdge.a, greaterThan(0));

      // Back to light, both to assert the other half and to leave the global
      // where every other test in the suite expects it.
      await tester.pumpWidget(
        const SubdockTheme(
          palette: SubdockPalette.light,
          child: SizedBox.shrink(),
        ),
      );

      expect(SubdockShadow.sheet, isNotEmpty);
      expect(SubdockColors.sheetEdge.a, 0);
    });

    // Every colour has to be answered in both variants, and the two have to
    // differ: a token that is the same in both is a token that was copied
    // rather than decided.
    test('ink and ground are inverted, not shared', () {
      expect(SubdockPalette.dark.ink, isNot(SubdockPalette.light.ink));
      expect(SubdockPalette.dark.canvas, isNot(SubdockPalette.light.canvas));
      expect(
        SubdockPalette.dark.page.colors,
        isNot(SubdockPalette.light.page.colors),
      );
    });

    // The dark accent is a light blue, so white on it fails contrast. This is
    // the whole reason onAccent is a token rather than Color(0xFFFFFFFF)
    // written at each call site.
    test('text on a filled accent is dark where the accent is light', () {
      expect(
        SubdockPalette.dark.onAccent.computeLuminance(),
        lessThan(SubdockPalette.dark.accent.computeLuminance()),
      );
      expect(
        SubdockPalette.light.onAccent.computeLuminance(),
        greaterThan(SubdockPalette.light.accent.computeLuminance()),
      );
    });

    test('the same holds for danger and savings', () {
      for (final palette in [SubdockPalette.light, SubdockPalette.dark]) {
        expect(
          (palette.onDanger.computeLuminance() -
                  palette.danger.computeLuminance())
              .abs(),
          greaterThan(0.3),
          reason: 'a countdown pill has to be readable in $palette',
        );
        expect(
          (palette.onSavings.computeLuminance() -
                  palette.savings.computeLuminance())
              .abs(),
          greaterThan(0.3),
        );
      }
    });

    test('body text is readable on its own ground', () {
      for (final palette in [SubdockPalette.light, SubdockPalette.dark]) {
        expect(
          (palette.ink.computeLuminance() - palette.canvas.computeLuminance())
              .abs(),
          greaterThan(0.5),
          reason: 'ink on canvas in $palette',
        );
      }
    });
  });
}

/// Pushes [screen] the way `_push` does: on a Scaffold, so the ink a row uses
/// has a Material under it.
void unawaitedPush(GlobalKey<NavigatorState> navigator, Widget screen) {
  navigator.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => Scaffold(body: screen)),
  );
}
