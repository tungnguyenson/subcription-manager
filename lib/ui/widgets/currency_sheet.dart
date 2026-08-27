import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_catalog.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/widgets/currency_row.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/search_field.dart';

/// The full currency list, behind the `Another currency` row.
///
/// A sheet rather than a longer list on the page itself. Fifty rows under the
/// question would bury the language section and the button below it, and the
/// four on the page answer for almost everyone; this is the door for the rest.
///
/// Search matches the code and the name in the language being read, so
/// someone reading Vietnamese finds the yen by typing `yên` and someone
/// reading English finds it by typing `yen`. Both find it by typing `JPY`.
class CurrencySheet extends StatefulWidget {
  final String selected;

  const CurrencySheet({super.key, required this.selected});

  /// Resolves to the chosen code, or null if the user backed out.
  static Future<String?> show(BuildContext context, String selected) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0x00000000),
        isScrollControlled: true,
        builder: (sheet) => CurrencySheet(selected: selected),
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
              itemBuilder: (context, i) => CurrencyRow(
                code: matches[i].code,
                selected: matches[i].code == widget.selected,
                flat: true,
                onTap: () => Navigator.of(context).pop(matches[i].code),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
