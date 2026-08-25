import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';

/// The one drawing in the app: a miniature of a tracked item that has not been
/// filled in, with the add button parked on its corner.
///
/// It is built from the same parts as a real row — a card at the card
/// elevation, placeholder lines punched through to the page ground, and the
/// accent circle exactly as the tab bar draws it — so it reads as *this app
/// with nothing in it* rather than as stock art. Nothing here is tappable and
/// nothing here is announced; the button underneath is the affordance.
class EmptyPlacard extends StatelessWidget {
  /// The card's side. Everything else is derived from it, so the placard can
  /// be sized in one number.
  final double size;

  const EmptyPlacard({super.key, this.size = 92});

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.36;
    final inset = size * 0.16;

    return ExcludeSemantics(
      child: SizedBox(
        // The badge sits half on the corner and half off it, the way the real
        // add button sits half over the tab bar.
        width: size + badge * 0.55,
        height: size + badge * 0.5,
        child: Stack(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: SubdockColors.card,
                borderRadius: BorderRadius.circular(SubdockRadius.placard),
                boxShadow: SubdockShadow.card,
              ),
              padding: EdgeInsets.fromLTRB(inset, inset * 1.3, inset, inset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Line(widthFactor: 0.6),
                  SizedBox(height: size * 0.09),
                  const _Line(widthFactor: 0.82),
                  const Spacer(),
                  // The one thing the placard asks for: a date, still blank.
                  SizedBox(height: size * 0.2, child: const _EmptySlot()),
                ],
              ),
            ),
            Positioned(right: 0, bottom: 0, child: _AddMark(diameter: badge)),
          ],
        ),
      ),
    );
  }
}

/// A placeholder line, drawn as the page ground showing through the card so it
/// reads as an absence rather than as content the user cannot make out.
class _Line extends StatelessWidget {
  final double widthFactor;

  const _Line({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: SubdockColors.canvas,
          borderRadius: BorderRadius.circular(3.5),
        ),
      ),
    );
  }
}

/// The slot a date would go in, dashed because it is waiting for one.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(painter: _DashedBorderPainter()),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  static const double _dash = 3.2;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = SubdockColors.accentHalf;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(SubdockRadius.tile),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

/// The add button as the tab bar draws it, at illustration scale. Same fill,
/// same shadow, same glyph — so the eye that follows it down to the real one
/// is following the same object.
class _AddMark extends StatelessWidget {
  final double diameter;

  const _AddMark({required this.diameter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        color: SubdockColors.accent,
        shape: BoxShape.circle,
        boxShadow: SubdockShadow.card,
      ),
      alignment: Alignment.center,
      child: Text(
        '+',
        style: TextStyle(
          fontFamily: SubdockText.family,
          fontSize: diameter * 0.52,
          height: 1,
          fontWeight: SubdockWeight.regular,
          color: SubdockColors.card,
        ),
      ),
    );
  }
}
