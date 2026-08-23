import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';

/// A tab's mark, in the two states the hand-off names: filled when the tab is
/// the one you are on, outlined when it is not.
///
/// Filled versus outlined is the part that survives being read badly. Colour
/// alone fails for the eight percent of men with a red-green deficiency and for
/// anyone glancing at the bar in sunlight; a solid shape against a hollow one
/// does not.
///
/// The hand-off names `event_upcoming`; Flutter's bundled Material set does not
/// carry it, and `event` is the same drawing without the arrow. Shipping a
/// second icon font for one glyph is not worth the download.
enum TabGlyph {
  upcoming(Icons.event_rounded, Icons.event_outlined),
  money(Icons.payments_rounded, Icons.payments_outlined),
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
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      active ? glyph.filled : glyph.outlined,
      size: size,
      color: active ? SubdockColors.accent : SubdockColors.inkMuted,
    );
  }
}
