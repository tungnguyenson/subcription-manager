import 'package:flutter/material.dart';

import 'package:subdock/i18n.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The language picker, reached from the Settings row that shows the answer.
///
/// A sheet with two rows rather than a screen. There are two languages and
/// there is no third thing to say about either, so a pushed screen would be a
/// title bar and a back button wrapped around one decision.
class LanguageSheet extends StatelessWidget {
  final AppLocale selected;

  const LanguageSheet({super.key, required this.selected});

  static Future<AppLocale?> show(BuildContext context, AppLocale selected) =>
      showModalBottomSheet<AppLocale>(
        context: context,
        backgroundColor: const Color(0x00000000),
        builder: (sheet) => LanguageSheet(selected: selected),
      );

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);

    return Container(
      decoration: SubdockSurface.sheet(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 16),
            for (final option in AppLocale.values)
              InkWell(
                onTap: () => Navigator.of(context).pop(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Each in its own language, always. Someone opening
                          // this sheet is usually here because the interface
                          // is in a language they cannot read, and translating
                          // both labels hides the one they are looking for.
                          option.label,
                          style: SubdockText.rowValue,
                        ),
                      ),
                      PickMark(selected: option == selected),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
