import 'package:flutter/material.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';

/// One tier of a service, at the cycle the form is set to.
@immutable
class PlanOption {
  /// The catalogue's [CatalogPlan.tier]: a slug, and what a selection is
  /// stored and compared as. Not what the tile says.
  final String tier;

  /// What the tile says: `Premium`, `Individual`, `200 GB`. The catalogue
  /// carries this beside the slug because the two differ — `50gb` against
  /// `50GB`, and on the merged phone-plan entry `viettel-5g150` against
  /// `Viettel 5G150`, where the tier has to spell out the carrier because one
  /// entry now holds six of them.
  final String label;

  final Money price;

  /// The day the price was read off the vendor's page.
  final String checkedAt;

  const PlanOption({
    required this.tier,
    required this.label,
    required this.price,
    required this.checkedAt,
  });
}

/// The published tiers of one service, as tappable tiles.
///
/// Two columns of price-over-name, and the price is the bigger of the two on
/// purpose: someone who knows they are on Netflix but cannot remember which
/// plan recognises the amount on their statement long before they recognise the
/// word "Standard".
///
/// Every price here has a vendor page and a date behind it — that is a hard rule
/// on [CatalogPlan] — but it is still a *listed* price, not the user's. Tapping
/// a tile fills the cost field, which the user can then overwrite; the
/// provenance line under the grid says where the number came from so a
/// disagreement reads as "my price differs" rather than "the app is wrong".
class PlanGrid extends StatelessWidget {
  final List<PlanOption> options;

  /// The chosen tier, or null when the user has typed their own amount.
  final String? selected;

  final ValueChanged<PlanOption> onSelect;

  const PlanGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  /// The tiers of [entry] for one region and cycle, cheapest first.
  ///
  /// Region falls back the way the rest of the app does: Vietnam first, because
  /// that is the money that actually leaves a card here, then global. Mixing the
  /// two would put a dong price beside a dollar one and invite the user to
  /// compare them.
  static List<PlanOption> optionsFor(CatalogEntry entry, Cycle cycle) {
    for (final region in const ['VN', 'GLOBAL']) {
      final plans =
          entry.plans
              .where((p) => p.region == region && p.cycle == cycle)
              .toList()
            ..sort((a, b) => a.amountMinor.compareTo(b.amountMinor));
      if (plans.isEmpty) continue;

      // One tile per tier. A vendor listing the same tier twice in one region
      // and cycle is a data error, and showing both would make the grid look
      // like the service has two identical plans.
      final seen = <String>{};
      return [
        for (final plan in plans)
          if (seen.add(plan.tier))
            PlanOption(
              tier: plan.tier,
              label: plan.name,
              price: Money(plan.amountMinor, plan.currency),
              checkedAt: plan.checkedAt,
            ),
      ];
    }
    return const [];
  }

  /// Vertical padding, the price line, the gap, the tier line.
  ///
  /// Plus a few points of slack: a line box is the font's own ascent and
  /// descent, which for both faces here runs a little past `fontSize * height`.
  /// A tile short by two points overflows and Flutter paints the stripes.
  static double _tileHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 14 * 2 + scaler.scale(15.5) * 1.2 + 5 + scaler.scale(13) * 1.3 + 6;
  }

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // A price over a tier, and nothing else. The catalogue also carries a
        // per-plan note, and it used to sit here as a third line: it never
        // fitted -- 82pt holds two lines, so the note was clipped through the
        // middle of its own glyphs -- and it is written in Vietnamese while
        // every other word in this app's interface is English. The hand-off
        // draws two lines. Sized from the text scale rather than a constant,
        // because the tile is fixed-height and a reader at 150% would clip the
        // tier the same way.
        mainAxisExtent: _tileHeight(context),
      ),
      itemCount: options.length,
      itemBuilder: (context, i) => _PlanTile(
        option: options[i],
        selected: options[i].tier == selected,
        onTap: () => onSelect(options[i]),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final PlanOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        border: Border.all(
          color: selected ? SubdockColors.accent : SubdockColors.glassEdge,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoneyFormat.full(option.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.monoValue.copyWith(
                    fontSize: 15.5,
                    color: selected
                        ? SubdockColors.accent
                        : SubdockColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 13,
                    height: 1.3,
                    color: SubdockColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
