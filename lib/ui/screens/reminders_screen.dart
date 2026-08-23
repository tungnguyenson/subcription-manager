import 'package:flutter/material.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/reminders_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One item's reminder ladder.
///
/// Shares its shape with the app-wide defaults screen, and differs from it in
/// the one way that matters: this one shows the dates the rungs actually land
/// on. "3 days before" is not checkable; "18/08 · next" is.
class RemindersScreen extends StatelessWidget {
  final TrackedItem item;
  final LocalDate today;
  final LocalDate? createdOn;

  /// How many pending notifications this item holds, and how many of other
  /// items' reminders the budget forced out.
  final int heldSlots;
  final int droppedElsewhere;

  final VoidCallback? onBack;
  final void Function(int leadDays, bool on)? onToggleLead;
  final VoidCallback? onPickTime;
  final VoidCallback? onDisableAll;

  const RemindersScreen({
    super.key,
    required this.item,
    required this.today,
    this.createdOn,
    this.heldSlots = 0,
    this.droppedElsewhere = 0,
    this.onBack,
    this.onToggleLead,
    this.onPickTime,
    this.onDisableAll,
  });

  /// The rungs offered, whether or not the item currently uses them. A ladder
  /// the user can only remove from is a ladder they cannot repair.
  static const List<int> offeredLeads = [30, 7, 3, 1, 0];

  @override
  Widget build(BuildContext context) {
    final ladder = {
      for (final rung in RemindersPresenter.ladder(
        item,
        today,
        createdOn: createdOn,
      ))
        rung.leadDays: rung,
    };

    // Anything the item holds that is not one of the standard rungs still gets
    // a row, at its own place in the ladder.
    final leads = {...offeredLeads, ...item.leadDays}.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        BackLink(onTap: onBack),
        const Text('Reminders', style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(
          '${item.name} · ${RemindersPresenter.anchorLine(item)}',
          style: SubdockText.summary,
        ),
        const SectionLabel('Schedule'),
        GroupedCard(
          children: [
            for (final lead in leads)
              _RungRow(
                lead: lead,
                on: item.leadDays.contains(lead),
                detail: ladder[lead] == null
                    ? null
                    : RemindersPresenter.detail(ladder[lead]!, item.remindAt),
                next: ladder[lead]?.status == ReminderStatus.next,
                onChanged: onToggleLead == null
                    ? null
                    : (on) => onToggleLead!(lead, on),
              ),
          ],
        ),
        const SectionLabel('Time of day'),
        GroupedCard(
          children: [
            DetailRow(
              label: 'Send at',
              value: item.remindAt.toString(),
              monoValue: true,
              onTap: onPickTime,
            ),
          ],
        ),
        Footnote(RemindersPresenter.budgetLine(heldSlots, droppedElsewhere)),
        const SizedBox(height: 24),
        QuietButton(
          'Turn off every reminder for this item',
          onPressed: onDisableAll,
          danger: true,
        ),
      ],
    );
  }
}

class _RungRow extends StatelessWidget {
  final int lead;
  final bool on;

  /// The date this rung lands on, already worded. Null when the rung is off,
  /// because there is no date to name until it is switched on.
  final String? detail;

  final bool next;
  final ValueChanged<bool>? onChanged;

  const _RungRow({
    required this.lead,
    required this.on,
    this.detail,
    this.next = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SubdockSpacing.rowH),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead == 0
                      ? 'On the day'
                      : '$lead ${lead == 1 ? "day" : "days"} before',
                  style: SubdockText.rowLink,
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: next
                        ? SubdockText.footnote.copyWith(
                            color: SubdockColors.accent,
                          )
                        : SubdockText.footnote,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppToggle(value: on, onChanged: onChanged),
        ],
      ),
    );
  }
}
