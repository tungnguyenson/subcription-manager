import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';

/// A tab's mark, in the two states the hand-off names: filled when the tab is
/// the one you are on, outlined when it is not.
///
/// Filled versus outlined is the part that survives being read badly. Colour
/// alone fails for the eight percent of men with a red-green deficiency and for
/// anyone glancing at the bar in sunlight; a solid shape against a hollow one
/// does not. It matters more in the Glass theme than it did in Layered, because
/// the selected tab there had a tinted slab behind it and here it has nothing
/// but the hue.
///
/// The hand-off names `event_upcoming` and `bar_chart`; Flutter's bundled
/// Material set does not carry the first, and `event` is the same drawing
/// without the arrow. Shipping a second icon font for one glyph is not worth
/// the download.
enum TabGlyph {
  upcoming(Icons.event_rounded, Icons.event_outlined),
  money(Icons.bar_chart_rounded, Icons.bar_chart_outlined),

  savings(Icons.savings_rounded, Icons.savings_outlined),

  settings(Icons.tune_rounded, Icons.tune_outlined);

  final IconData filled;
  final IconData outlined;

  const TabGlyph(this.filled, this.outlined);
}

class TabMark extends StatelessWidget {
  final TabGlyph glyph;
  final bool active;
  final double size;

  const TabMark({
    super.key,
    required this.glyph,
    required this.active,
    this.size = 23,
  });

  /// The colour a tab takes when it is the selected one.
  ///
  /// The accent, for all four. The savings *screen* is green -- it is the only
  /// place in the app where a figure is money the user keeps, and the accent
  /// already means "you can act here" -- but the bar is not part of any one
  /// screen. It is the one control on display at all times, and a row of four
  /// where one is a different hue reads as that tab being in a different
  /// state, not as a preview of the colour behind it. The hand-off draws this
  /// tab green; the consistency of the bar wins.
  static Color tint(TabGlyph glyph) => SubdockColors.accent;

  @override
  Widget build(BuildContext context) {
    return Icon(
      active ? glyph.filled : glyph.outlined,
      size: size,
      color: active ? tint(glyph) : SubdockColors.inkMuted,
    );
  }
}
