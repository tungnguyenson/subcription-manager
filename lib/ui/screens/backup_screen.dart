import 'package:flutter/material.dart';

import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

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

  /// Writes the list out as a spreadsheet. Null where the channel has no such
  /// thing.
  final VoidCallback? onExportCsv;

  /// Replaces everything in the app. The confirmation belongs to whoever wires
  /// this up, not to a button on a settings screen.
  final VoidCallback? onRestore;

  /// Attaches an account to a channel that needs one.
  final VoidCallback? onConnect;

  /// Detaches it again, leaving the copy where it is.
  final VoidCallback? onDisconnect;

  final VoidCallback? onBack;

  const BackupScreen({
    super.key,
    required this.page,
    this.onBackUp,
    this.onExportCsv,
    this.onRestore,
    this.onConnect,
    this.onDisconnect,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: onBack),
        Text(page.title, style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(page.intro, style: SubdockText.summary),
        if (page.facts.isNotEmpty) ...[
          SectionLabel(S.t.backupNow),
          GroupedCard(
            children: [
              for (final (label, value) in page.facts)
                DetailRow(label: label, value: value, monoValue: true),
            ],
          ),
        ],
        SectionLabel(S.t.backupActions),
        GroupedCard(
          children: [
            // First, because on a channel with no account yet it is the only
            // row here and the only thing the page is for.
            if (page.connectLabel case final label?)
              DetailRow.nav(label: label, onTap: onConnect),
            if (page.backUpLabel case final label?)
              DetailRow.nav(label: label, onTap: onBackUp),
            // Under the backup rather than above it. The backup is the row
            // someone came here for after losing a phone; the spreadsheet is
            // the row they came here for out of curiosity, and only one of the
            // two has a bad day behind it.
            if (page.exportCsvLabel case final label?)
              DetailRow.nav(label: label, onTap: onExportCsv),
            // The one that destroys the list is last and reads plainly. It is
            // not tinted: the sheet it opens is where the warning belongs, and
            // a red row in a settings list is read as broken rather than as
            // dangerous.
            if (page.restoreLabel case final label?)
              DetailRow.nav(label: label, onTap: onRestore),
            // Below the restore, and plain. It destroys nothing: the copy
            // stays in the user's Drive, which is what the footnote says.
            if (page.disconnectLabel case final label?)
              DetailRow.nav(label: label, onTap: onDisconnect),
          ],
        ),
        if (page.note case final note?) Footnote(note),
      ],
    );
  }
}
