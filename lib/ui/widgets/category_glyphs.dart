import 'package:flutter/material.dart';

/// The marks for everything that has no logo.
///
/// Two thirds of the catalog is Vietnamese household admin — electricity, a
/// passport, a motorbike inspection — and none of it has a brand. The rest is
/// local brands that ship no vector mark anywhere: Viettel, VieON, iTel. Both
/// end up here, and the difference between them is colour, not shape: a
/// household glyph is drawn in muted ink, a local brand's glyph in that
/// brand's own colour, so `SIM Viettel` still reads as Viettel red.
///
/// Drawn in the same vocabulary as [TabMark]: a 20-unit grid, 1.6px strokes,
/// rounded caps and joins. That is the point of drawing them rather than
/// importing a category icon set — a second stroke weight or a second corner
/// radius in the same column is visible immediately, even to someone who
/// could not say what changed.
enum CategoryGlyph {
  /// Streaming that is not one of the global brands: FPT Play, VieON, Galaxy
  /// Play, Disney+.
  streaming,

  /// Music services without a mark: NhacCuaTui, Zing MP3.
  music,

  /// A prepaid mobile line, and the data package on it.
  sim,

  /// Home broadband.
  router,

  /// Cable television.
  television,

  /// Electricity.
  power,

  /// Water.
  water,

  /// Piped or bottled gas.
  gas,

  /// Building service charges: the management fee, the rubbish collection.
  building,

  /// An AI service with no mark of its own.
  ai,

  /// A dating app.
  dating,

  /// Courses and language apps.
  education,

  /// Books and audiobooks.
  book,

  /// Budgeting and market-data apps: the money you watch, not the money you owe.
  wallet,

  /// Training, sleep and meditation apps.
  fitness,

  /// Food delivery memberships.
  food,

  /// A games subscription without a mark.
  gaming,

  /// Newspapers and magazines.
  news,

  /// A suite of tools rather than one tool.
  apps,

  /// Cloud storage.
  storage,

  /// Travel: lounges, transit passes, roaming data.
  travel,

  /// Antivirus, VPN, password managers.
  shield,

  /// Anything about a vehicle: parking, inspection, motor insurance.
  vehicle,

  /// A loan or an instalment plan — money owed on a schedule.
  loan,

  /// A card: the statement, the annual fee.
  card,

  /// Any insurance policy.
  insurance,

  /// A passport or a visa.
  passport,

  /// A card-shaped identity document: the ID card, the driving licence, the
  /// residence card.
  identityCard,

  /// A licence or a certificate — a sheet of paper with a seal on it.
  certificate,

  /// A domain name.
  domain,

  /// A VPS or hosting plan.
  server,

  /// Nothing known yet. Drawn beside an empty name field, where a blank square
  /// would read as an image that failed to load, and offered in the gallery as
  /// the "just something neutral" choice.
  calendar,
}

/// One category glyph, stroked in [colour].
class CategoryMark extends StatelessWidget {
  final CategoryGlyph glyph;
  final Color colour;
  final double size;

  const CategoryMark({
    super.key,
    required this.glyph,
    required this.colour,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: CategoryGlyphPainter(glyph, colour)),
    );
  }
}

class CategoryGlyphPainter extends CustomPainter {
  final CategoryGlyph glyph;
  final Color colour;

  const CategoryGlyphPainter(this.glyph, this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20, size.height / 20);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colour;
    final fill = Paint()..color = colour;

