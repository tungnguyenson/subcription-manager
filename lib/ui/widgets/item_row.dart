import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// How a run of rows is separated.
enum ItemRowStyle {
  /// A rule under each row, and nothing else: no fill, no radius, no gap. The
  /// default, and what Upcoming draws.
  ///
  /// The rows on Upcoming are a *list*, and a list is read by running an eye
  /// down it. Giving each row its own translucent card put four edges and a
  /// 10px moat around every line, so a screen of eight items read as eight
  /// separate objects that happened to be stacked — and the moats and the
  /// hairlines together spent about a fifth of the screen saying nothing. A
  /// rule says the same thing in one pixel.
  ///
  /// The cost is real and worth naming: an overdue row can no longer carry a
  /// danger fill and a danger edge, because with no card there is nothing to
  /// fill. It signals with its countdown pill instead, which is the loudest
  /// thing on the row either way.
  dividers,

  /// Each row its own translucent card, with a gap between them. Kept for a
  /// caller that wants the old look back.
  cards,
}

/// One line in the Upcoming list.
///
/// Three columns: the service mark, the name and what it costs, and the
/// countdown. The countdown column is mono and right-aligned, which is what
/// lets a reader scan straight down it — the whole reason the date is not
/// folded into the subtitle.
class ItemRow extends StatelessWidget {
  final String name;

  /// The amount, the instalment count — whatever the second line carries.
  /// Optional: a document has no amount and inventing one would be noise.
  final String? subtitle;

  /// Which card or account pays for it, appended to the second line after a
  /// separator. Quieter than the amount it follows: it answers "which card",
  /// which is a question the user only asks once they have read the amount.
  final String? sourceName;

  /// The chosen icon's key, or null to let the name decide.
  final String? iconName;

  /// The human phrase: `Tomorrow`, `6d`, `Late`.
  final String when;

  /// The literal date under it, or how long ago it lapsed.
  final String date;

  /// Puts the countdown in a filled danger pill. The name and amount are
  /// untouched — an overdue item is still the same item, and re-colouring the
  /// whole row would make the list look like a list of errors.
  ///
  /// Under [ItemRowStyle.cards] it also swaps the row's fill and edge for the
  /// danger pair. Under [ItemRowStyle.dividers] there is no fill to swap, and
  /// the pill carries it alone.
  final bool overdue;

  /// A free trial: the name is followed by a `FREE TRIAL` badge.
  ///
  /// A badge and nothing else. This used to tint three things at once — the
  /// card's edge, the amount and the countdown — and the design is right to cut
  /// them: a trial is a *fact about the item*, not a level of urgency, and
  /// three accented signals for one fact turn a list with four trials in it
  /// into a list that looks four-fifths highlighted. The word says it exactly,
  /// and it says it to a reader who cannot tell the accent from the ink.
  final bool trial;

  /// Cancelled, with the paid-up period still running.
  ///
  /// Takes the badge slot from [trial] when both are true, and there is one
  /// slot on purpose: two badges after the name leave the name about four
  /// characters, on the line the row exists to show. Cancelled wins because it
  /// is the fact that changed and the one with a decision behind it -- the
  /// trial is ending either way, and the amount on the second line already
  /// says what the trial was about.
  final bool cancelled;

  /// How this row separates itself from the one under it. See [ItemRowStyle].
  final ItemRowStyle style;

  final VoidCallback? onTap;

  const ItemRow({
    super.key,
    required this.name,
    this.subtitle,
    this.sourceName,
    this.iconName,
    required this.when,
    required this.date,
    this.overdue = false,
    this.trial = false,
    this.cancelled = false,
    this.style = ItemRowStyle.dividers,
    this.onTap,
  });

  /// The rule under a row, and the row's own padding.
  ///
  /// 2px of side padding rather than 14: with no card around it the row has
  /// nothing to be inset from, and the name should start on the same left edge
  /// as the section heading above it. 15px top and bottom because the row now
  /// has to hold its own height instead of borrowing it from a card.
  static const EdgeInsets _dividerPadding = EdgeInsets.symmetric(
    horizontal: 2,
    vertical: 15,
  );

  static const EdgeInsets _cardPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 13,
  );

  @override
  Widget build(BuildContext context) {
    final cards = style == ItemRowStyle.cards;

    // Overdue takes the whole card, but only where there is one. That one *is*
    // urgency: something has already gone wrong and the row has to be findable
    // from across the list. With no card the pill carries it alone.
    final decoration = cards
        ? (overdue ? SubdockSurface.overdue() : SubdockSurface.card())
        : BoxDecoration(
            border: Border(bottom: BorderSide(color: SubdockColors.hairline)),
          );

    return Container(
      decoration: decoration,
      // Only a card clips: the rule is drawn on the outside of the padding and
      // an antialiased clip on a border-only box costs a saveLayer per row.
      clipBehavior: cards ? Clip.antiAlias : Clip.none,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: cards ? _cardPadding : _dividerPadding,
            child: Row(
              children: [
                ServiceTile(
                  name,
                  iconName: iconName,
                  size: ServiceTile.listSize,
                  radius: ServiceTile.listRadius,
                  fontSize: ServiceTile.listFontSize,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Flexible, not Expanded: the badge sits directly
                          // after the name rather than pushed to the far right,
                          // which is what makes it read as part of the name and
                          // not as a second column.
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SubdockText.itemName,
                            ),
                          ),
                          if (cancelled) ...[
                            const SizedBox(width: 8),
                            StatusBadge(S.t.cancelledBadge, quiet: true),
                          ] else if (trial) ...[
                            const SizedBox(width: 8),
                            StatusBadge(S.t.freeTrialBadge),
                          ],
                        ],
                      ),
                      if (subtitle != null || sourceName != null) ...[
                        const SizedBox(height: 3),
                        _SecondLine(subtitle: subtitle, sourceName: sourceName),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DueStack(countdown: when, date: date, urgent: overdue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The amount, then the source after a middot.
///
/// A [Row] rather than one interpolated string, because the two halves have to
/// truncate differently: a long service plan name ("Free now · then $20.00 /
/// mo") may be cut, and "· Momo" never may — a source that ellipsises to "· M"
/// is worse than no source at all.
class _SecondLine extends StatelessWidget {
  final String? subtitle;
  final String? sourceName;

  const _SecondLine({this.subtitle, this.sourceName});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (subtitle != null)
          Flexible(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SubdockText.itemSubtitle,
            ),
          ),
        if (sourceName != null)
          Text(
            subtitle == null ? sourceName! : ' · $sourceName',
            maxLines: 1,
            style: SubdockText.itemAside,
          ),
      ],
    );
  }
}

/// The callout at the top of Upcoming: notifications are off, and anything else
/// the user has to see before the list itself.
///
/// Faint rather than red, and no icon. It has to be noticed on the way past
/// without competing with the overdue section directly beneath it — which in
/// the Glass theme means it is the *palest* surface on the screen rather than
/// the most coloured one. A red panel above a list of red rows loses the list.
class AlertBanner extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AlertBanner({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.card(color: SubdockColors.banner),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: SubdockWeight.medium,
                    color: SubdockColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: SubdockText.itemSubtitle.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 12),
            Material(
              color: SubdockColors.accent,
              borderRadius: BorderRadius.circular(SubdockRadius.chip),
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(SubdockRadius.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontFamily: SubdockText.family,
                      fontSize: 15,
                      height: 1,
                      fontWeight: SubdockWeight.medium,
                      color: SubdockColors.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
