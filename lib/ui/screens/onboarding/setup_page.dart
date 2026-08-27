import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/widgets/currency_row.dart';
import 'package:subdock/ui/widgets/currency_sheet.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The second onboarding page: the two things the app cannot work out on its
/// own and would be wrong about if it guessed.
///
/// Both are asked here rather than left in Settings, and both for the same
/// reason. A phone set to English in Hanoi says nothing reliable about which
/// currency the bills arrive in, and a person reading the app in the wrong
/// language will not find the setting that fixes it. Asked once, on a screen
/// that is already being read, they cost one tap each.
class SetupPage extends StatelessWidget {
  final String currency;
  final AppLocale locale;

  final ValueChanged<String> onCurrency;
  final ValueChanged<AppLocale> onLocale;

  const SetupPage({
    super.key,
    required this.currency,
    required this.locale,
    required this.onCurrency,
    required this.onLocale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.t.onboardCurrencyTitle,
          // 23, from the design, and the reason it is not the app's own
          // `onboardTitle` size: this sentence has to hold one line. Wrapped
          // it takes a third of the card stack's height with it.
          style: SubdockText.onboardTitle.copyWith(fontSize: 23, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          S.t.onboardCurrencyBody,
          style: SubdockText.summary.copyWith(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 18),
        for (final code in _offered) ...[
          CurrencyRow(
            code: code,
            selected: code == currency,
            onTap: () => onCurrency(code),
          ),
          const SizedBox(height: 8),
        ],
        _OtherCurrency(
          onTap: () async {
            final picked = await CurrencySheet.show(context, currency);
            if (picked != null) onCurrency(picked);
          },
        ),
        if (!CurrencyCatalog.isConvertible(currency)) ...[
          const SizedBox(height: 12),
          Footnote(S.t.onboardNoRateNote),
        ],
        const SizedBox(height: 26),
        SectionLabel(S.t.onboardLanguageLabel, tight: true),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final option in AppLocale.values) ...[
              if (option != AppLocale.values.first) const SizedBox(width: 8),
              Expanded(
                child: _LanguageTile(
                  locale: option,
                  selected: option == locale,
                  onTap: () => onLocale(option),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The four featured codes, plus the current pick when it came from the
  /// search sheet.
  ///
  /// Appended rather than substituted into the four. A list that swapped one
  /// out would move the other rows under the user's finger the moment they
  /// came back from the sheet, and the tick they just placed would be sitting
  /// somewhere they did not put it.
  List<String> get _offered => [
    ...CurrencyCatalog.featured,
    if (!CurrencyCatalog.featured.contains(currency)) currency,
  ];
}

/// The dashed row into the full list.
///
/// Dashed rather than a card with a chevron, because it is not a currency: a
/// fifth solid row shaped like the four above it would read as a fifth option
/// and get tapped by someone who wanted dollars.
class _OtherCurrency extends StatelessWidget {
  final VoidCallback onTap;

  const _OtherCurrency({required this.onTap});

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
          children: [
            Expanded(
              child: Text(
                S.t.onboardOtherCurrency,
                style: SubdockText.rowLink.copyWith(
                  fontSize: 15,
                  color: SubdockColors.inkSecondary,
                ),
              ),
            ),
            Caret(),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLocale locale;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.locale,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: selected
            ? SubdockSurface.accented(radius: 13)
            : SubdockSurface.card(radius: 13),
        child: Text(
          // The language's own name, always. This is the one label in the app
          // that must not follow the language currently in force: someone who
          // cannot read the interface is looking for the word they *can*
          // read, and translating both tiles hides it from them.
          locale.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SubdockText.rowValue.copyWith(
            fontSize: 15,
            color: selected ? SubdockColors.accent : SubdockColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
