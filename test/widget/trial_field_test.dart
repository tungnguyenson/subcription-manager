import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/ui/screens/add/trial_field.dart';
import 'package:subdock/ui/theme.dart';

/// The control is one switch and nothing else, and it has to work with nothing
/// else on the form filled in.
/// A trial has no dates of its own — the day the free period ends is the day
/// the charge lands, which is the form's own date field — so there is nothing
/// here for the user to answer before the flag can be set.
void main() {
  Future<bool> show(WidgetTester tester, {bool start = false}) async {
    var value = start;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSubdockTheme(),
        home: Scaffold(
          backgroundColor: SubdockColors.canvas,
          body: StatefulBuilder(
            builder: (context, setState) => TrialField(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('In a free trial now'));
    await tester.pumpAndSettle();
    return value;
  }

  // The label, not the switch. A tap that lands on the words and does nothing
  // is indistinguishable from a switch that is broken.
  testWidgets('the whole row turns it on, with nothing else filled in', (
    tester,
  ) async {
    expect(await show(tester), isTrue);
  });

  testWidgets('tapping it again turns it off', (tester) async {
    expect(await show(tester, start: true), isFalse);
  });

  // No caption under the switch, on or off. It explained a control the user
  // has already understood by the time they could read it, and both things it
  // promised -- the badge on the list, and nothing counting as spent -- show
  // up on their own within a screen of tapping it.
  testWidgets('says nothing under the switch, either way', (tester) async {
    await show(tester);
    expect(find.textContaining('Badged FREE TRIAL'), findsNothing);

    await show(tester, start: true);
    expect(find.textContaining('Badged FREE TRIAL'), findsNothing);
  });
}
