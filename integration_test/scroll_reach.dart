import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How much of the bottom of the screen the tab bar covers.
///
/// The bar is 60 high and sits on the home indicator inset, which is 34 on the
/// phones these run on. Rounded up rather than measured, because the number is
/// only used to decide whether to keep scrolling and overshooting costs
/// nothing.
const double _tabBarReach = 100;

/// Scrolls [target] far enough up the screen to be tappable, then taps it.
///
/// `scrollUntilVisible` stops the moment the target enters the viewport, and
/// on this app the viewport runs *underneath* the tab bar: `AppShell` uses
/// `Scaffold(extendBody: true)` so the bar has something to blur. A target that
/// has only just appeared is therefore sitting behind the bar, and
/// `tester.tap` sends the pointer to the bar instead. The tap is not lost --
/// it lands on a `BackdropFilter` and does nothing -- so the failure reads as
/// a button that did not respond, which sends the reader looking at the button.
///
/// The list can always scroll further, because `SubdockSpacing.screenPadding`
/// adds the bar's height back as bottom padding. This just keeps going until
/// the target is clear of it.
///
/// This cost the repo three red tests in `delete_test.dart` and three in
/// `navigation_test.dart`, sitting unnoticed because `flutter test` does not
/// run `integration_test/`.
Future<void> tapPastTabBar(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);

  final floor = tester.getSize(find.byType(MaterialApp)).height - _tabBarReach;
  // Bounded, so a target that genuinely cannot clear the bar fails on the tap
  // with the framework's own diagnostics rather than spinning here.
  for (var i = 0; i < 10 && tester.getCenter(target).dy > floor; i++) {
    await tester.drag(scrollable, const Offset(0, -40));
    await tester.pumpAndSettle();
  }

  await tester.tap(target);
  await tester.pumpAndSettle();
}