    switch (glyph) {
      case CategoryGlyph.ai:
        // A four-point sparkle. The concave arms are what stop it reading as a
        // star rating, which is the other thing a small filled star means.
        canvas.drawPath(
          Path()
            ..moveTo(10, 2.4)
            ..cubicTo(10.7, 7.0, 13.0, 9.3, 17.6, 10)
            ..cubicTo(13.0, 10.7, 10.7, 13.0, 10, 17.6)
            ..cubicTo(9.3, 13.0, 7.0, 10.7, 2.4, 10)
            ..cubicTo(7.0, 9.3, 9.3, 7.0, 10, 2.4)
            ..close(),
          fill,
        );

      case CategoryGlyph.dating:
        canvas.drawPath(
          Path()
            ..moveTo(10, 16.8)
            ..cubicTo(10, 16.8, 3.0, 12.4, 3.0, 7.8)
            ..cubicTo(3.0, 5.4, 4.9, 3.8, 7.0, 3.8)
            ..cubicTo(8.5, 3.8, 9.6, 4.7, 10, 5.6)
            ..cubicTo(10.4, 4.7, 11.5, 3.8, 13.0, 3.8)
            ..cubicTo(15.1, 3.8, 17.0, 5.4, 17.0, 7.8)
            ..cubicTo(17.0, 12.4, 10, 16.8, 10, 16.8)
            ..close(),
          stroke,
        );

      case CategoryGlyph.education:
        // A mortarboard: the board alone is a diamond, so the head below it is
        // what makes the shape a cap rather than a rotated square.
        canvas.drawPath(
          Path()
            ..moveTo(10, 3.4)
            ..lineTo(18.2, 7.4)
            ..lineTo(10, 11.4)
            ..lineTo(1.8, 7.4)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5.4, 9.0)
            ..lineTo(5.4, 13.2)
            ..cubicTo(5.4, 13.2, 7.2, 15.4, 10, 15.4)
            ..cubicTo(12.8, 15.4, 14.6, 13.2, 14.6, 13.2)
            ..lineTo(14.6, 9.0),
          stroke,
        );

