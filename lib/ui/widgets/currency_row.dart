import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One currency in a picker: its mark, its code, its name, and a tick.
///
/// Shared by the four featured rows on the onboarding page and by every row in
/// the full search sheet, so the two cannot drift apart — the sheet is where
/// someone goes when the four are wrong for them, and arriving at a
/// differently shaped list would read as a different question.
class CurrencyRow extends StatelessWidget {
  final String code;
  final bool selected;
  final VoidCallback? onTap;

  /// Set on the rows inside the search sheet, which sit on a plain sheet and
  /// are separated by hairlines rather than each being its own card.
  final bool flat;

  const CurrencyRow({
    super.key,
    required this.code,
    required this.selected,
    this.onTap,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: flat ? 2 : 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SubdockColors.thumb,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: SubdockColors.thumbEdge),
            ),
            child: Text(
              CurrencyCatalog.symbolOf(code),
              maxLines: 1,
              style: SubdockText.monoValue.copyWith(
                fontSize: 16,
                color: selected
                    ? SubdockColors.accent
                    : SubdockColors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: SubdockText.itemName.copyWith(
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.t.currencyName(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.itemSubtitle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PickMark(selected: selected),
        ],
      ),
    );

    final tappable = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SubdockRadius.card),
      child: row,
    );

    if (flat) return tappable;

    return Container(
      decoration: selected ? SubdockSurface.accented() : SubdockSurface.card(),
      clipBehavior: Clip.antiAlias,
      child: tappable,
    );
  }
}
