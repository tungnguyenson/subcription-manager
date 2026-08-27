import 'package:flutter/material.dart';

import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/savings_presenter.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// The one screen where a number is good news.
///
/// Two tabs, and they are two different claims rather than two views of one.
/// **Move to yearly** says "the vendor charges less for the same thing" and its
/// figures come out of the catalogue, each with a page and a date behind it.
/// **Cancel a service** says "you would stop paying this" and its figures come
/// out of what the user typed. Mixing them into a single "you could save X"
/// headline would put a sourced number and a self-reported one inside the same
/// total, and there would be no way to say which half was which.
///
/// Everything on this screen is in [SubdockColors.savings], not the accent. It
/// is the only screen in the app where a figure is money the user *keeps*, and
/// the accent already means "you can act here".
class SavingsScreen extends StatefulWidget {
  final SavingsView view;

  /// How many monthly plans were considered, for the `2 of 5` lead line.
  final int monthlyCount;

  /// Sets or clears the note on the item's renewal reminder.
  final void Function(String itemId, YearlyChoice choice)? onChoose;

  /// Brings every dismissed suggestion back.
  final VoidCallback? onUnskip;

  /// Opens the item, so a plan with no yearly price can have one entered.
  final void Function(String itemId)? onOpenItem;

  /// Leaves for the page where the service is actually cancelled.
  final void Function(String itemId, String url)? onOpenCancel;

  /// Stops tracking a service the user has confirmed they cancelled.
  final void Function(String itemId)? onRemove;

  const SavingsScreen({
    super.key,
    required this.view,
    required this.monthlyCount,
    this.onChoose,
    this.onUnskip,
    this.onOpenItem,
    this.onOpenCancel,
    this.onRemove,
  });

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  SavingsTab _tab = SavingsTab.yearly;

  /// Which row is expanded. One at a time: the expanded body carries a button
  /// that leaves the app, and two of those open at once invites the wrong tap.
  String? _open;

  /// Whether the "no yearly price yet" list is unfolded. Folded by default —
  /// it is a list of things the app *cannot* help with, and it must not be the
  /// first thing on a screen about what it can.
  bool _unpricedOpen = false;

