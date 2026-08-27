import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

class SuggestionRow extends StatelessWidget {
  final String name;
  final String? detail;
  final bool muted;
  final VoidCallback onTap;

  const SuggestionRow({
    super.key,
    required this.name,
    this.detail,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            ServiceTile(
              name,
              size: 30,
              radius: SubdockRadius.tile,
              fontSize: 12,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted ? SubdockText.rowLabel : SubdockText.fieldValue,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 10),
              Text(detail!, style: SubdockText.rowLabel.copyWith(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One sheet for every list-of-options field on the item form.
///
/// A sheet rather than a Material dropdown: the dropdown paints its own menu
/// surface with its own radius and elevation, and there is no way to make that
/// surface agree with the Glass theme.
Future<T?> chooseOption<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: SubdockColors.canvas,
    showDragHandle: true,
    // The list sizes to its own contents either way; this only lifts the
    // ceiling a default sheet puts on it at about half the screen. Most of
    // these are five or six options and never reach it. The shelf list is
    // twenty-two, and half a screen turns picking one into a scroll through a
    // window four rows tall.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SubdockRadius.placard),
      ),
    ),
    // A Builder, not the SafeArea directly: a route's page is built once and
    // cached, so this is the element that has to hold the palette dependency
    // if the sheet is to repaint when the phone goes dark under it.
    builder: (sheet) => Builder(
      builder: (context) {
        SubdockTheme.watch(context);
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              SubdockSpacing.screenH,
              0,
              SubdockSpacing.screenH,
              20,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title.toUpperCase(),
                  style: SubdockText.sectionLabel,
                ),
              ),
              GroupedCard(
                children: [
                  for (final (value, label) in options)
                    DetailRow(
                      // The tick is set in mono because that is the family that
                      // carries the glyph; Be Vietnam Pro has no U+2713 and
                      // would fall back to whatever the platform supplies.
                      label: label,
                      value: value == selected ? '✓' : null,
                      monoValue: true,
                      valueColor: SubdockColors.accent,
                      onTap: () => Navigator.of(sheet).pop(value),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
