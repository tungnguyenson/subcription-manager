import 'package:flutter/material.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// The reminder defaults, for the app rather than for one item.
///
/// These apply to items added from now on. Changing them does not rewrite what
/// is already on the list — an item whose ladder the user tuned by hand must
/// not be quietly reset by a switch on a settings screen — and the footnote
/// says so rather than leaving the user to find out.
class ReminderRulesScreen extends StatelessWidget {
  final AppSettings settings;

  /// Whether the system will actually deliver anything. The switch below
  /// reports this rather than a preference of its own: an in-app "push" toggle
  /// that says on while the system permission is off is a lie the user cannot
  /// see through.
  final bool pushGranted;

  /// Whether a reminder lands at the minute it was set for. Null where the
  /// question does not arise, which is every platform but Android -- see
  /// [NotificationScheduler.hasExactTiming].
  ///
  /// Separate from [pushGranted] because they fail separately: permission
  /// granted plus exact timing denied still delivers, just late, and "late"
  /// is the difference between catching a deadline and missing it.
  final bool? exactTiming;

  final void Function(int lead, bool on)? onToggleLead;
  final VoidCallback? onPickTime;
  final VoidCallback? onEnablePush;

  /// Sends one notification a few seconds out, to prove the path works.
  ///
  /// Everything else on this screen is a claim the app makes about delivery,
  /// and the user has no way to check any of it. A reminder that never arrives
  /// looks exactly like a reminder that is still coming, so without this the
  /// only test available is to wait until the day of a real deadline and find
  /// out then.
  final VoidCallback? onSendTest;

  final VoidCallback? onBack;

  const ReminderRulesScreen({
    super.key,
    required this.settings,
    this.pushGranted = false,
    this.exactTiming,
    this.onToggleLead,
    this.onPickTime,
    this.onEnablePush,
    this.onSendTest,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: onBack),
        Text(S.t.rowReminders, style: SubdockText.screenTitle),
        SectionLabel(S.t.remindersDefaultSchedule),
        GroupedCard(
          children: [
            for (final lead in AppSettings.offeredLeads)
              ToggleRow(
                label: ItemPresenter.leadLabel(lead),
                value: settings.defaultLeadDays.contains(lead),
                onChanged: onToggleLead == null
                    ? null
                    : (on) => onToggleLead!(lead, on),
              ),
          ],
        ),
        SectionLabel(S.t.remindersTimeOfDay),
        GroupedCard(
          children: [
            DetailRow(
              label: S.t.remindersSendAt,
              value: settings.remindAt.toString(),
              monoValue: true,
              onTap: onPickTime,
            ),
          ],
        ),
        SectionLabel(S.t.remindersChannels),
        GroupedCard(
          children: [
            ToggleRow(
              label: S.t.remindersPush,
              value: pushGranted,
              // Turning it on is a system prompt; turning it off is a system
              // setting. Neither belongs to this switch, so it only ever asks.
              onChanged: pushGranted || onEnablePush == null
                  ? null
                  : (_) => onEnablePush!(),
            ),
          ],
        ),
        // Only while push is granted. With it off the button cannot do
        // anything, and a button that fails on purpose teaches the user
        // nothing the footnote below does not already say.
        if (pushGranted && onSendTest != null) ...[
          const SizedBox(height: 10),
          SecondaryButton(S.t.remindersSendTest, onPressed: onSendTest),
        ],
        // Only the state, never the tutorial. That notifications are off is
        // something the user cannot see anywhere else on this screen; how the
        // defaults propagate is documentation, and documentation does not
        // belong on a settings page.
        if (!pushGranted)
          Footnote(S.t.remindersNotificationsOff)
        else if (exactTiming == false)
          Footnote(S.t.remindersInexact),
      ],
    );
  }
}
