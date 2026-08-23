import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/service_mark.dart';

/// The icon gallery, shown in a sheet from the tile beside the name field.
///
/// A grid rather than a list: these are chosen by recognising a shape, and a
/// shape is recognised faster in a block than down a column of rows.
///
/// Each choice is drawn by the same [ServiceTile] the list uses, so what the
/// user picks here is exactly what appears on the row -- brand colour and all.
/// A gallery that redrew the marks in one flat ink would be lying about the
/// two that are only told apart by colour.
class IconGallery extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onPick;

  const IconGallery({super.key, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SubdockSpacing.screenH,
          0,
          SubdockSpacing.screenH,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Group(
              label: 'Categories',
              keys: SubdockMarks.pickableGlyphs,
              selected: selected,
              onPick: onPick,
            ),
            const SizedBox(height: 20),
            _Group(
              label: 'Services',
              keys: SubdockMarks.pickableBrands,
              selected: selected,
              onPick: onPick,
            ),
          ],
        ),
      ),
    );
  }
}

/// One labelled block of the sheet.
///
/// Two blocks rather than one long grid: with fifty shapes in a single wrap,
/// "where do the logos start" becomes a question the user has to answer by
/// scrolling, and the answer is the only thing separating the two halves.
class _Group extends StatelessWidget {
  final String label;
  final List<String> keys;
  final String? selected;
  final ValueChanged<String> onPick;

  const _Group({
    required this.label,
    required this.keys,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionLabel(label, tight: true),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final key in keys)
              _IconChoice(
                markKey: key,
                selected: key == selected,
                onTap: () => onPick(key),
              ),
          ],
        ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String markKey;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.markKey,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selection is a ring, not a fill. The mark inside now carries the brand's
    // own colour, and flooding the chip with the accent would either hide that
    // or fight it -- and the two marks that differ only by colour would stop
    // being tellable apart at the moment of choosing between them.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.control),
        boxShadow: selected ? const [] : SubdockShadow.soft,
      ),
      // Foreground, not background: the Material fills the whole chip, so a
      // ring painted behind it is a ring nobody sees.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SubdockRadius.control),
          border: selected
              ? Border.all(color: SubdockColors.accent, width: 2)
              : null,
        ),
        child: Material(
          color: SubdockColors.card,
          borderRadius: BorderRadius.circular(SubdockRadius.control),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SubdockRadius.control),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                // The name is empty because the key decides the mark outright;
                // there is nothing here for the detector to read.
                child: ServiceTile('', iconName: markKey, size: 34),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
