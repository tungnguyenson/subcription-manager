import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/category_glyphs.dart';
import 'package:subdock/ui/widgets/service_mark.dart';
import 'package:subdock/ui/widgets/service_marks.data.dart';

/// The uppercase heading that sits above a card, outside it.
class SectionLabel extends StatelessWidget {
  final String text;

  /// The first label on a screen sits closer to the title than a label that is
  /// separating two cards.
  final bool tight;

  const SectionLabel(this.text, {super.key, this.tight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: tight ? 16 : SubdockSpacing.sectionTop,
        bottom: SubdockSpacing.sectionBottom,
      ),
      child: Text(text.toUpperCase(), style: SubdockText.sectionLabel),
    );
  }
}

/// The translucent container everything sits in.
///
/// There is no drop shadow. A card is told apart from the gradient behind it
/// by the bright hairline in [SubdockSurface.card] — which is why this is a
/// single widget rather than a decoration each screen repeats. One card drawn
/// with a shadow instead disappears; one drawn opaque stops belonging to the
/// theme.
class GroupedCard extends StatelessWidget {
  final List<Widget> children;

  /// Set to make the card one block instead of a stack of ruled rows. A block
  /// card gets no hairlines: its children are lines of a single thought, and
  /// ruling between them would slice one paragraph into three rows.
  final EdgeInsetsGeometry? padding;

  final double radius;

  /// Overrides the fill. Used for the two rows that carry a hue of their own:
  /// overdue, and a free trial.
  final BoxDecoration? decoration;

  const GroupedCard({
    super.key,
    required this.children,
    this.padding,
    this.radius = SubdockRadius.card,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final ruled = padding == null;

    final interleaved = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (ruled && i > 0) {
        interleaved.add(
          Divider(height: 1, thickness: 1, color: SubdockColors.hairline),
        );
      }
      interleaved.add(children[i]);
    }

    return Container(
      decoration: decoration ?? SubdockSurface.card(radius: radius),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: interleaved,
      ),
    );
  }
}

/// The tick that says which of a list of choices is the current one.
///
/// Drawn rather than taken from Material's icon set, like every other mark in
/// this app. Two reasons here: the ring and the tick have to sit on the app's
/// own hairline weight to belong beside a `Caret`, and the MaterialIcons font
/// is not loaded under `flutter_test`, so an `Icon` would be an empty square
/// in every screenshot the repo takes of a picker.
class PickMark extends StatelessWidget {
  final bool selected;
  final double size;

  const PickMark({super.key, required this.selected, this.size = 21});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _PickMarkPainter(
        selected: selected,
        fill: SubdockColors.accent,
        tick: SubdockColors.onAccent,
        ring: SubdockColors.hairline,
      ),
    ),
  );
}

class _PickMarkPainter extends CustomPainter {
  final bool selected;
  final Color fill;
  final Color tick;
  final Color ring;

  const _PickMarkPainter({
    required this.selected,
    required this.fill,
    required this.tick,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    if (!selected) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      return;
    }

    canvas.drawCircle(centre, radius, Paint()..color = fill);

    // A tick sized off the box rather than off fixed points, so the same mark
    // reads the same at 18 and at 24.
    final unit = size.width / 21;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx - 4.4 * unit, centre.dy - 0.2 * unit)
        ..lineTo(centre.dx - 1.2 * unit, centre.dy + 3.1 * unit)
        ..lineTo(centre.dx + 4.6 * unit, centre.dy - 3.4 * unit),
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PickMarkPainter old) =>
      old.selected != selected ||
      old.fill != fill ||
      old.tick != tick ||
      old.ring != ring;
}

/// A dashed outline around something that is standing in for a thing not
/// there yet: an empty date slot, a row that opens a longer list.
///
/// Dashed rather than solid is the whole message. A solid hairline is what
/// every real surface in this app wears, so a placeholder wearing one reads as
/// a card the user can act on directly.
class DashedBox extends StatelessWidget {
  final Widget? child;
  final double radius;

  /// Null takes [SubdockColors.accentHalf].
  final Color? color;

  final EdgeInsetsGeometry padding;

