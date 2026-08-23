import 'package:flutter/material.dart';
import 'package:subdock/ui/icons.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The icon gallery, shown in a sheet from the tile beside the name field.
///
/// A grid rather than a list: these are chosen by recognising a shape, and a
/// shape is recognised faster in a block than down a column of rows.
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
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SectionLabel('Icon', tight: true),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in SubdockIcons.all.entries)
                  _IconChoice(
                    icon: entry.value,
                    selected: entry.key == selected,
                    onTap: () => onPick(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        boxShadow: selected ? const [] : SubdockShadow.soft,
      ),
      child: Material(
        color: selected ? SubdockColors.accent : SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SubdockRadius.chip),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 22,
              color: selected ? SubdockColors.card : SubdockColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
