import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The free-trial control: one switch, and a line saying what it changes.
///
/// A trial has no dates of its own. The day the free period ends is the day
/// the first charge lands, and that is the form's own date field — so asking
/// for it a second time here would be two answers to one question, and asking
/// for a start date on top would be a third. Nothing this control could
/// collect is worth the taps: the app does not need to know when the trial
/// began in order to warn the user before it ends.
///
/// So the whole control is a flag, and the line under it spends its space
/// saying what the flag does rather than asking for more.
class TrialField extends StatelessWidget {
  final bool value;

  final ValueChanged<bool> onChanged;

  const TrialField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedCard(
          children: [
            // The whole row, not just the switch. A 42-by-25 pill on a row
            // eight times that wide reads as tappable everywhere and answers
            // in one corner; a tap on the label that does nothing is
            // indistinguishable from a switch that is broken. The Reminders
            // screen deliberately does the opposite -- five stacked leads
            // where a stray tap flips the wrong one -- which is why this lives
            // here rather than in `ToggleRow`.
            InkWell(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SubdockSpacing.rowH,
                  vertical: SubdockSpacing.rowV,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'In a free trial now',
                        style: SubdockText.rowLink,
                      ),
                    ),
                    // Keeps its own gesture: it is opaque, so a tap on the
                    // pill is answered there and never reaches the row behind
                    // it. One tap, one call, either way.
                    AppToggle(value: value, onChanged: onChanged),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Only while it is on. Off is the state the user is already in and
        // needs nothing explained about; a line under a switch nobody has
        // touched is a caption on the ordinary case.
        //
        // It names neither date. The summary block at the foot of the form
        // already reads the charge date back in full, and a second line saying
        // `Free until 15/08` a screen above it is the form answering one
        // question twice. What is left is the part nothing else on this screen
        // says: what the flag actually changes once the item is saved.
        if (value)
          const Footnote(
            'Badged FREE TRIAL on the list. Nothing counts as spent before the '
            'first charge.',
          ),
      ],
    );
  }
}
