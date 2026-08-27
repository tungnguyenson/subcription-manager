import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The amount, and which currency it is in.
///
/// The symbol chips are not decoration: the same digits mean two things a
/// thousand-fold apart, and the app converts one to the other for its totals.
/// So the chip is beside the number rather than in a settings screen, and the
/// converted line sits under it with the rate that produced it.
///
/// Which chips are offered follows the base currency; see [offered].
class CostField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// The code this amount is in. Decides the allowed characters and which
  /// chip is lit.
  final String currency;

  final ValueChanged<String> onCurrency;

  /// Which currencies the chips offer.
  ///
  /// The base first, then the two the app holds a rate between. Three at most,
  /// and usually two, because a row of chips is a row of things the user has
  /// to rule out before typing — and a fourth currency the app cannot relate
  /// to any of the others earns its place on nobody's form.
  static List<String> offered(String base) => [
    base.toUpperCase(),
    for (final code in CurrencyCatalog.ratedPair)
      if (code != base.toUpperCase()) code,
  ];

  /// `≈ 520,000 ₫ · 26,046 ₫/$`, or null when there is nothing to convert.
  final String? convertedLine;

  const CostField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.currency,
    required this.onCurrency,
    this.convertedLine,
  });

  @override
  Widget build(BuildContext context) {
    // VND has no minor unit, so its field has no decimal point to offer and
    // no decimal key to put on the keyboard.
    final exponent = Currencies.exponentOf(currency);
    final converted = convertedLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldBox(
          focused: focusNode.hasFocus,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  // Always decimal-capable, even under a currency with no minor
                  // unit. Two reasons, and neither is about dong.
                  //
                  // Flutter does not push a changed `keyboardType` to a field
                  // that already has focus: the pad that came up under ₫ was
                  // still on screen after tapping $, with no separator key on
                  // it. Keeping the type constant removes that entirely.
                  //
                  // And the key is not dead under ₫: `parseMajor` rounds half
                  // up, so `20.5` becomes 21 ₫ rather than being swallowed.
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // The amount is typed the way it is written — 20.50, not
                  // 2050 — so the separators it is written with have to be
                  // typeable. Both marks are allowed through: iOS labels the
                  // pad's separator key in the device's locale, so a phone set
                  // to Vietnamese offers a comma where a phone set to English
                  // offers a full stop, and the user cannot choose. Which one
                  // they meant is worked out in `parseMajor`, not here.
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: SubdockText.monoValue,
                  cursorColor: SubdockColors.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    // A plausible amount rather than a zero. `0` reads as a
                    // value the field is already holding — free — where a
                    // shaped number reads as the shape of the answer. It
                    // follows the currency chip beside it, because 231,000
                    // under a dollar sign would be teaching the wrong shape.
                    hintText: exponent > 0 ? '9.99' : '231,000',
                    hintStyle: SubdockText.fieldValue.copyWith(
                      color: SubdockColors.inkMuted,
                    ),
                  ),
                ),
              ),
              for (final code in offered(Fx.base)) ...[
                const SizedBox(width: 5),
                ChoiceChipPill(
                  CurrencyCatalog.symbolOf(code),
                  selected: currency.toUpperCase() == code,
                  onField: true,
                  onTap: () => onCurrency(code),
                ),
              ],
            ],
          ),
        ),
        if (converted != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(converted, style: SubdockText.monoInline),
          ),
      ],
    );
  }
}
