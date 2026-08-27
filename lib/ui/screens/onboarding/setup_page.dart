import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_picks.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/currency_picker.dart';
import 'package:subdock/ui/widgets/language_sheet.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The second onboarding page: the two things the app cannot work out on its
/// own and would be wrong about if it guessed.
///
/// Both are asked here rather than left in Settings, and both for the same
/// reason. A phone set to English in Hanoi says nothing reliable about which
/// currency the bills arrive in, and a person reading the app in the wrong
/// language will not find the setting that fixes it. Asked once, on a screen
/// that is already being read, they cost one tap each.
///
/// Language comes first, and that order is load-bearing rather than tidy: the
/// currency block below it is the longer question, and answering it first in a
/// language the reader cannot read means answering it twice.
///
/// There is no paragraph under the title. The page is a title, two headings
/// and their controls, and every sentence added here pushes the second
/// currency card and the button under it off a 390x844 frame. What had to be
/// said is said where it applies: under the default chips, and under a
/// currency the app holds no rate for.
class SetupPage extends StatelessWidget {
  final CurrencyPicks picks;
  final AppLocale locale;

  final ValueChanged<CurrencyPicks> onCurrency;
  final ValueChanged<AppLocale> onLocale;

  const SetupPage({
    super.key,
    required this.picks,
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
          // it takes a third of the block below it with it.
          style: SubdockText.onboardTitle.copyWith(fontSize: 23, height: 1.3),
        ),
        SectionLabel(S.t.onboardLanguageLabel, tight: true),
        PickerField(
          // The language's own name, always. This is the one label in the app
          // that must not follow the language currently in force: someone who
          // cannot read the interface is looking for the word they *can* read,
          // and translating it hides it from them.
          value: locale.label,
          onTap: () async {
            final picked = await LanguageSheet.show(context, locale);
            if (picked != null) onLocale(picked);
          },
        ),
        SectionLabel(S.t.onboardCurrencyLabel),
        CurrencyPicker(picks: picks, onChanged: onCurrency),
      ],
    );
  }
}