  const DashedBox({
    super.key,
    this.child,
    this.radius = SubdockRadius.tile,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(
        radius: radius,
        color: color ?? SubdockColors.accentHalf,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  static const double _dash = 3.2;
  static const double _gap = 3;

  final double radius;
  final Color color;

  const DashedBorderPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
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
  bool shouldRepaint(DashedBorderPainter old) =>
      old.radius != radius || old.color != color;
}

/// The small downward triangle on a field that opens a picker.
///
/// Drawn rather than set as `▾`. Neither bundled face carries U+25BE, so the
/// character falls back to whatever the platform happens to have — a different
/// weight and a different size on every device, and nothing at all in a test.
class Caret extends StatelessWidget {
  /// Null takes [SubdockColors.inkMuted]. Nullable rather than defaulted,
  /// because a token is no longer a compile-time constant and a default has to
  /// be one.
  final Color? color;

  final double size;

  /// Points up instead of down. Used where the caret reports state rather than
  /// affordance: a section that is already open.
  final bool up;

  const Caret({super.key, this.color, this.size = 9, this.up = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.55),
      painter: _CaretPainter(color ?? SubdockColors.inkMuted, up),
    );
  }
}

class _CaretPainter extends CustomPainter {
  final Color color;
  final bool up;

  const _CaretPainter(this.color, this.up);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.color != color || old.up != up;
}

/// A label on the left, a value on the right. The workhorse of the detail,
/// settings and review screens.
class DetailRow extends StatelessWidget {
  /// The most of a row the label may take before it starts to ellipsize.
  ///
  /// Above half, because the label is normally the shorter of the two and this
  /// only ever binds on the rare long one; not the whole row, because the
  /// value must always keep somewhere to be.
  static const double _labelShare = 0.55;

  final String label;
  final String? value;

  /// True for a date, an amount, a count — anything the reader lines up
  /// against the same field on another row.
  final bool monoValue;

  /// A row that leads somewhere shows a chevron and reads in full ink; a row
  /// that states a fact does neither.
  final VoidCallback? onTap;
  final bool chevron;

  final Color? valueColor;

  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.monoValue = false,
    this.onTap,
    this.chevron = false,
    this.valueColor,
  });

  /// A settings entry: full-ink label, chevron, nothing else.
  const DetailRow.nav({
    super.key,
    required this.label,
    this.value,
    required this.onTap,
  }) : monoValue = false,
       chevron = true,
       valueColor = null;

