import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';

/// One consequence, on the sheet that stands in front of an action.
///
/// The three confirmation sheets -- delete, restore, cancel -- are the same
/// shape on purpose, because they are read in the same half second and by the
/// same reader: someone who has already tapped and is now being asked to look
/// before it happens. A row that is laid out differently on each of them is a
/// row that has to be parsed three times.
///
/// [danger] tints only the icon. The whole row going red would say the loss is
/// certain, when what it usually is is a count that happens to be non-zero.
class AskLine extends StatelessWidget {
  final IconData icon;

  /// What is about to happen. `Reminders stopped`, `Kept`.
  final String label;

  /// What it happens to. A count, a date, a list of things.
  final String value;

  final bool danger;

  const AskLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? SubdockColors.danger : SubdockColors.accent;

    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.hairline,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SubdockText.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: SubdockText.footnote.copyWith(fontSize: 14.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