      case CategoryGlyph.book:
        canvas.drawRRect(
          RRect.fromLTRBR(4.0, 3.0, 16.4, 17.0, const Radius.circular(1.8)),
          stroke,
        );
        canvas.drawLine(
          const Offset(7.2, 3.0),
          const Offset(7.2, 17.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(10.0, 7.2),
          const Offset(13.6, 7.2),
          stroke,
        );

      case CategoryGlyph.wallet:
        canvas.drawRRect(
          RRect.fromLTRBR(2.6, 5.4, 17.4, 16.2, const Radius.circular(2.4)),
          stroke,
        );
        // The card poking out of the top is what separates a wallet from the
        // plain rounded box that four other glyphs already are.
        canvas.drawPath(
          Path()
            ..moveTo(5.0, 5.4)
            ..lineTo(5.0, 3.4)
            ..lineTo(13.4, 3.4)
            ..lineTo(13.4, 5.4),
          stroke,
        );
        canvas.drawCircle(const Offset(13.8, 10.8), 1.3, fill);

      case CategoryGlyph.fitness:
        canvas.drawLine(
          const Offset(6.6, 10.0),
          const Offset(13.4, 10.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.0, 6.6),
          const Offset(6.0, 13.4),
          stroke,
        );
        canvas.drawLine(
          const Offset(14.0, 6.6),
          const Offset(14.0, 13.4),
          stroke,
        );
        canvas.drawLine(
          const Offset(3.2, 8.2),
          const Offset(3.2, 11.8),
          stroke,
        );
        canvas.drawLine(
          const Offset(16.8, 8.2),
          const Offset(16.8, 11.8),
          stroke,
        );

      case CategoryGlyph.food:
        // A bowl and chopsticks rather than a knife and fork: the list this
        // sits in is mostly Vietnamese delivery memberships.
        canvas.drawPath(
          Path()
            ..moveTo(2.8, 9.6)
            ..lineTo(17.2, 9.6)
            ..cubicTo(17.2, 14.0, 14.0, 17.0, 10, 17.0)
            ..cubicTo(6.0, 17.0, 2.8, 14.0, 2.8, 9.6)
            ..close(),
          stroke,
        );
        canvas.drawLine(
          const Offset(8.6, 2.8),
          const Offset(11.4, 7.6),
          stroke,
        );
        canvas.drawLine(
          const Offset(12.4, 2.8),
          const Offset(13.4, 7.6),
          stroke,
        );

      case CategoryGlyph.gaming:
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 6.6, 17.8, 15.4, const Radius.circular(3.4)),
          stroke,
        );
        canvas.drawLine(
          const Offset(5.2, 11.0),
          const Offset(8.4, 11.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.8, 9.4),
          const Offset(6.8, 12.6),
          stroke,
        );
        canvas.drawCircle(const Offset(13.2, 9.9), 1.05, fill);
        canvas.drawCircle(const Offset(15.0, 12.1), 1.05, fill);

      case CategoryGlyph.news:
        canvas.drawRRect(
          RRect.fromLTRBR(2.8, 4.2, 17.2, 15.8, const Radius.circular(1.6)),
          stroke,
        );
        canvas.drawLine(
          const Offset(5.2, 7.2),
          const Offset(14.8, 7.2),
          stroke,
        );
        canvas.drawLine(
          const Offset(5.2, 10.2),
          const Offset(9.4, 10.2),
          stroke,
        );
        canvas.drawLine(
          const Offset(5.2, 12.6),
          const Offset(9.4, 12.6),
          stroke,
        );
        canvas.drawRect(const Rect.fromLTRB(11.4, 9.6, 14.8, 13.0), stroke);

      case CategoryGlyph.apps:
        const r = Radius.circular(1.4);
        canvas.drawRRect(RRect.fromLTRBR(3.0, 3.0, 9.0, 9.0, r), stroke);
        canvas.drawRRect(RRect.fromLTRBR(11.0, 3.0, 17.0, 9.0, r), stroke);
        canvas.drawRRect(RRect.fromLTRBR(3.0, 11.0, 9.0, 17.0, r), stroke);
        canvas.drawRRect(RRect.fromLTRBR(11.0, 11.0, 17.0, 17.0, r), stroke);

      case CategoryGlyph.storage:
        canvas.drawPath(
          Path()
            ..moveTo(6.6, 15.4)
            ..cubicTo(4.2, 15.4, 2.4, 13.7, 2.4, 11.5)
            ..cubicTo(2.4, 9.6, 3.8, 8.0, 5.7, 7.7)
            ..cubicTo(6.2, 5.5, 8.1, 3.8, 10.5, 3.8)
            ..cubicTo(13.1, 3.8, 15.2, 5.8, 15.5, 8.3)
            ..cubicTo(17.0, 8.8, 18.0, 10.2, 18.0, 11.8)
            ..cubicTo(18.0, 13.8, 16.5, 15.4, 14.4, 15.4)
            ..close(),
          stroke,
        );

      case CategoryGlyph.travel:
        canvas.drawPath(
          Path()
            ..moveTo(10, 2.4)
            ..cubicTo(10.9, 2.4, 11.5, 3.5, 11.5, 5.0)
            ..lineTo(11.5, 8.2)
            ..lineTo(17.6, 11.8)
            ..lineTo(17.6, 13.4)
            ..lineTo(11.5, 11.6)
            ..lineTo(11.5, 15.0)
            ..lineTo(13.6, 16.6)
            ..lineTo(13.6, 17.6)
            ..lineTo(10, 16.8)
            ..lineTo(6.4, 17.6)
            ..lineTo(6.4, 16.6)
            ..lineTo(8.5, 15.0)
            ..lineTo(8.5, 11.6)
            ..lineTo(2.4, 13.4)
            ..lineTo(2.4, 11.8)
            ..lineTo(8.5, 8.2)
            ..lineTo(8.5, 5.0)
            ..cubicTo(8.5, 3.5, 9.1, 2.4, 10, 2.4)
            ..close(),
          fill,
        );

      case CategoryGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(10, 2.8)
            ..lineTo(16.8, 5.4)
            ..lineTo(16.8, 10.2)
            ..cubicTo(16.8, 14.0, 13.8, 16.4, 10, 17.4)
            ..cubicTo(6.2, 16.4, 3.2, 14.0, 3.2, 10.2)
            ..lineTo(3.2, 5.4)
            ..close(),
          stroke,
        );

      case CategoryGlyph.streaming:
        // A screen with a play triangle: the triangle alone reads as a button,
        // and half the app's rows are things you press a button in.
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 4.0, 17.8, 15.2, const Radius.circular(2.6)),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8.4, 7.2)
            ..lineTo(13.0, 9.6)
            ..lineTo(8.4, 12.0)
            ..close(),
          fill,
        );
        canvas.drawLine(
          const Offset(7.0, 17.6),
          const Offset(13.0, 17.6),
          stroke,
        );

      case CategoryGlyph.music:
        // A quaver. Two note heads, because one reads as a stray dot at 20px.
        canvas.drawLine(
          const Offset(7.4, 14.2),
          const Offset(7.4, 4.4),
          stroke,
        );
        canvas.drawLine(
          const Offset(15.0, 12.4),
          const Offset(15.0, 2.6),
          stroke,
        );
        canvas.drawLine(
          const Offset(7.4, 4.4),
          const Offset(15.0, 2.6),
          stroke,
        );
        canvas.drawCircle(const Offset(5.4, 14.6), 2.1, fill);
        canvas.drawCircle(const Offset(13.0, 12.8), 2.1, fill);

      case CategoryGlyph.sim:
        // The chamfer is the whole identity of a SIM, and at 25px a subtle one
        // does not survive: cut a third of the width off the corner, and draw
        // the contact pad as a grid rather than an empty box, or the shape
        // reads as a document beside the ID card two rows down.
        canvas.drawPath(
          Path()
            ..moveTo(4.4, 2.6)
            ..lineTo(11.2, 2.6)
            ..lineTo(15.6, 7.0)
            ..lineTo(15.6, 17.4)
            ..lineTo(4.4, 17.4)
            ..close(),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromLTRBR(7.0, 8.8, 13.0, 14.6, const Radius.circular(1.0)),
          stroke,
        );
        canvas.drawLine(
          const Offset(10.0, 8.8),
          const Offset(10.0, 14.6),
          stroke,
        );
        canvas.drawLine(
          const Offset(7.0, 11.7),
          const Offset(13.0, 11.7),
          stroke,
        );

      case CategoryGlyph.router:
        // A box with an aerial and two link lights.
        canvas.drawRRect(
          RRect.fromLTRBR(2.4, 10.4, 17.6, 16.6, const Radius.circular(2.0)),
          stroke,
        );
        canvas.drawCircle(const Offset(6.0, 13.5), 1.1, fill);
        canvas.drawCircle(const Offset(9.6, 13.5), 1.1, fill);
        canvas.drawLine(
          const Offset(14.2, 10.4),
          const Offset(14.2, 6.0),
          stroke,
        );
        // Two arcs of signal, opening away from the aerial.
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(14.2, 6.0), radius: 3.0),
          3.67,
          1.8,
          false,
          stroke,
        );

      case CategoryGlyph.television:
        // Distinguished from [streaming] by the aerial rather than by the
        // screen, so the two never depend on the viewer noticing a triangle.
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 7.0, 17.8, 17.4, const Radius.circular(2.6)),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.6, 2.8),
          const Offset(10.0, 7.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(13.4, 2.8),
          const Offset(10.0, 7.0),
          stroke,
        );

      case CategoryGlyph.power:
        // The lightning bolt, drawn filled: at this size a stroked bolt is
        // mostly the gap down its middle.
        canvas.drawPath(
          Path()
            ..moveTo(11.6, 2.2)
            ..lineTo(4.6, 11.4)
            ..lineTo(9.2, 11.4)
            ..lineTo(8.4, 17.8)
            ..lineTo(15.4, 8.6)
            ..lineTo(10.8, 8.6)
            ..close(),
          fill,
        );

      case CategoryGlyph.water:
        // A droplet: a point at the top, a circle at the bottom, joined by two
        // curves that leave the tip sharp.
        canvas.drawPath(
          Path()
            ..moveTo(10.0, 2.4)
            ..cubicTo(10.0, 2.4, 15.6, 8.6, 15.6, 12.2)
            ..cubicTo(15.6, 15.3, 13.1, 17.8, 10.0, 17.8)
            ..cubicTo(6.9, 17.8, 4.4, 15.3, 4.4, 12.2)
            ..cubicTo(4.4, 8.6, 10.0, 2.4, 10.0, 2.4)
            ..close(),
          stroke,
        );

      case CategoryGlyph.gas:
        // A flame. Same silhouette family as the droplet but inverted and
        // notched, which is what keeps the two apart in a list.
        canvas.drawPath(
          Path()
            ..moveTo(10.0, 2.2)
            ..cubicTo(10.0, 2.2, 5.0, 6.6, 5.0, 11.6)
            ..cubicTo(5.0, 15.0, 7.2, 17.8, 10.0, 17.8)
            ..cubicTo(12.8, 17.8, 15.0, 15.0, 15.0, 11.6)
            ..cubicTo(15.0, 9.4, 13.6, 7.6, 13.6, 7.6)
            ..cubicTo(13.6, 10.4, 12.2, 11.4, 11.4, 11.4)
            ..cubicTo(10.6, 11.4, 11.8, 7.0, 10.0, 2.2)
            ..close(),
          stroke,
        );

      case CategoryGlyph.building:
        // An apartment block. Square windows rather than round ones, because
        // four dots in a rounded box is a domino; and a roof line across the
        // top, which is what makes it a building rather than a form.
        canvas.drawPath(
          Path()
            ..moveTo(3.4, 17.4)
            ..lineTo(3.4, 6.0)
            ..lineTo(10.0, 2.6)
            ..lineTo(16.6, 6.0)
            ..lineTo(16.6, 17.4)
            ..close(),
          stroke,
        );
        for (final y in const [7.8, 11.4]) {
          for (final x in const [6.2, 11.4]) {
            canvas.drawRect(Rect.fromLTWH(x, y, 2.4, 2.2), stroke);
          }
        }
        canvas.drawLine(
          const Offset(3.4, 17.4),
          const Offset(16.6, 17.4),
          stroke,
        );

      case CategoryGlyph.vehicle:
        // A car from the side: cabin, body, two wheels.
        canvas.drawPath(
          Path()
            ..moveTo(3.0, 12.6)
            ..lineTo(3.0, 10.4)
            ..lineTo(5.4, 10.4)
            ..lineTo(7.4, 6.6)
            ..lineTo(13.2, 6.6)
            ..lineTo(15.0, 10.4)
            ..lineTo(17.0, 10.4)
            ..lineTo(17.0, 12.6)
            ..close(),
          stroke,
        );
        canvas.drawCircle(const Offset(6.6, 13.6), 1.7, stroke);
        canvas.drawCircle(const Offset(13.4, 13.6), 1.7, stroke);

      case CategoryGlyph.loan:
        // A banknote. The circle in the middle keeps it from reading as a card;
        // the card glyph is the one with a stripe across the top.
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 5.2, 17.8, 14.8, const Radius.circular(2.0)),
          stroke,
        );
        canvas.drawCircle(const Offset(10.0, 10.0), 2.4, stroke);
        canvas.drawLine(
          const Offset(5.0, 10.0),
          const Offset(5.6, 10.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(14.4, 10.0),
          const Offset(15.0, 10.0),
          stroke,
        );

      case CategoryGlyph.card:
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 4.8, 17.8, 15.2, const Radius.circular(2.2)),
          stroke,
        );
        canvas.drawLine(
          const Offset(2.2, 8.4),
          const Offset(17.8, 8.4),
          stroke,
        );
        canvas.drawLine(
          const Offset(5.4, 12.2),
          const Offset(9.0, 12.2),
          stroke,
        );

      case CategoryGlyph.insurance:
        // A shield with a tick. The tick is what says "covered" rather than
        // "protected", which is the distinction a policy row needs.
        canvas.drawPath(
          Path()
            ..moveTo(10.0, 2.4)
            ..lineTo(16.4, 5.0)
            ..lineTo(16.4, 10.2)
            ..cubicTo(16.4, 14.0, 13.6, 16.6, 10.0, 17.8)
            ..cubicTo(6.4, 16.6, 3.6, 14.0, 3.6, 10.2)
            ..lineTo(3.6, 5.0)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7.4, 10.2)
            ..lineTo(9.3, 12.1)
            ..lineTo(12.8, 8.2),
          stroke,
        );

      case CategoryGlyph.passport:
        // A booklet, not a sheet: the spine on the left and the crest in the
        // middle are what separate it from [certificate].
        canvas.drawRRect(
          RRect.fromLTRBR(4.0, 2.4, 16.0, 17.6, const Radius.circular(2.0)),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.6, 2.4),
          const Offset(6.6, 17.6),
          stroke,
        );
        canvas.drawCircle(const Offset(11.6, 8.6), 2.4, stroke);
        canvas.drawLine(
          const Offset(9.4, 13.4),
          const Offset(13.8, 13.4),
          stroke,
        );

      case CategoryGlyph.identityCard:
        // Landscape, portrait photo on the left, two lines of detail beside it.
        canvas.drawRRect(
          RRect.fromLTRBR(2.2, 4.4, 17.8, 15.6, const Radius.circular(2.2)),
          stroke,
        );
        canvas.drawCircle(const Offset(7.2, 9.0), 1.7, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4.6, 13.0)
            ..cubicTo(5.2, 11.3, 9.2, 11.3, 9.8, 13.0),
          stroke,
        );
        canvas.drawLine(
          const Offset(12.0, 8.4),
          const Offset(15.4, 8.4),
          stroke,
        );
        canvas.drawLine(
          const Offset(12.0, 11.6),
          const Offset(15.4, 11.6),
          stroke,
        );

      case CategoryGlyph.certificate:
        // A sheet with a seal. The seal is filled so it survives at 20px,
        // where a stroked ring of that diameter closes up.
        canvas.drawPath(
          Path()
            ..moveTo(4.0, 2.6)
            ..lineTo(14.2, 2.6)
            ..lineTo(16.0, 4.4)
            ..lineTo(16.0, 17.4)
            ..lineTo(4.0, 17.4)
            ..close(),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.6, 6.8),
          const Offset(13.4, 6.8),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.6, 9.6),
          const Offset(11.0, 9.6),
          stroke,
        );
        canvas.drawCircle(const Offset(13.0, 13.4), 2.0, fill);

      case CategoryGlyph.domain:
        // A globe: the outline, the equator, and one meridian drawn as an
        // ellipse, which is the cheapest way to say "sphere" in three strokes.
        canvas.drawCircle(const Offset(10.0, 10.0), 7.4, stroke);
        canvas.drawLine(
          const Offset(2.6, 10.0),
          const Offset(17.4, 10.0),
          stroke,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(10.0, 10.0),
            width: 7.6,
            height: 14.8,
          ),
          stroke,
        );

      case CategoryGlyph.server:
        // Two stacked units with a status light each.
        for (final top in const [3.4, 11.0]) {
          canvas.drawRRect(
            RRect.fromLTRBR(
              2.6,
              top,
              17.4,
              top + 5.6,
              const Radius.circular(1.8),
            ),
            stroke,
          );
          canvas.drawCircle(Offset(5.8, top + 2.8), 1.1, fill);
          canvas.drawLine(
            Offset(9.0, top + 2.8),
            Offset(14.6, top + 2.8),
            stroke,
          );
        }

      case CategoryGlyph.calendar:
        // The same drawing as the Upcoming tab's mark. Deliberately: the tile
        // is saying "a thing with a date", which is what that tab is called.
        canvas.drawRRect(
          RRect.fromLTRBR(2.6, 4.4, 17.4, 17.4, const Radius.circular(3.4)),
          stroke,
        );
        canvas.drawLine(
          const Offset(2.6, 8.6),
          const Offset(17.4, 8.6),
          stroke,
        );
        canvas.drawLine(const Offset(6.8, 2.6), const Offset(6.8, 5.6), stroke);
        canvas.drawLine(
          const Offset(13.2, 2.6),
          const Offset(13.2, 5.6),
          stroke,
        );
        canvas.drawCircle(const Offset(10, 13.2), 1.5, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CategoryGlyphPainter old) =>
      old.colour != colour || old.glyph != glyph;
}