  /// Services the user has just been sent off to cancel, this session only.
  ///
  /// Not persisted, and that is the honest scope: the app has no way to know
  /// whether the cancellation went through. What it knows is that it opened the
  /// page a moment ago, which is exactly long enough to be worth offering "I
  /// did it — stop tracking this". Storing it would turn a hunch into a record.
  final Set<String> _sentTo = {};

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    final view = widget.view;

    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        Text(S.t.savingsTitle, style: SubdockText.screenTitle),
        const SizedBox(height: 14),
        SegmentedRow(
          labels: [S.t.tabMoveToYearly, S.t.tabCancelAService],
          selected: _tab.index,
          onSelect: (i) => setState(() {
            _tab = SavingsTab.values[i];
            _open = null;
          }),
        ),
        const SizedBox(height: 14),
        Text(
          view.leadFor(_tab, widget.monthlyCount),
          style: SubdockText.summary,
        ),
        if (_tab == SavingsTab.yearly)
          ..._yearlyTab(view)
        else
          ..._cancelTab(view),
      ],
    );
  }

  // ---- move to yearly ----

  List<Widget> _yearlyTab(SavingsView view) => [
    if (view.hasYearly) ...[
      const SizedBox(height: 18),
      GroupedCard(
        padding: const EdgeInsets.all(18),
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(view.total, style: SubdockText.figureLight),
          ),
          const SizedBox(height: 7),
          Text(view.totalSub, style: SubdockText.footnote),
          const SizedBox(height: 5),
          Text(
            // The catch, on the headline rather than in a footnote. A yearly
            // plan is cheaper per month and more expensive today, and someone
            // who acts on this figure without knowing that gets a surprise
            // twelve times the size of the one they were avoiding.
            S.t.paidUpFront,
            style: SubdockText.caption,
          ),
        ],
      ),
      SectionLabel(S.t.tabMoveToYearly),
      for (var i = 0; i < view.yearly.length; i++) ...[
        if (i > 0) const SizedBox(height: SubdockSpacing.rowGap),
        _YearlyCard(
          row: view.yearly[i],
          expanded: _open == view.yearly[i].itemId,
          onToggle: () => _toggle(view.yearly[i].itemId),
          onChoose: (choice) =>
              widget.onChoose?.call(view.yearly[i].itemId, choice),
        ),
      ],
    ],
    if (view.unpriced.isNotEmpty) ...[
      const SizedBox(height: 14),
      _UnpricedFold(
        rows: view.unpriced,
        open: _unpricedOpen,
        onToggle: () => setState(() => _unpricedOpen = !_unpricedOpen),
        onOpenItem: widget.onOpenItem,
      ),
    ],
    if (view.leftOut != null) ...[
      const SizedBox(height: 22),
      Text(view.leftOut!, style: SubdockText.caption),
    ],
    if (view.skipped > 0) ...[
      const SizedBox(height: 10),
      InkWell(
        onTap: widget.onUnskip,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            S.t.skippedSuggestions(view.skipped),
            style: SubdockText.footnote.copyWith(color: SubdockColors.accent),
          ),
        ),
      ),
    ],
  ];

  // ---- cancel ----

  List<Widget> _cancelTab(SavingsView view) => [
    for (final group in view.groups) ...[
      const SizedBox(height: 24),
      _GroupHeader(group: group),
      for (var i = 0; i < group.rows.length; i++) ...[
        if (i > 0) const SizedBox(height: SubdockSpacing.rowGap),
        _CancelCard(
          row: group.rows[i],
          dim: group.discouraged,
          expanded: _open == group.rows[i].itemId,
          sentTo: _sentTo.contains(group.rows[i].itemId),
          onToggle: () => _toggle(group.rows[i].itemId),
          onOpen: () {
            final url = group.rows[i].target.url;
            if (url == null) return;
            setState(() => _sentTo.add(group.rows[i].itemId));
            widget.onOpenCancel?.call(group.rows[i].itemId, url);
          },
          onRemove: () => widget.onRemove?.call(group.rows[i].itemId),
        ),
      ],
    ],
    const SizedBox(height: 24),
    Text(
      // The limit, said plainly and last. The app cannot cancel anything: it
      // has no account with any vendor and never will. Anything vaguer here
      // would let a user believe tapping the button did the deed.
      S.t.cancelDisclaimer,
      style: SubdockText.caption,
    ),
  ];

  void _toggle(String id) => setState(() => _open = _open == id ? null : id);
}

/// One plan that costs less yearly: the row, and its reasoning behind a tap.
///
/// The reasoning is behind a tap rather than always visible because there are
/// two audiences. Someone scanning wants the name and the number; someone about
/// to act on it needs the multiplication, the date the price was checked, and
/// the warning when their own price disagrees. Showing all of that on every row
/// makes the list unscannable and the total unreachable.
class _YearlyCard extends StatelessWidget {
  final YearlyRow row;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(YearlyChoice) onChoose;

