import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// One service on the list, already worded.
class ServiceToggle {
  final String id;
  final String name;

  /// `Next 22/08 · 260,000 ₫`, or `Off · no reminders`. The second line is
  /// what the switch actually did, said in words — a greyed row with a switch
  /// to the left of centre is not self-explanatory.
  final String subtitle;

  final String? iconName;
  final bool on;

  /// Cancelled, with the paid-up period still running.
  ///
  /// Distinct from [on] being false, and both can be true at once. The switch
  /// is about whether the user wants to hear about it; this is about what has
  /// happened to the subscription. Without the badge the two are the same row
  /// -- and the switch, which is the loudest thing on it, would be describing
  /// the smaller of the two facts.
  final bool cancelled;

  const ServiceToggle({
    required this.id,
    required this.name,
    required this.subtitle,
    this.iconName,
    required this.on,
    this.cancelled = false,
  });
}

/// One shelf of services, already labelled.
///
/// The label is a catalogue sector — Streaming, Music, Mobile and SIM — or, for
/// items the catalogue does not know, the leftovers group its category falls
/// into. `ServicesPresenter.groups` decides both; the screen only renders what
/// it is handed.
class ServiceGroup {
  final String label;
  final List<ServiceToggle> rows;

  const ServiceGroup({required this.label, required this.rows});
}

/// Everything the app is tracking, with a switch per service.
///
/// This screen exists because Upcoming deliberately does not show everything:
/// it is a list of what is *coming*, so an item eleven months out is folded
/// away and a paused one is gone entirely. Without one screen that lists all of
/// them, "where did my Netflix go" has no answer.
///
/// The switch pauses rather than deletes, and the copy at the top says so
/// outright. A switch that quietly deleted a year of payment history would be
/// the worst affordance in the app, and a user cannot tell which kind it is by
/// looking at it.
class ServicesScreen extends StatelessWidget {
  final List<ServiceGroup> groups;

  final void Function(String id)? onOpen;
  final void Function(String id, bool on)? onToggle;
  final VoidCallback? onAdd;
  final VoidCallback? onBack;

  const ServicesScreen({
    super.key,
    required this.groups,
    this.onOpen,
    this.onToggle,
    this.onAdd,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: onBack),
        Text(S.t.allServices, style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(S.t.servicesLead, style: SubdockText.summary),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 10),
            child: Text(
              group.label.toUpperCase(),
              style: SubdockText.sectionLabel,
            ),
          ),
          GroupedCard(
            children: [
              for (final row in group.rows)
                _ToggleRow(
                  row: row,
                  onOpen: () => onOpen?.call(row.id),
                  onToggle: (on) => onToggle?.call(row.id, on),
                ),
            ],
          ),
        ],
        if (groups.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 26),
            child: Text(S.t.servicesEmpty, style: SubdockText.summary),
          ),
        const SizedBox(height: 20),
        SecondaryButton(S.t.servicesAdd, accent: true, onPressed: onAdd),
      ],
    );
  }
}

/// The row: tap the left two thirds to open the item, tap the switch to pause.
///
/// Two targets in one row, which needs saying because it is unusual. The switch
/// is the reason the screen exists, and the name has to stay tappable or the
/// only way into an item would be a list it might not appear on.
class _ToggleRow extends StatelessWidget {
  final ServiceToggle row;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;

  const _ToggleRow({
    required this.row,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.rowH,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Opacity(
                // The whole left side dims when off, not just the subtitle. A
                // switch alone is read as an option; a dimmed row is read as a
                // thing that is not currently happening, which is what it is.
                opacity: row.on ? 1 : 0.45,
                child: Row(
                  children: [
                    ServiceTile(
                      row.name,
                      iconName: row.iconName,
                      size: ServiceTile.listSize,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Flexible rather than Expanded, so the badge
                              // sits against the name instead of being pushed
                              // out to a column of its own. Same reasoning as
                              // the badge on `ItemRow`.
                              Flexible(
                                child: Text(
                                  row.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SubdockText.itemName.copyWith(
                                    fontSize: 16.5,
                                  ),
                                ),
                              ),
                              if (row.cancelled) ...[
                                const SizedBox(width: 8),
                                StatusBadge(S.t.cancelledBadge, quiet: true),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            row.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SubdockText.caption.copyWith(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: S.t.servicesRemindersFor(row.name),
            child: AppToggle(value: row.on, onChanged: onToggle),
          ),
        ],
      ),
    );
  }
}
