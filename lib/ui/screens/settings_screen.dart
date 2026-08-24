import 'package:flutter/material.dart';
import 'package:subdock/domain/notification_planner.dart';
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

  final VoidCallback? onOpenReminders;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onExport;
  final VoidCallback? onAbout;

  const SettingsScreen({
    super.key,
    this.droppedReminders = const [],
    this.currencyLabel = 'VND',
    this.languageLabel = 'English',
    this.onOpenReminders,
    this.onOpenHistory,
    this.onExport,
    this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
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
        const SizedBox(height: 20),
        GroupedCard(
          children: [
            DetailRow.nav(label: 'Reminders', onTap: onOpenReminders),
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
            DetailRow.nav(label: 'Export data', onTap: onExport),
            DetailRow.nav(label: 'About', onTap: onAbout),
          ],
        ),
      ],
    );
  }
}
