import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One search box, used by every list in the app that has one.
///
/// It lives here rather than beside its first caller because the second caller
/// -- the icon gallery -- would otherwise have copied it, and two search boxes
/// drawn from two copies drift: one grows a clear button, the other keeps a
/// different hint colour, and nobody notices until they are side by side.
///
/// The clear button appears only when there is something to clear, so the
/// caller has to rebuild as the text changes. Every caller already does, since
/// the whole point of the field is filtering a list underneath it.
class SearchField extends StatelessWidget {
  final TextEditingController controller;

  final String hint;

  /// The keyboard's submit key. Null leaves it as a plain dismiss, which is
  /// what a field that filters as you type wants.
  final VoidCallback? onSubmitted;

  final bool autofocus;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FieldBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: SubdockColors.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: onSubmitted == null
                  ? TextInputAction.done
                  : TextInputAction.search,
              onSubmitted: (_) => onSubmitted?.call(),
              style: SubdockText.fieldValue,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 16,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
