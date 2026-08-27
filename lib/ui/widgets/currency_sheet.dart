import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/widgets/currency_row.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/search_field.dart';

/// The full currency list, behind the `Add a currency` row and behind a tap
/// on a currency card.
///
/// A sheet rather than a longer list on the page itself. Fifty rows under the
/// question would bury the language section and the button below it, and the
/// one or two cards on the page answer for almost everyone; this is the door
/// for the rest.
///
/// Search matches the code and the name in the language being read, so
/// someone reading Vietnamese finds the yen by typing `yên` and someone
/// reading English finds it by typing `yen`. Both find it by typing `JPY`.
class CurrencySheet extends StatefulWidget {
  /// The code this sheet was opened *on*: the slot being filled or changed.
  final String selected;

  /// Every code already declared, [selected] usually among them.
  ///
  /// Ticked and dimmed rather than hidden. A list that quietly dropped the
  /// currency the user already has would answer "is my dong in here" with an
  /// empty search, and the honest answer is "yes, and you already have it".
  final Set<String> taken;

  const CurrencySheet({
    super.key,
    required this.selected,
    this.taken = const {},
  });

  /// Resolves to the chosen code, or null if the user backed out.
  static Future<String?> show(
    BuildContext context,
    String selected, {
    Set<String> taken = const {},
  }) => showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0x00000000),
    isScrollControlled: true,
    builder: (sheet) => CurrencySheet(selected: selected, taken: taken),
  );

  @override
  State<CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<CurrencySheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CurrencyInfo> get _matches {
    final needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return CurrencyCatalog.all;
    return [
      for (final info in CurrencyCatalog.all)
        if (info.code.toLowerCase().contains(needle) ||
            S.t.currencyName(info.code).toLowerCase().contains(needle))
          info,
    ];
  }

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    final matches = _matches;

    return Container(
      // Tall but not full: the strip of page left above it is what says this
      // is a layer over the question rather than a new screen replacing it.
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: SubdockSurface.sheet(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
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
          SearchField(controller: _query, hint: S.t.onboardSearchCurrency),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: matches.length,
              separatorBuilder: (context, _) => Divider(
                height: 1,
                thickness: 1,
                color: SubdockColors.hairline,
              ),
              itemBuilder: (context, i) {
                final code = matches[i].code;
                final held = widget.taken.contains(code);
                return Opacity(
                  // Dimmed, not disabled. Tapping one still closes the sheet
                  // on that code, and the caller works out that nothing
                  // changed -- which is a great deal easier to understand
                  // than a row that swallows the tap.
                  opacity: held && code != widget.selected ? 0.5 : 1,
                  child: CurrencyRow(
                    code: code,
                    selected: held || code == widget.selected,
                    flat: true,
                    onTap: () => Navigator.of(context).pop(code),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
