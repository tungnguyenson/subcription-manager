import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/domain/currency_picks.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/onboarding/currency_samples.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/currency_sheet.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The declared currencies, and which of them the totals speak.
///
/// One widget rather than a block written into onboarding, because onboarding
/// is shown once and this answer outlives it. Someone who added a second
/// currency at first launch and stopped being billed in it a year later has to
/// have somewhere to go, and the somewhere has to be the same screen they
/// remember — see [CurrencyPicksSheet], which is this widget in a sheet.
class CurrencyPicker extends StatelessWidget {
  final CurrencyPicks picks;
  final ValueChanged<CurrencyPicks> onChanged;

  const CurrencyPicker({
    super.key,
    required this.picks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final code in picks.codes) ...[
          _CurrencyCard(
            code: code,
            // Only once there is a second one. A lone card with a remove
            // control on it offers a state the app cannot render: no currency
            // at all, on a screen whose next tap is `Get started`.
            onRemove: picks.codes.length > 1
                ? () => onChanged(picks.remove(code))
                : null,
            onTap: () => _replace(context, code),
          ),
          const SizedBox(height: 11),
        ],
        if (!picks.isFull) _AddCurrency(onTap: () => _add(context)),
        if (_noRate) Footnote(S.t.onboardNoRateNote),
        if (picks.codes.length > 1) ...[
          SectionLabel(S.t.onboardDefaultLabel, tight: true),
          Row(
            children: [
              for (final code in picks.codes) ...[
                if (code != picks.codes.first) const SizedBox(width: 8),
                Expanded(
                  child: _DefaultChip(
                    code: code,
                    selected: code == picks.base,
                    onTap: () => onChanged(picks.withBase(code)),
                  ),
                ),
              ],
            ],
          ),
          Footnote(S.t.onboardDefaultNote),
        ],
      ],
    );
  }

  /// Whether the combined figure on the Money screen is going to be missing.
  ///
  /// Asked of the declared set, not of the base alone. The app carries one
  /// rate; a list holding dong and euro adds up perfectly per currency and has
  /// no single number, and that is worth saying here rather than leaving to be
  /// discovered later on a screen with no explanation on it.
  bool get _noRate =>
      !CurrencyCatalog.isConvertible(picks.base) ||
      picks.codes.any((code) => !CurrencyCatalog.hasRate(code, picks.base));

  Future<void> _add(BuildContext context) async {
    final picked = await CurrencySheet.show(
      context,
      picks.base,
      taken: picks.codes.toSet(),
    );
    if (picked != null) onChanged(picks.add(picked));
  }

  /// Tapping a card changes *that* slot, leaving the other where it is.
  ///
  /// The sheet opens on the code being replaced rather than on the base, so
  /// the tick is on the row the user tapped through and not on a different
  /// answer to a question they did not ask.
  Future<void> _replace(BuildContext context, String code) async {
    final picked = await CurrencySheet.show(
      context,
      code,
      taken: picks.codes.toSet(),
    );
    if (picked != null) onChanged(picks.replace(code, picked));
  }
}

/// One declared currency, drawn as a bill in it.
class _CurrencyCard extends StatelessWidget {
  final String code;
  final VoidCallback? onRemove;
  final VoidCallback onTap;

  const _CurrencyCard({required this.code, required this.onTap, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final bill = sampleBillFor(code);

    return Container(
      decoration: SubdockSurface.card(radius: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Tight, and measured rather than chosen. The Vietnamese sub line
          // is a third longer than the English one, and with the remove
          // control on the row as well `Standard · hàng tháng` was arriving
          // as `Standard · hàng th…` — see trap 40.
          padding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
          child: Row(
            children: [
              if (bill case final bill?)
                ServiceTile(
                  bill.name,
                  iconName: bill.iconKey,
                  size: 42,
                  radius: 13,
                  fontSize: 18,
                )
              else
                _SymbolTile(code: code),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill?.name ?? code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SubdockText.itemName.copyWith(
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bill == null
                          ? S.t.currencyName(code)
                          : [?bill.tier, S.t.onboardSampleMonthly].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SubdockText.itemSubtitle.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bill case final bill?) ...[
                    Text(
                      MoneyFormat.full(bill.amount),
                      style: SubdockText.monoValue.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    code,
                    style: SubdockText.monoInline.copyWith(
                      fontSize: 12,
                      color: SubdockColors.inkMuted,
                    ),
                  ),
                ],
              ),
              if (onRemove case final remove?) ...[
                const SizedBox(width: 2),
                _RemoveButton(onTap: remove),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The tile for a currency the sample table has nothing for: its own mark.
class _SymbolTile extends StatelessWidget {
  final String code;

  const _SymbolTile({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SubdockColors.thumb,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: SubdockColors.thumbEdge),
      ),
      child: Text(
        CurrencyCatalog.symbolOf(code),
        maxLines: 1,
        style: SubdockText.monoValue.copyWith(
          fontSize: 17,
          color: SubdockColors.inkSecondary,
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.t.onboardRemoveCurrency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: SubdockColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// The dashed row into the full list.
///
/// Dashed rather than a card with a chevron, because it is not a currency: a
/// third solid row shaped like the two above it would read as a third option
/// and get tapped by someone who wanted dollars.
class _AddCurrency extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCurrency({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SubdockRadius.card),
      child: DashedBox(
        radius: SubdockRadius.card,
        color: SubdockColors.hairline,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 19, color: SubdockColors.accent),
            const SizedBox(width: 8),
            Text(
              S.t.onboardAddCurrency,
              style: SubdockText.rowLink.copyWith(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two chips that says which currency the totals speak.
class _DefaultChip extends StatelessWidget {
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _DefaultChip({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: selected
            ? SubdockSurface.accented(radius: 13)
            : SubdockSurface.card(radius: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PickMark(selected: selected, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${CurrencyCatalog.symbolOf(code)} $code',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SubdockText.monoValue.copyWith(
                  fontSize: 14.5,
                  color: selected
                      ? SubdockColors.accent
                      : SubdockColors.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [CurrencyPicker] in a sheet, for Settings.
///
/// The same block, not a second design of the same question. Someone changing
/// this a year after onboarding is looking for the screen they answered it on.
///
/// It reports every change as it happens and returns nothing on the way out,
/// the way onboarding does. There is no OK button because there is nothing to
/// confirm: each control here is one decision, already taken by the time the
/// finger lifts, and a button that could undo all of them at once would be a
/// second and much quieter question.
class CurrencyPicksSheet extends StatefulWidget {
  final CurrencyPicks picks;
  final ValueChanged<CurrencyPicks> onChanged;

  const CurrencyPicksSheet({
    super.key,
    required this.picks,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context,
    CurrencyPicks picks,
    ValueChanged<CurrencyPicks> onChanged,
  ) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0x00000000),
    isScrollControlled: true,
    builder: (sheet) => CurrencyPicksSheet(picks: picks, onChanged: onChanged),
  );

  @override
  State<CurrencyPicksSheet> createState() => _CurrencyPicksSheetState();
}

class _CurrencyPicksSheetState extends State<CurrencyPicksSheet> {
  late CurrencyPicks _picks = widget.picks;

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);

    return Container(
      decoration: SubdockSurface.sheet(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SubdockColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(S.t.onboardCurrencyLabel, style: SubdockText.detailTitle),
              const SizedBox(height: 16),
              CurrencyPicker(
                picks: _picks,
                onChanged: (next) {
                  setState(() => _picks = next);
                  widget.onChanged(next);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