  const _YearlyCard({
    required this.row,
    required this.expanded,
    required this.onToggle,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              ServiceTile(row.name, iconName: row.iconName, size: 34),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.itemName,
                ),
              ),
              if (row.reminding) ...[
                Icon(
                  Icons.notifications_active_rounded,
                  size: 17,
                  color: SubdockColors.savings,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                row.saving,
                style: SubdockText.monoValue.copyWith(
                  fontSize: 16,
                  color: SubdockColors.savings,
                ),
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
          const SizedBox(height: 12),
          Text(row.compare, style: SubdockText.monoInline),
          const SizedBox(height: 7),
          Text(
            row.note,
            style: row.stale
                ? SubdockText.footnote.copyWith(color: SubdockColors.ink)
                : SubdockText.caption,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _SavingsButton(
                  label: row.reminding
                      ? S.t.reminderSetFor(row.remindOn)
                      : S.t.remindMeOn(row.remindOn),
                  outlined: row.reminding,
                  onTap: () => onChoose(
                    row.reminding
                        ? YearlyChoice.undecided
                        : YearlyChoice.remind,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              QuietButton(
                S.t.skip,
                onPressed: () => onChoose(YearlyChoice.skipped),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The monthly plans with no yearly price in the catalogue, folded away.
class _UnpricedFold extends StatelessWidget {
  final List<UnpricedRow> rows;
  final bool open;
  final VoidCallback onToggle;
  final void Function(String itemId)? onOpenItem;

  const _UnpricedFold({
    required this.rows,
    required this.open,
    required this.onToggle,
    this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.t.noYearlyPriceYet(rows.length),
                      style: SubdockText.itemSubtitle.copyWith(fontSize: 15),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: SubdockColors.inkMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (open)
          for (final row in rows) ...[
            const SizedBox(height: SubdockSpacing.rowGap),
            GroupedCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              children: [
                InkWell(
                  onTap: () => onOpenItem?.call(row.itemId),
                  child: Row(
                    children: [
                      ServiceTile(row.name, iconName: row.iconName, size: 34),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SubdockText.itemName,
                        ),
                      ),
                      Text(
                        S.t.addPrice,
                        style: TextStyle(
                          fontFamily: SubdockText.family,
                          fontSize: 14.5,
                          height: 1,
                          fontWeight: SubdockWeight.medium,
                          color: SubdockColors.savings,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
      ],
    );
  }
}

/// A group's heading: what it is, why it is grouped that way, and its total.
class _GroupHeader extends StatelessWidget {
  final CancelGroup group;

  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    // The discouraged group's heading and total are dimmed rather than green.
    // A bright saving figure beside "health insurance" would read as the app
    // recommending it be dropped.
    final headingColor = group.discouraged
        ? SubdockColors.inkMuted
        : SubdockColors.inkSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.label.toUpperCase(),
                  style: SubdockText.sectionLabel.copyWith(color: headingColor),
                ),
                const SizedBox(height: 5),
                Text(group.hint, style: SubdockText.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            group.total,
            style: SubdockText.monoValue.copyWith(
              fontSize: 14,
              color: group.discouraged
                  ? SubdockColors.inkMuted
                  : SubdockColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One service, with where it is cancelled behind a tap.
class _CancelCard extends StatelessWidget {
  final CancelRow row;
  final bool dim;
  final bool expanded;
  final bool sentTo;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _CancelCard({
    required this.row,
    required this.dim,
    required this.expanded,
    required this.sentTo,
    required this.onToggle,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = row.hasAmount && !dim
        ? SubdockColors.savings
        : SubdockColors.inkMuted;

    return Opacity(
      // Dimmed, not hidden. A service with no cancel page is still one the user
      // pays for, and dropping it off this screen would make the group total
      // look like the whole picture.
      opacity: row.target.canOpen ? 1 : 0.62,
      child: GroupedCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                ServiceTile(row.name, iconName: row.iconName, size: 34),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SubdockText.itemName,
                      ),
                      const SizedBox(height: 4),
                      Text(row.target.via, style: SubdockText.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  row.yearly,
                  style: SubdockText.monoValue.copyWith(color: amountColor),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
            const SizedBox(height: 12),
            Text(row.target.where, style: SubdockText.monoInline),
            if (row.target.canOpen) ...[
              const SizedBox(height: 13),
              _SavingsButton(
                label: sentTo ? S.t.openedOpenAgain : row.target.action!,
                outlined: sentTo,
                onTap: onOpen,
              ),
            ],
            if (sentTo) ...[
              const SizedBox(height: 4),
              QuietButton(
                S.t.cancelledRemove,
                danger: true,
                onPressed: onRemove,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The savings screen's own button: filled green, or outlined once the thing it
/// does has already been done.
///
/// Not [PrimaryButton]. That one is the accent, and the accent on this screen
/// would say "this is the action" about a suggestion the user is free to
/// ignore — while the green says "this is money you keep", which is the only
/// claim these buttons make.
class _SavingsButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onTap;

  const _SavingsButton({
    required this.label,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: outlined ? const Color(0x00000000) : SubdockColors.savings,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        border: outlined
            ? Border.all(color: SubdockColors.savingsEdge, width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: SubdockText.family,
                fontSize: 15.5,
                height: 1,
                fontWeight: SubdockWeight.medium,
                color: outlined
                    ? SubdockColors.savings
                    : SubdockColors.onSavings,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
