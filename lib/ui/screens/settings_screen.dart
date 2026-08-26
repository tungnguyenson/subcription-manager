import 'package:flutter/material.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/primitives.dart';

class SettingsScreen extends StatelessWidget {
  /// Alerts the planner had to leave out. Shown at the top, not buried in a
  /// log: the platform drops the furthest-out pending notifications silently,
  /// and the user has no other way to learn that a reminder they are relying
  /// on was never actually scheduled.
  final List<String> droppedReminders;

  final String currencyLabel;
  final String languageLabel;

  /// `8 · 2 off`. Answers "how much is in there" without opening the screen,
  /// and the `off` half is the only place outside Upcoming that says anything
  /// has been paused.
  final String? servicesLine;

  /// `3`, or `None`.
  final String? sourcesLine;

  /// What the backup card says: when the last one was, whether the device
  /// keeps a copy of its own, and whether that is worth warning about.
  ///
  /// Null only where a caller has nothing to say, which in practice is a test
  /// building this screen for some other reason. The card still draws its two
  /// actions; it just cannot report state it was not given.
  final BackupView? backup;

  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenSources;
  final VoidCallback? onOpenReminders;
  final VoidCallback? onOpenHistory;

  /// Hands the whole list to the system share sheet as one file.
  final VoidCallback? onExport;

  /// Reads one back, replacing everything. Destructive, and the confirmation
  /// that says so belongs to whoever wires this up, not to a settings row.
  final VoidCallback? onImport;

  final VoidCallback? onAbout;

  const SettingsScreen({
    super.key,
    this.droppedReminders = const [],
    this.currencyLabel = 'VND',
    this.languageLabel = 'English',
    this.servicesLine,
    this.sourcesLine,
    this.backup,
    this.onOpenServices,
    this.onOpenSources,
    this.onOpenReminders,
    this.onOpenHistory,
    this.onExport,
    this.onImport,
    this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        const Text('Settings', style: SubdockText.screenTitle),
        if (droppedReminders.isNotEmpty) ...[
          const SizedBox(height: 18),
          AlertBanner(
            title:
                '${droppedReminders.length} reminders could not be scheduled',
            body:
                'This app schedules at most '
                '${NotificationPlanner.budget} reminders at a time. '
                'Left out: ${droppedReminders.join(", ")}.',
          ),
        ],
        // Under the reminder banner rather than above it. That one is about
        // dates that will not arrive; this one is about a list that has not
        // been copied anywhere. Both are things the user cannot find out from
        // any other screen, which is why both are here and not in a footnote.
        if (backup?.warningTitle case final title?) ...[
          const SizedBox(height: 18),
          AlertBanner(
            title: title,
            body: backup?.warningBody ?? '',
            actionLabel: 'Export a backup',
            onAction: onExport,
          ),
        ],
        const SizedBox(height: 20),
        GroupedCard(
          children: [
            DetailRow.nav(
              label: 'All services',
              value: servicesLine,
              onTap: onOpenServices,
            ),
            DetailRow.nav(label: 'Reminders', onTap: onOpenReminders),
            DetailRow.nav(
              label: 'Payment sources',
              value: sourcesLine,
              onTap: onOpenSources,
            ),
            DetailRow.nav(label: 'History', onTap: onOpenHistory),
            // Value rows, not destinations. There is one base currency and one
            // language, and a chevron on either would promise a picker that
            // does not exist.
            DetailRow(label: 'Currency', value: currencyLabel),
            DetailRow(label: 'Language', value: languageLabel),
          ],
        ),
        const SizedBox(height: 14),
        GroupedCard(
          children: [
            // A value row, not a destination, and for the same reason Currency
            // and Language above are: there is no home-screen widget in this
            // build and no screen to configure one, so a chevron here would
            // promise a place that does not exist. The row is still worth
            // having — it answers "can this put my next date on the home
            // screen" without the user hunting for a setting that is not
            // there.
            const DetailRow(label: 'Widget', value: 'Not yet'),
            DetailRow.nav(label: 'About', onTap: onAbout),
          ],
        ),
        const SectionLabel('Backup'),
        GroupedCard(
          children: [
            // A value row, not a destination, for the same reason Currency and
            // Language are: it reports state and leads nowhere. `Never` beside
            // a list of twelve items is the whole warning, which is why no
            // sentence here tells the user what to do about it.
            if (backup case final view?)
              DetailRow(label: 'Last backup', value: view.lastBackup),
            DetailRow.nav(label: 'Export a backup', onTap: onExport),
            DetailRow.nav(label: 'Restore from a backup', onTap: onImport),
          ],
        ),
        // State, not a tutorial — the same rule the reminder screen follows.
        // Answers section 11.2 of the product spec: say whether the database
        // is in the device's own backup, so the user knows what they are
        // trusting. The sentence differs per platform because the truth does;
        // see [DeviceBackup].
        if (backup case final view?) Footnote(view.note),
      ],
    );
  }
}
