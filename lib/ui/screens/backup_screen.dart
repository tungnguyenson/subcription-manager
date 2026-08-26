import 'package:flutter/material.dart';

import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One backup channel: what it is, when it last worked, and what can be done
/// with it.
///
/// Both channels use this screen, and the wording that tells them apart comes
/// in as a [BackupPage] rather than being written here. The two are genuinely
/// different promises -- one the app keeps by itself, one the user keeps by
/// hand -- and that difference is almost entirely copy.
///
/// Its own screen at all because Settings used to carry five backup rows: a
/// status, a date, and three actions, two of which destroy the list. Five rows
/// under one heading gave the destructive pair the same weight as the date
/// above them.
class BackupScreen extends StatelessWidget {
  final BackupPage page;

  /// Writes a copy. Null where the channel writes its own.
  final VoidCallback? onBackUp;

  /// Replaces everything in the app. The confirmation belongs to whoever wires
  /// this up, not to a button on a settings screen.
  final VoidCallback? onRestore;

  final VoidCallback? onBack;

  const BackupScreen({
    super.key,
    required this.page,
    this.onBackUp,
    this.onRestore,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: onBack),
        Text(page.title, style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(page.intro, style: SubdockText.summary),
        if (page.facts.isNotEmpty) ...[
          const SectionLabel('Now'),
          GroupedCard(
            children: [
              for (final (label, value) in page.facts)
                DetailRow(label: label, value: value, monoValue: true),
            ],
          ),
        ],
        const SectionLabel('Actions'),
        GroupedCard(
          children: [
            if (page.backUpLabel case final label?)
              DetailRow.nav(label: label, onTap: onBackUp),
            // The one that destroys the list is last and reads plainly. It is
            // not tinted: the sheet it opens is where the warning belongs, and
            // a red row in a settings list is read as broken rather than as
            // dangerous.
            if (page.restoreLabel case final label?)
              DetailRow.nav(label: label, onTap: onRestore),
          ],
        ),
        if (page.note case final note?) Footnote(note),
      ],
    );
  }
}
