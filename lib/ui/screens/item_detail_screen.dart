import 'package:flutter/material.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/annual_saving_presenter.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/manage_presenter.dart';
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

  /// The catalog row this item's name matches exactly, when it matches one.
  ///
  /// Resolved at display time rather than stored on the item, for the same
  /// reason the icon is: the catalogue ships with the binary and gets better
  /// between releases, so an item created before a price was collected picks
  /// it up on the next update without a migration.
  final CatalogEntry? catalogEntry;

  final VoidCallback? onBack;

  /// Opens the form on this item. Reached from the link beside Back and from
  /// the rows the form owns, so a user who came here to fix the price taps the
  /// price rather than hunting for a pencil.
  final VoidCallback? onEdit;

  final VoidCallback? onMarkPaid;
  final VoidCallback? onEditReminders;

  /// Postpones this item's next nudge. Absent once the item is closed.
  final VoidCallback? onSnooze;

  /// Ends the series: stop after this payment, or cancel the subscription.
  /// Both are the same operation and the label is derived from the item.
  final VoidCallback? onStop;

  final VoidCallback? onDelete;

  /// Leaves the app for the page that holds the real answer, and records what
  /// the tap revealed about where this subscription was bought.
  final void Function(ManageAction action)? onOpenManage;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.today,
    this.history = const [],
    this.scheduledCount = 0,
    this.nextReminder,
    this.catalogEntry,
    this.onBack,
    this.onEdit,
    this.onMarkPaid,
    this.onEditReminders,
    this.onSnooze,
    this.onStop,
    this.onDelete,
    this.onOpenManage,
  });

  @override
  Widget build(BuildContext context) {
    final position = Instalments.of(item);
    final money = item.money;
    final saving = AnnualSavingPresenter.of(
      item: item,
      entry: catalogEntry,
      today: today,
    );
    final manage = onOpenManage == null
        ? null
        : ManagePresenter.of(item: item, entry: catalogEntry);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.screenH,
        6,
        SubdockSpacing.screenH,
        SubdockSpacing.contentBottom,
      ),
      children: [
        Row(
          children: [
            Expanded(child: BackLink(onTap: onBack)),
            if (onEdit != null)
              InkWell(
                onTap: onEdit,
                child: const Padding(
                  // Matches BackLink's own padding so the two links sit on one
                  // baseline at either end of the row.
                  padding: EdgeInsets.fromLTRB(12, 2, 0, 14),
                  child: Text('Edit', style: SubdockText.quietAction),
                ),
              ),
          ],
        ),
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
            // The three rows the form owns open the form. The rest of this
            // card is derived or already has an editor of its own.
            DetailRow(
              label: 'Category',
              value: ItemPresenter.categoryLabel(item.category),
              onTap: onEdit,
            ),
            DetailRow(
              label: 'Repeats',
              value: ItemPresenter.repeatLabel(item),
              onTap: onEdit,
            ),
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
              // A dash on a row that leads somewhere reads as "nothing to see
              // here". An item with no price has one, and this is where the
              // user goes to put it in.
              value: money != null
                  ? _costLabel(money)
                  : (onEdit == null ? '—' : 'Add a cost'),
              monoValue: money != null,
              valueColor: money == null && onEdit != null
                  ? SubdockColors.accent
                  : null,
              onTap: onEdit,
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
        // Both blocks answer "what about this one?", which is this screen's
        // question. Neither belongs on the list, which answers "what is coming
        // up?" -- see design-spec.md 2.2.
        if (saving != null) ...[
          const SectionLabel('Yearly plan'),
          _AnnualSavingCard(copy: saving),
        ],
        if (manage != null) ...[
          // The saving block ends in exactly one action, and it is this
          // button. The app cannot switch anyone's plan and must not put a
          // control on screen that suggests it can.
          SizedBox(height: saving != null ? 10 : SubdockSpacing.sectionTop),
          SecondaryButton(
            manage.primary.label,
            onPressed: () => onOpenManage?.call(manage.primary),
          ),
          if (manage.alternate case final alternate?)
            QuietButton(
              alternate.label,
              onPressed: () => onOpenManage?.call(alternate),
            ),
        ],
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

/// What paying yearly instead of monthly is worth, on the vendor's own numbers.
///
/// Deliberately not a warning colour and deliberately not a badge. Saving money
/// is not a hazard, and this app spends its red on the one thing it is for:
/// something about to be lost that cannot be got back. A yearly plan that goes
/// unclaimed costs money, and money can be earned again.
class _AnnualSavingCard extends StatelessWidget {
  final AnnualSavingCopy copy;

  const _AnnualSavingCard({required this.copy});

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      padding: const EdgeInsets.fromLTRB(
        SubdockSpacing.rowH,
        16,
        SubdockSpacing.rowH,
        16,
      ),
      children: [
        // A sentence with a figure inside it, so the figure is set in the
        // figure face and the words are not. Joining them into one string and
        // one style would make the number read as prose.
        Text.rich(
          TextSpan(
            style: SubdockText.detailTitle.copyWith(fontSize: 19),
            children: [
              TextSpan(text: '${copy.savingLead} '),
              TextSpan(
                text: copy.savingAmount,
                style: const TextStyle(
                  fontFamily: SubdockText.mono,
                  letterSpacing: -0.5,
                ),
              ),
              const TextSpan(text: ' a year'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SumLine(label: 'Monthly', value: copy.monthlyValue),
        const SizedBox(height: 6),
        _SumLine(label: 'Yearly', value: copy.yearlyValue),
        const SizedBox(height: 14),
        Text(
          copy.sourceLine,
          // The provenance line is the whole reason this block is allowed to
          // exist, and once the price is over a year old it stops being an
          // aside. It gets the body colour then, not the footnote grey.
          style: copy.stale
              ? SubdockText.footnote.copyWith(color: SubdockColors.inkMuted)
              : SubdockText.footnote,
        ),
        if (copy.mismatchLine case final mismatch?) ...[
          const SizedBox(height: 6),
          Text(mismatch, style: SubdockText.footnote),
        ],
      ],
    );
  }
}

/// One side of the comparison: a word on the left, a figure on the right.
class _SumLine extends StatelessWidget {
  final String label;
  final String value;

  const _SumLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          // Fixed rather than intrinsic so the two figures start on the same
          // vertical, which is what makes them comparable at a glance.
          width: 66,
          child: Text(label, style: SubdockText.rowLabel),
        ),
        Expanded(
          child: Text(
            value,
            style: SubdockText.monoInline.copyWith(color: SubdockColors.ink),
          ),
        ),
      ],
    );
  }
}
