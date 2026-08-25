import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One line in the Upcoming list, and its own card.
///
/// Its own card, not a ruled row inside a shared one. The Glass design puts a
/// 10px gap between rows and gives each its own hairline, and that is what lets
/// an overdue row carry the danger edge while the rows above and below it stay
/// plain. A single ruled card can only have one edge, so the overdue row would
/// have to signal itself with colour on its text alone.
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

  /// Puts the countdown in a filled danger pill and swaps the row's edge for
  /// the danger one. The name and amount are untouched — an overdue item is
  /// still the same item, and re-colouring the whole row would make the list
  /// look like a list of errors.
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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Overdue still takes the whole card. That one *is* urgency: something has
    // already gone wrong and the row has to be findable from across the list.
    final decoration = overdue
        ? SubdockSurface.overdue()
        : SubdockSurface.card();

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                ServiceTile(
                  name,
                  iconName: iconName,
                  size: ServiceTile.listSize,
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
                          if (trial) ...[
                            const SizedBox(width: 8),
                            const StatusBadge('Free trial'),
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
                  style: const TextStyle(
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
                    style: const TextStyle(
                      fontFamily: SubdockText.family,
                      fontSize: 15,
                      height: 1,
                      fontWeight: SubdockWeight.medium,
                      color: Color(0xFFFFFFFF),
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