  @override
  Widget build(BuildContext context) {
    final base = monoValue ? SubdockText.monoValue : SubdockText.rowValue;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: SubdockSpacing.rowH,
          vertical: chevron ? 15 : SubdockSpacing.rowV,
        ),
        child: Row(
          children: [
            // The label takes what it needs and the value takes the rest,
            // rather than the two splitting the row down the middle.
            //
            // Two `Flexible` children of one Row each get half the free space
            // whether or not they want it, and a loose Flexible that wants
            // less simply leaves its share empty -- it does not hand it over.
            // So a short label beside a long value produced a gap in the
            // middle of the card and an ellipsis at the end of the value:
            // `Last saved  27/08/2026 at 14...`, with the part the row exists
            // to report being the part that got cut.
            //
            // The value is the answer and the label is the question, so the
            // label is the one that yields. It is still capped, because a
            // Vietnamese label two or three words longer than its English
            // original must not be able to squeeze the value out entirely.
            Expanded(
              child: LayoutBuilder(
                builder: (context, room) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        // Only where there is a value to protect. The cap
                        // exists to stop a long label squeezing the answer
                        // out; on a row that has no answer it was cutting the
                        // label to leave room for nothing, which is how
                        // `Connect a Google account` reached the screen as
                        // `Connect a Google a...`.
                        maxWidth: value == null
                            ? room.maxWidth
                            : room.maxWidth * _labelShare,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chevron
                            ? SubdockText.rowLink
                            : SubdockText.rowLabel,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value!,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chevron
                              ? SubdockText.rowLabel.copyWith(fontSize: 12)
                              : (valueColor == null
                                    ? base
                                    : base.copyWith(color: valueColor)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: 8),
              Text(
                '›',
                style: TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 12,
                  height: 1,
                  color: SubdockColors.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded square that carries a service's mark.
///
/// Three outcomes, in falling order of how much the app actually knows:
///
/// 1. **A brand mark** — the drawn logo, on a tile tinted with that brand's
///    own colour at 10%.
/// 2. **A category glyph** — a bill, a SIM, a document. Drawn on plain glass,
///    never tinted, so a colour in this column always means "this is that
///    service" and never "this row is a bill".
/// 3. **The first letter**, on a filled accent tile with white type.
///
/// The design mock-ups show (3) for everything, because HTML cannot draw the
/// app's vector marks. Keeping (1) and (2) is deliberate: the marks are real
/// work with golden tests behind them, and a wall of identical accent squares
/// carries less information than a Netflix logo does. The letter tile is the
/// fallback the design specifies, not the default.
class ServiceTile extends StatelessWidget {
  final String name;

  /// An explicit mark key. When null the name is asked, and when the name has
  /// nothing to say its first letter is drawn.
  final String? iconName;

  final double size;
  final double radius;
  final double fontSize;

  /// Set on the add form, where the tile is the way into the icon gallery.
  final VoidCallback? onTap;

  /// The size for a two-line list row: name over subtitle.
  ///
  /// Measured, not chosen. `itemName` at 17/1.3 is 22pt, the 3pt gap, and a
  /// 14/1.4 subtitle is 20pt, so the text beside the tile stands 45pt tall. A
  /// 34pt tile against that leaves the mark floating in the middle of a taller
  /// column and reads as undersized. The tile matches the block it sits
  /// beside, with a point to spare so a subtitle a shade taller cannot
  /// overtake it. Rows carrying a single line keep the smaller default.
  static const double listSize = 46;

  /// The corner and the letter that go with [listSize].
  ///
  /// Two points softer than [SubdockRadius.chip] and five points larger than
  /// the default letter, both for the same reason: the tile grew, and a chip
  /// radius on a 46pt square reads as a rounded rectangle rather than as the
  /// squircle every other app icon beside it on the home screen is. The letter
  /// is scaled with the box so a fallback tile carries the same weight in the
  /// row as a brand mark does.
  static const double listRadius = 11;
  static const double listFontSize = 19;

  const ServiceTile(
    this.name, {
    super.key,
    this.iconName,
    this.size = 34,
    this.radius = SubdockRadius.chip,
    this.fontSize = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final chosen = iconName;
    final detected = chosen == null
        ? SubdockMarks.detect(trimmed)
        : SubdockMarks.forKey(chosen);
    // With no name yet there is no letter to draw and nothing to detect from,
    // and an empty square beside an empty field reads as an image that failed
    // to load. The neutral mark says "this is the icon, and you can tap it".
    final spec = detected ?? (trimmed.isEmpty ? _blank : null);

    final (Widget child, Color tint) = switch (spec) {
      // An explicit key that no longer names anything -- a mark retired from a
      // later build -- falls through to the letter rather than to an empty
      // square, which is the one outcome that would look like a bug.
      BrandSpec(:final key) => switch (brandMarks[key]) {
        final BrandMark mark => (
          BrandGlyph(mark: mark, size: size * 0.56),
          Color(mark.colour),
        ),
        null => (_letter(trimmed), SubdockColors.accent),
      },
      GlyphSpec(:final glyph, brandColour: final int colour) => (
        CategoryMark(glyph: glyph, colour: Color(colour), size: size * 0.62),
        Color(colour),
      ),
      GlyphSpec(:final glyph) => (
        CategoryMark(
          glyph: glyph,
          colour: SubdockColors.inkSecondary,
          size: size * 0.62,
        ),
        _plain,
      ),
      null => (_letter(trimmed), SubdockColors.accent),
    };

    // A letter tile is filled solid and a mark tile is not. The letter has to
    // carry the whole identity of the row on its own, and 16px of grey type on
    // glass does not; a mark already has a shape to be recognised by, and
    // filling its tile would fight the logo inside it.
    final solid =
        spec == null || (spec is BrandSpec && brandMarks[spec.key] == null);

    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid
            ? tint
            : (tint == _plain
                  ? SubdockColors.thumb
                  : tint.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: solid ? const Color(0x00000000) : SubdockColors.thumbEdge,
        ),
      ),
      child: child,
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: tile,
    );
  }

  static const MarkSpec _blank = GlyphSpec(CategoryGlyph.calendar);

  /// Sentinel for "no brand colour" in the switch above. Any colour would do;
  /// it is compared by identity, never painted.
  static const Color _plain = Color(0x00000001);

  Widget _letter(String trimmed) => Text(
    trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase(),
    style: SubdockText.tileLetter.copyWith(fontSize: fontSize),
  );
}

/// The filled action. There is one accent in this design, so a screen showing
/// two of these has a hierarchy problem rather than a styling one.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SubdockRadius.card),
      ),
      child: Material(
        color: enabled ? SubdockColors.accent : SubdockColors.accentSoft,
        borderRadius: BorderRadius.circular(SubdockRadius.card),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SubdockRadius.card),
          child: Container(
            // Horizontal padding matters only when the button is sized to its
            // label rather than to the screen: the empty state's one button is
            // the case, and without it the words touch the accent's edge.
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SubdockText.button.copyWith(
                color: enabled
                    ? SubdockColors.onAccent
                    : SubdockColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The second action: a white card of the same size, one elevation lower.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Reads in the accent rather than in ink. The design uses this where the
  /// card-shaped button is the *only* action on the block — "Open Netflix
  /// account", "Enter manually", "Add a service" — so it has to look like the
  /// thing to tap without becoming a second filled button on the screen.
  final bool accent;

  const SecondaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SubdockSurface.card(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SubdockText.button.copyWith(
                color: accent ? SubdockColors.accent : SubdockColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The third action: no card at all.
///
/// This is where the design puts the one thing on a screen that undoes it —
/// cancel the subscription, stop after this payment. It is reachable without
/// being a target the thumb finds by accident.
class QuietButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  const QuietButton(
    this.label, {
    super.key,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(SubdockRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: danger
              ? SubdockText.quietAction.copyWith(color: SubdockColors.danger)
              : SubdockText.quietAction,
        ),
      ),
    );
  }
}

/// A selectable pill: date shortcuts, reminder leads, history filters.
class ChoiceChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Set when the chip sits inside a [FieldBox] rather than on the page.
  ///
  /// The unselected chip is a white card lifted off a grey ground. Put that
  /// same card on the white of a field and the only thing left of it is its
  /// shadow: the currency chips read as one lit button beside a smudge, on the
  /// one control where which of the two is lit changes what the number means.
  /// On a field it inverts — the ground colour comes back as the fill.
  final bool onField;

  /// A mark drawn before the label. Only the payment-source chips use one: the
  /// list is user-written names ("VCB 4412", "Momo"), and a card glyph beside
  /// them is what says the row is about money rather than about a service.
  final Widget? icon;

  /// A tally after the label, at 60% of the label's own colour.
  ///
  /// The same shape a section heading uses for its count, and dimmed for the
  /// same reason: a two-digit number set as brightly as the word beside it
  /// outranks the word, and the word is what the chip is for.
  final int? count;

  const ChoiceChipPill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.onField = false,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? SubdockColors.accent
            : (onField ? SubdockColors.hairline : SubdockColors.card),
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        border: Border.all(
          color: selected || onField
              ? const Color(0x00000000)
              : SubdockColors.glassEdge,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              // 44px minimum on a chip the thumb has to hit. The design's own
              // padding gives 32px, which is under the platform minimum on
              // both iOS and Android; the extra goes into the touch target,
              // not the drawn box, because the row of chips has to keep the
              // proportions the mock-up gives it.
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      size: 16,
                      color: selected
                          ? SubdockColors.onAccent
                          : SubdockColors.inkSecondary,
                    ),
                    child: icon!,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Builder(
                    builder: (context) {
                      final style = selected
                          ? SubdockText.chipSelected
                          : SubdockText.chip;
                      return Text.rich(
                        TextSpan(
                          text: label,
                          children: [
                            if (count != null)
                              TextSpan(
                                text: '  $count',
                                style: style.copyWith(
                                  // Multiplied, not set: the unselected label
                                  // is already a partly transparent ink, and
                                  // setting .6 on it would come out brighter
                                  // than the word it is meant to sit behind.
                                  color: style.color?.withValues(
                                    alpha: (style.color?.a ?? 1) * 0.6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of chips that scrolls sideways and runs off both edges of the
/// screen.
///
/// The hand-off is specific about this: the Date and Remind me rows are a
/// single row that bleeds to the edge of the phone, not a wrapping block. A
/// wrap re-flows into two or three lines as options are added and the form
/// grows a different height per item; a rail stays one line forever, and the
/// half-chip cut off at the right edge is what tells the reader to push it.
///
/// Because the rail supplies its own gutters, the screen that holds it must
/// not — put it outside the body's horizontal padding.
/// A chip with no edge: transparent when off, accent-faint when on.
///
/// The build file calls this shape `flat`, and it is used where a chip is a
/// *shortcut* to a control that is already on screen rather than the control
/// itself. A bordered pill beside the field it fills would read as a second
/// place the value could live.
/// A small word set into a row, naming a state the row is in.
///
/// `FREE TRIAL` is the one it exists for. It replaced tinting the row's edge,
/// its amount and its countdown all at once: those three say "pay attention to
/// this line", which is what an overdue item means, and a trial is not that. It
/// is a fact — *you are not being charged yet* — and a fact is best said in the
/// word for it.
///
/// Uppercase and letter-spaced rather than sentence case, so it reads as a
/// label attached to the name rather than as a second, shouting name. Caller
/// passes normal case; the widget does the shouting.
class StatusBadge extends StatelessWidget {
  final String label;

  const StatusBadge(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SubdockColors.accentFaint,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: TextStyle(
          fontFamily: SubdockText.family,
          fontSize: 11,
          height: 1.25,
          letterSpacing: 0.7,
          fontWeight: SubdockWeight.semibold,
          color: SubdockColors.accent,
        ),
      ),
    );
  }
}

class FlatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const FlatChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SubdockColors.accentFaint : const Color(0x00000000),
      borderRadius: BorderRadius.circular(SubdockRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Text(
            label,
            style: SubdockText.chip.copyWith(
              fontSize: 13,
              color: selected ? SubdockColors.accent : SubdockColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class ChipRail extends StatelessWidget {
  final List<Widget> children;

  const ChipRail({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.screenH,
        vertical: 2,
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row of segments that divide the width between them.
///
/// The Glass design draws this as one inset tray with the selected segment
/// lifted out of it in solid white — not as a row of separate pills. That
/// matters: the options here are exhaustive and mutually exclusive (Month /
/// Year, Move to yearly / Cancel a service), and a single tray is what says
/// "one of these, always". Separate pills would read as independent filters.
class SegmentedRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelect;

  /// Give each segment a share of the width in proportion to its label.
  ///
  /// Off by default, because equal thirds are what a tray of short options
  /// (Month / Year, All / Paid / Missed) should look like. On where the labels
  /// are lopsided — `After a number of payments` beside `On a date` — since an
  /// equal split there spends half the tray on nine characters and truncates
  /// the twenty-six beside them, which is the one thing a segment must never
  /// do: a segment whose label is cut off cannot be read before it is chosen.
  final bool weighted;

  /// A mark before each label, one per segment. Only the Upcoming header uses
  /// them: `List` and `Calendar` are two ways of drawing the same items rather
  /// than two subsets of them, and the icon is what says so before the words
  /// are read.
  final List<IconData>? icons;

  /// Size the tray to its labels instead of dividing the width it is given.
  ///
  /// Off by default: a tray of exhaustive options (Month / Year) filling its
  /// row is what says the options are the whole set. On where the tray shares
  /// a row with something else — the Upcoming header puts the filter controls
  /// beside it — since a full-width tray there would push them off the screen.
  final bool tight;

  const SegmentedRow({
    super.key,
    required this.labels,
    required this.selected,
    this.onSelect,
    this.weighted = false,
    this.icons,
    this.tight = false,
  });

  /// The horizontal padding inside one segment, both sides.
  static const double _segmentPadding = 16;

  static const TextStyle _segmentStyle = TextStyle(
    fontFamily: SubdockText.family,
    fontSize: 14.5,
    height: 1.2,
    fontWeight: SubdockWeight.medium,
  );

  /// What each segment needs, measured rather than guessed.
  ///
  /// Character count is not a usable stand-in here: the labels this is used
  /// for are ordinary English, where `payments` is eight narrow letters and
  /// `On a date` is nine mostly-wide ones plus two spaces. Laying out the text
  /// for real is a handful of microseconds and it is the only way to be sure
  /// no segment is handed less width than its own label occupies.
  static List<double> _widths(List<String> labels, TextScaler scaler) => [
    for (final label in labels)
      (TextPainter(
            text: TextSpan(text: label, style: _segmentStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout()).width +
          _segmentPadding,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(SubdockRadius.chip),
        border: Border.all(color: SubdockColors.hairline),
      ),
      child: Builder(
        builder: (context) {
          final widths = weighted
              ? _widths(labels, MediaQuery.textScalerOf(context))
              : null;

          return Row(
            mainAxisSize: tight ? MainAxisSize.min : MainAxisSize.max,
            children: [
              for (var i = 0; i < labels.length; i++)
                _sized(
                  tight: tight,
                  // Flex is an int, so the measured widths are scaled up
                  // before rounding — at 1:1 a two-point difference between
                  // two segments would round away to nothing.
                  flex: widths == null ? 1 : (widths[i] * 10).round(),
                  child: Material(
                    color: i == selected
                        ? SubdockColors.segmentSelected
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(SubdockRadius.chip),
                    child: InkWell(
                      onTap: onSelect == null ? null : () => onSelect!(i),
                      borderRadius: BorderRadius.circular(SubdockRadius.chip),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (icons != null) ...[
                              Icon(
                                icons![i],
                                size: 16,
                                color: i == selected
                                    ? SubdockColors.ink
                                    : SubdockColors.inkMuted,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                labels[i],
                                // A segment is a third of a phone wide at most.
                                // A label that does not fit has to clip on one
                                // line rather than wrap and make this row taller
                                // than the one beside it.
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: _segmentStyle.copyWith(
                                  color: i == selected
                                      ? SubdockColors.ink
                                      : SubdockColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// A segment takes its share of the row, or takes only what it needs.
  static Widget _sized({
    required bool tight,
    required int flex,
    required Widget child,
  }) => tight ? child : Expanded(flex: flex, child: child);
}

/// The white box a field's contents sit in. One elevation below a card.
class FieldBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Drawn while the field has focus: the accent as a ring rather than a fill.
  final bool focused;

  const FieldBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: focused
          ? SubdockSurface.card(radius: SubdockRadius.field).copyWith(
              border: Border.all(color: SubdockColors.accent, width: 1.5),
            )
          : SubdockSurface.card(radius: SubdockRadius.field),
      padding: padding,
      child: child,
    );
  }
}

/// A label above a field, with the field under it.
class Field extends StatelessWidget {
  /// Null draws the control with no heading.
  ///
  /// The add form uses it: the build file labels `NAME` and `BILLING CYCLE`
  /// and then stops, because the chips under the name field are self-evidently
  /// a category and the switch reading "In a free trial now" is its own label.
  /// A heading over either would be the screen saying the same thing twice.
  final String? label;

  final Widget child;

  /// Set when the child supplies its own gutters and runs to the screen edge
  /// — a [ChipRail]. The label still needs the gutter, so it keeps it.
  final bool bleed;

  const Field({
    super.key,
    required this.label,
    required this.child,
    this.bleed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label case final label?)
          Padding(
            padding: EdgeInsets.only(
              left: bleed ? SubdockSpacing.screenH : 0,
              right: bleed ? SubdockSpacing.screenH : 0,
              bottom: SubdockSpacing.labelToControl,
            ),
            child: Text(label.toUpperCase(), style: SubdockText.sectionLabel),
          ),
        child,
      ],
    );
  }
}

/// A field whose value is picked from a list: category, repeat count.
class PickerField extends StatelessWidget {
  final String value;
  final bool placeholder;
  final VoidCallback? onTap;

  /// A second line under the value, saying what tapping does.
  ///
  /// Only worth having where the value itself is still a prompt — the date
  /// field reads `Choose a date` before it is set, and `Tap to open the
  /// calendar` under it is what turns that from a label into an affordance.
  /// A field that already holds a real value has nothing to add.
  final String? hint;

  const PickerField({
    super.key,
    required this.value,
    this.placeholder = false,
    this.onTap,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SubdockRadius.field),
      child: FieldBox(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: placeholder
                        ? SubdockText.fieldValue.copyWith(
                            color: SubdockColors.inkMuted,
                          )
                        : SubdockText.fieldValue,
                  ),
                  if (hint case final hint?) ...[
                    const SizedBox(height: 3),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SubdockText.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Caret(),
          ],
        ),
      ),
    );
  }
}

/// The iOS-shaped switch, drawn here so it carries the app's accent rather
/// than Material's.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 25,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? SubdockColors.accent : SubdockColors.accentSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: SubdockColors.knob,
              shape: BoxShape.circle,
              boxShadow: SubdockShadow.knob,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row carrying a switch. Its label is full ink: it is a control, not a fact.
class ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SubdockSpacing.rowH,
        vertical: SubdockSpacing.rowV,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: SubdockText.rowLink)),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A short explanatory line under a card. Never a tooltip: the design puts the
/// caveat on screen where it cannot be missed.
class Footnote extends StatelessWidget {
  final String text;

  const Footnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text, style: SubdockText.footnote),
    );
  }
}
