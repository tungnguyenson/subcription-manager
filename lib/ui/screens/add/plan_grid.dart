import 'package:flutter/material.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/i18n.dart';

/// One tier of a service, at the cycle the vendor sells it on.
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

  /// The cycle the price is quoted for.
  ///
  /// Carried per option rather than passed to the grid because the grid now
  /// shows every cycle at once: a vendor's monthly and yearly tiers sit side
  /// by side, told apart by the `/ mo` and `/ yr` under the price, and tapping
  /// one sets the form's billing cycle as well as its amount. Filtering the
  /// grid by the cycle the form happened to be on hid half the price list
  /// behind a control the user had not touched yet.
  final Cycle cycle;

  /// The day the price was read off the vendor's page.
  final String checkedAt;

  const PlanOption({
    required this.tier,
    required this.label,
    required this.price,
    required this.cycle,
    required this.checkedAt,
  });

  /// `/ mo`, `/ yr` — the unit that turns a bare figure into a price.
  String? get per => ItemPresenter.cyclePer(cycle);

  /// What a lit tile is remembered as.
  ///
  /// The tier alone is not enough now that the grid holds every cycle at
  /// once: a vendor selling one plan two ways gives both tiles the same
  /// slug — Disney+ ships `premium` monthly and `premium` yearly — and
  /// matching on the slug lit both of them, which said the user had chosen
  /// two prices at once.
  String get id => '$tier·${cycle.unit.name}${cycle.step}';
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
/// a tile fills the cost field and sets the cycle, both of which the user can
/// then overwrite; the way out is the last tile rather than a line of prose
/// under the grid, so "none of these" is answered in the same gesture as "this
/// one".
class PlanGrid extends StatelessWidget {
  final List<PlanOption> options;

  /// The chosen tile's [PlanOption.id], or null when the user has typed their
  /// own amount.
  final String? selected;

  final ValueChanged<PlanOption> onSelect;

  /// Opens the cost field. Null leaves the tile off the grid.
  final VoidCallback? onOther;

  const PlanGrid({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.onOther,
  });

  /// The tiers of [entry] for one region, cheapest cycle first.
  ///
  /// Region falls back the way the rest of the app does: Vietnam first, because
  /// that is the money that actually leaves a card here, then global. Mixing the
  /// two would put a dong price beside a dollar one and invite the user to
  /// compare them.
  ///
  /// Every cycle the vendor publishes, not just the one the form is set to.
  /// The `/ mo` and `/ yr` on the tiles are what keeps the two readable side by
  /// side, and a yearly tier is the one number a monthly-billed user most wants
  /// to see before they commit.
  static List<PlanOption> optionsFor(CatalogEntry entry) {
    for (final region in const ['VN', 'GLOBAL']) {
      final plans = entry.plans.where((p) => p.region == region).toList()
        ..sort((a, b) {
          // Short cycles first, so `/ mo` tiles group above `/ yr` ones rather
          // than interleaving by price -- a yearly figure is ten times a
          // monthly one and would otherwise sink to the bottom of the grid
          // whatever tier it is.
          final byCycle = _cycleDays(a.cycle).compareTo(_cycleDays(b.cycle));
          if (byCycle != 0) return byCycle;
          return a.amountMinor.compareTo(b.amountMinor);
        });
      if (plans.isEmpty) continue;

      // One tile per tier and cycle. A vendor listing the same tier twice in
      // one region and cycle is a data error, and showing both would make the
      // grid look like the service has two identical plans.
      final seen = <String>{};
      return [
        for (final plan in plans)
          if (seen.add('${plan.tier}·${plan.cycle}'))
            PlanOption(
              tier: plan.tier,
              label: plan.name,
              price: Money(plan.amountMinor, plan.currency),
              cycle: plan.cycle,
              checkedAt: plan.checkedAt,
            ),
      ];
    }
    return const [];
  }

  /// Roughly how long a cycle is, for ordering only. A month counts as thirty
  /// days, which is wrong by a day or two and right about the order.
  static int _cycleDays(Cycle cycle) =>
      cycle.unit == CycleUnit.day ? cycle.step : cycle.step * 30;

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

    final other = onOther;
    final count = options.length + (other == null ? 0 : 1);

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
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == options.length) {
          // Armed while no tile is lit, which is also when it is the only way
          // forward: a service the catalogue prices but this user pays a
          // different amount for.
          return _OtherTile(armed: selected == null, onTap: other!);
        }
        return _PlanTile(
          option: options[i],
          selected: options[i].id == selected,
          onTap: () => onSelect(options[i]),
        );
      },
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
    final ink = selected ? SubdockColors.accent : SubdockColors.inkSecondary;

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
                Text.rich(
                  TextSpan(
                    text: MoneyFormat.full(option.price),
                    children: [
                      // The unit, not a second figure: two tiles reading
                      // 260,000 and 2,600,000 are the same plan billed two
                      // ways, and without `/ mo` beside one of them the grid
                      // looks like a tenfold price rise.
                      if (option.per case final per?)
                        TextSpan(
                          text: '  $per',
                          style: SubdockText.monoValue.copyWith(
                            fontSize: 12.5,
                            color: SubdockColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.monoValue.copyWith(
                    fontSize: 15.5,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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

/// The way past the grid, as a tile in it.
///
/// It used to be a sentence under the grid — "Paying a different amount?
/// Enter it" — which put the answer to "none of these" in a different shape,
/// a different place and a different weight from the answer to "this one". A
/// tile is the same gesture as every other option here.
///
/// Drawn unfilled so it never reads as a plan: no card behind it, and an inset
/// rule instead of a border. The rule is the accent while nothing is chosen,
/// because then this is the only live way forward, and drops back to the
/// separator once a tile is lit.
class _OtherTile extends StatelessWidget {
  final bool armed;
  final VoidCallback onTap;

  const _OtherTile({required this.armed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        border: Border.all(
          color: armed ? SubdockColors.accent : SubdockColors.hairline,
          width: 1.5,
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
                  S.t.planOtherAmount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 15.5,
                    height: 1.2,
                    fontWeight: SubdockWeight.medium,
                    color: armed
                        ? SubdockColors.accent
                        : SubdockColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  S.t.planTypeItYourself,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 13,
                    height: 1.3,
                    color: SubdockColors.inkMuted,
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
