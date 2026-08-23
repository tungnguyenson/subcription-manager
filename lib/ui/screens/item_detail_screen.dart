import 'package:flutter/material.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';

class ItemDetailScreen extends StatelessWidget {
  final TrackedItem item;
  final LocalDate today;
  final List<HandledEvent> history;

  /// How many reminders this item currently holds on the device. Shown before
  /// the delete button, because deleting also silently removes them.
  final int scheduledCount;

  /// The next reminder, already worded. Null when nothing is pending.
  final String? nextReminder;

  final VoidCallback? onBack;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onEditReminders;

  /// Postpones this item's next nudge. Absent once the item is closed.
  final VoidCallback? onSnooze;

  /// Ends the series: stop after this payment, or cancel the subscription.
  /// Both are the same operation and the label is derived from the item.
  final VoidCallback? onStop;

  final VoidCallback? onDelete;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.today,
    this.history = const [],
    this.scheduledCount = 0,
    this.nextReminder,
    this.onBack,
    this.onMarkPaid,
    this.onEditReminders,
    this.onSnooze,
    this.onStop,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final position = Instalments.of(item);
    final money = item.money;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        BackLink(onTap: onBack),
        Row(
          children: [
            ServiceTile(
              item.name,
              size: 48,
              radius: SubdockRadius.field,
              fontSize: 19,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: SubdockText.detailTitle),
                  const SizedBox(height: 5),
                  Text(
                    ItemPresenter.summary(item, today),
                    style: SubdockText.itemSubtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GroupedCard(
          children: [
            if (position != null) _PaymentProgress(position: position),
            DetailRow(
              label: 'Category',
              value: ItemPresenter.categoryLabel(item.category),
            ),
            DetailRow(label: 'Repeats', value: ItemPresenter.repeatLabel(item)),
            if (Instalments.lastOccurrence(item) case final last?)
              DetailRow(
                label: 'Last payment',
                value: MoneyFormat.date(last),
                monoValue: true,
              ),
            DetailRow(
              label: 'Remind me',
              value: _remindLabel(),
              onTap: onEditReminders,
            ),
            DetailRow(
              label: 'Cost',
              value: money == null ? '—' : _costLabel(money),
              monoValue: money != null,
            ),
            if (Instalments.totalLeft(item) case final left?)
              DetailRow(
                label: 'Total left',
                value: MoneyFormat.full(left),
                monoValue: true,
              ),
            DetailRow(
              label: 'Date from',
              value: ItemPresenter.dateSourceLabel(item.dateSource),
            ),
            DetailRow(label: 'Note', value: item.note ?? '—'),
          ],
        ),
        const SectionLabel('Actions'),
        PrimaryButton(_markLabel(position), onPressed: onMarkPaid),
        const SizedBox(height: 10),
        SecondaryButton(
          nextReminder == null
              ? 'Edit reminders'
              : 'Next reminder $nextReminder',
          onPressed: onEditReminders,
        ),
        const SizedBox(height: 10),
        // Named for what it does, not for the mechanism. "Snooze" is a word
        // about the app; "remind me again in 3 days" is a sentence about the
        // user's week, and it is the only wording that says how long.
        if (onSnooze != null) ...[
          QuietButton('Remind me again in 3 days', onPressed: onSnooze),
          const SizedBox(height: 10),
        ],
        if (_stopLabel() case final stop?)
          QuietButton(stop, onPressed: onStop)
        else
          QuietButton('Delete this item', onPressed: onDelete, danger: true),
        if (history.isNotEmpty) ...[
          const SectionLabel('History'),
          GroupedCard(
            children: [
              for (final event in history)
                DetailRow(
                  label: MoneyFormat.shortDate(event.forDueDate),
                  value: _paidLabel(event),
                ),
            ],
          ),
        ],
        if (_stopLabel() != null) ...[
          const SizedBox(height: 24),
          QuietButton('Delete this item', onPressed: onDelete, danger: true),
        ],
        Footnote(ItemPresenter.deleteConsequence(scheduledCount)),
      ],
    );
  }

  String _remindLabel() {
    final leads = item.leadDays;
    if (leads.isEmpty) return 'Never';
    return ItemPresenter.leadLabel(leads.first);
  }

  String _costLabel(Money money) {
    final per = ItemPresenter.cyclePer(item.cycle);
    final amount = MoneyFormat.full(money);
    return per == null ? amount : '$amount $per';
  }

  /// `Mark payment 4 as paid` while there are instalments left to count, and
  /// plain `Mark as paid` otherwise. The number is what tells the user the app
  /// and their own records agree about where they are in the plan.
  String _markLabel(Instalments? position) => position == null
      ? 'Mark as paid'
      : 'Mark payment ${position.index} as paid';

  /// The quiet action, or null when this item has no series to end.
  String? _stopLabel() {
    if (item.state != ItemState.active) return null;
    if (Instalments.of(item) != null) return 'Stop after this payment';
    if (item.cycle != null) return 'Cancel this subscription';
    return null;
  }

  String _paidLabel(HandledEvent event) {
    final minor = event.actualChargedMinor ?? event.baseAmountMinor;
    final currency = event.currency;
    if (minor == null || currency == null) return 'Paid';
    return MoneyFormat.full(Money(minor, currency));
  }
}

/// The instalment strip: one pip per payment, filled up to where the user is.
///
/// Three states rather than two. A plan the user is halfway through has a
/// payment that is *due now*, and drawing it the same as one already made
/// would tell them they are one further ahead than they are.
class _PaymentProgress extends StatelessWidget {
  final Instalments position;

  const _PaymentProgress({required this.position});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.rowH,
        16,
        SubdockSpacing.rowH,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Payment', style: SubdockText.rowLabel),
              ),
              Text(
                '${position.index} of ${position.total}',
                style: SubdockText.rowValue.copyWith(
                  fontFamily: SubdockText.mono,
                  letterSpacing: -0.13,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= position.total; i++) ...[
                if (i > 1) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: switch (i) {
                        _ when i < position.index => SubdockColors.accent,
                        _ when i == position.index => SubdockColors.accentHalf,
                        _ => SubdockColors.accentFaint,
                      },
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(
            ItemPresenter.instalmentLine(position),
            style: SubdockText.footnote,
          ),
        ],
      ),
    );
  }
}
