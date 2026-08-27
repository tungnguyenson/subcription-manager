import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/search_field.dart';
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
///
/// The tile *is* the cell. An earlier version sat each tile inside a second
/// white card, which drew two nested rounded squares around every mark and
/// spent the width on the outer one: the logo itself came out at 19pt on a
/// 52pt chip. The mark is the only thing here worth looking at, so it gets the
/// whole cell.
class IconGallery extends StatefulWidget {
  final String? selected;
  final ValueChanged<String> onPick;

  /// How much of the screen the sheet may take. Nearly all of it: there are
  /// over a hundred and fifty marks, and a half-height sheet turns choosing
  /// one into scrolling past four rows at a time.
  static const double maxHeightFraction = 0.9;

  const IconGallery({super.key, required this.selected, required this.onPick});

  @override
  State<IconGallery> createState() => _IconGalleryState();
}

class _IconGalleryState extends State<IconGallery> {
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

  List<String> _hits(List<String> keys) =>
      keys.where((key) => SubdockMarks.matches(key, _query.text)).toList();

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    final glyphs = _hits(SubdockMarks.pickableGlyphs);
    final brands = _hits(SubdockMarks.pickableBrands);
    final typed = _query.text.trim();

    // The sheet keeps its height when the keyboard comes up and the grid gives
    // the room back instead. Growing the sheet by the keyboard's height would
    // push its top edge off the screen; shrinking the whole sheet would make
    // the search box jump as the first character is typed.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SubdockSpacing.screenH,
              0,
              SubdockSpacing.screenH,
              14,
            ),
            // Not autofocused. The gallery is opened to browse at least as
            // often as to look something up, and a keyboard that arrives
            // uninvited eats the half of the grid the sheet was made taller
            // for.
            child: SearchField(controller: _query, hint: 'Search icons'),
          ),
          Expanded(
            child: glyphs.isEmpty && brands.isEmpty
                ? _NoHits(query: typed)
                : SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        SubdockSpacing.screenH,
                        0,
                        SubdockSpacing.screenH,
                        20 + keyboard,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (glyphs.isNotEmpty)
                            _Group(
                              label: 'Categories',
                              keys: glyphs,
                              selected: widget.selected,
                              onPick: widget.onPick,
                            ),
                          if (glyphs.isNotEmpty && brands.isNotEmpty)
                            const SizedBox(height: 20),
                          if (brands.isNotEmpty)
                            _Group(
                              label: 'Services',
                              keys: brands,
                              selected: widget.selected,
                              onPick: widget.onPick,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One labelled block of the sheet.
///
/// Two blocks rather than one long grid: with fifty shapes in a single wrap,
/// "where do the logos start" becomes a question the user has to answer by
/// scrolling, and the answer is the only thing separating the two halves.
///
/// A block with nothing in it is left out by the caller rather than drawn
/// empty, because a heading over a blank strip reads as a grid that failed to
/// load rather than as a search that matched only brands.
class _Group extends StatelessWidget {
  final String label;
  final List<String> keys;
  final String? selected;
  final ValueChanged<String> onPick;

  /// Marks per row. Five is what fits a phone at a size where a logo is still
  /// a logo; the cell is measured from the width rather than fixed, so the
  /// grid reaches both edges instead of trailing off into a ragged gap.
  static const int columns = 5;

  static const double gap = 10;

  const _Group({
    required this.label,
    required this.keys,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionLabel(label, tight: true),
            ),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final key in keys)
                  _IconChoice(
                    markKey: key,
                    size: cell,
                    selected: key == selected,
                    onTap: () => onPick(key),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String markKey;

  /// The whole cell, ring included.
  final double size;

  final bool selected;
  final VoidCallback onTap;

  /// The accent ring, and the gap between it and the tile. Reserved on every
  /// cell whether it is selected or not, so picking a different mark does not
  /// shuffle the grid under the finger that picked it.
  static const double ring = 2;
  static const double inset = 3;

  const _IconChoice({
    required this.markKey,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selection is a ring, not a fill. The mark inside carries the brand's own
    // colour, and flooding the cell with the accent would either hide that or
    // fight it -- and the two marks that differ only by colour would stop
    // being tellable apart at the moment of choosing between them.
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SubdockRadius.control + inset),
          border: Border.all(
            color: selected ? SubdockColors.accent : const Color(0x00000000),
            width: ring,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: ServiceTile(
            // The name is empty because the key decides the mark outright;
            // there is nothing here for the detector to read.
            '',
            iconName: markKey,
            size: size - (ring + inset) * 2,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

/// What a search that matched nothing says.
///
/// It names what was typed rather than saying "no results", because the answer
/// the user needs is usually that they searched for the service and the app
/// only has a shape for it -- and a shape is still pickable from the block
/// above once the query is cleared.
class _NoHits extends StatelessWidget {
  final String query;

  const _NoHits({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.screenH,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No icon called "$query"',
            textAlign: TextAlign.center,
            style: SubdockText.summary,
          ),
          const SizedBox(height: 6),
          Text(
            'Clear the search to pick a shape instead.',
            textAlign: TextAlign.center,
            style: SubdockText.caption,
          ),
        ],
      ),
    );
  }
}
