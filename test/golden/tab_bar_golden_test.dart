import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/theme.dart';

/// The tab bar is drawn entirely from stacked shadows and one accent disc, and
/// none of that is expressible as an assertion — a shadow layer can go missing
/// without a single widget test noticing. Regenerate with:
///
///     flutter test test/golden --update-goldens
void main() {
  setUpAll(() async {
    final families = {
      SubdockText.family: [
        'assets/fonts/BeVietnamPro-Regular.ttf',
        'assets/fonts/BeVietnamPro-Medium.ttf',
        'assets/fonts/BeVietnamPro-SemiBold.ttf',
        'assets/fonts/BeVietnamPro-Bold.ttf',
      ],
      SubdockText.mono: [
        'assets/fonts/IBMPlexMono-Regular.ttf',
        'assets/fonts/IBMPlexMono-Medium.ttf',
        'assets/fonts/IBMPlexMono-SemiBold.ttf',
      ],
    };

    for (final entry in families.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(
          File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      }
      await loader.load();
    }
  });

  testWidgets('three destinations and the add button', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 130 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSubdockTheme(),
        home: AppShell(
          current: ShellTab.upcoming,
          onSelect: (_) {},
          onAdd: () {},
          child: const ColoredBox(color: SubdockColors.canvas),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(AppShell), matchesGoldenFile('tab_bar.png'));
  });
}
