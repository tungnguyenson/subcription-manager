import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/theme.dart';

/// The tab bar is a frosted translucent panel over a gradient with one accent
/// disc on it, and none of that is expressible as an assertion — the blur, the
/// bright top hairline and the panel's own alpha can each go missing without a
/// single widget test noticing. Regenerate with:
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

  testWidgets('four destinations and the add button', (tester) async {
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
          // Something with edges under the bar, so the blur has work to do. A
          // flat fill would look identical whether the BackdropFilter is there
          // or not, which is the one thing this golden exists to catch.
          child: const _Stripes(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(find.byType(AppShell), matchesGoldenFile('tab_bar.png'));
  });
}

/// Bands the frosted bar has to visibly smear.
class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 10; i++)
        Expanded(
          child: ColoredBox(
            color: i.isEven ? SubdockColors.accent : SubdockColors.canvas,
            child: const SizedBox.expand(),
          ),
        ),
    ],
  );
}
