import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One line in the Upcoming list.
///
/// Three columns: the service mark, the name and what it costs, and the
/// countdown. The countdown column is set in mono and right-aligned, which is
/// what lets a reader scan straight down it — the whole reason the date is not
/// folded into the subtitle.
class ItemRow extends StatelessWidget {
  final String name;

  /// The amount, the instalment count — whatever the second line carries.
  /// Optional: a document has no amount and inventing one would be noise.
  final String? subtitle;

  /// The chosen icon's key, or null to let the name decide.
  final String? iconName;

  /// The human phrase: `Tomorrow`, `6 days`, `Overdue`.
  final String when;

  /// The literal date under it, or how long ago it lapsed.
  final String date;

  /// Turns the countdown red. Nothing else on the row changes: an overdue item
  /// is still the same item, and re-colouring the whole row would make the
  /// list look like a list of errors.
  final bool overdue;

  final VoidCallback? onTap;

  const ItemRow({
    super.key,
    required this.name,
    this.subtitle,
    this.iconName,
    required this.when,
    required this.date,
    this.overdue = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SubdockSpacing.rowH),
          child: Row(
            children: [
              ServiceTile(name, iconName: iconName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SubdockText.itemName,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SubdockText.itemSubtitle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    when,
                    style: overdue
                        ? SubdockText.when.copyWith(color: SubdockColors.danger)
                        : SubdockText.when,
                  ),
                  const SizedBox(height: 3),
                  Text(date, style: SubdockText.whenDate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tinted callout at the top of Upcoming: notifications are off, and
/// anything else the user has to see before the list itself.
///
/// Pink rather than red, and no icon. It has to be noticed on the way past
/// without competing with the overdue section directly beneath it.
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
      decoration: BoxDecoration(
        color: SubdockColors.dangerTint,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        boxShadow: SubdockShadow.soft,
      ),
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
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: SubdockColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: SubdockText.itemSubtitle.copyWith(height: 1.45),
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
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: SubdockColors.card,
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
