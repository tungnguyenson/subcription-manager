import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/category_glyphs.dart';
import 'package:subdock/ui/widgets/service_marks.data.dart';

/// A brand's own mark, compiled from SVG by `tool/gen_service_marks.py`.
///
/// The path is absolute move/line/cubic/close on a 24-unit square, which is
/// everything left of SVG's grammar once relative coordinates are resolved and
/// arcs are approximated. That work happens at build time so this file can
/// parse a mark with four cases and no dependency; see the generator's header
/// for why the alternative — an SVG runtime plus thirty asset files — was not
/// worth it in an app that draws its own tab marks.
@immutable
class BrandMark {
  /// Opaque ARGB. The brand's own colour, not a palette choice.
  final int colour;

  final String path;

  /// Set when the source used `fill-rule="evenodd"`. Most marks punch their
  /// holes by winding a subpath backwards instead, which is Flutter's default.
  final bool evenOdd;

  const BrandMark({
    required this.colour,
    required this.path,
    this.evenOdd = false,
  });

  /// Grid the generator normalises every mark onto.
  static const double grid = 24;

  Path toPath() {
    final path = Path()
      ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
    final tokens = this.path.split(' ');

    var i = 0;
    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      switch (tokens[i++]) {
        case 'M':
          path.moveTo(next(), next());
        case 'L':
          path.lineTo(next(), next());
        case 'C':
          path.cubicTo(next(), next(), next(), next(), next(), next());
        case 'Z':
          path.close();
        case final op:
          throw FormatException('unknown path op "$op"', this.path);
      }
    }
    return path;
  }
}

/// What to draw for one item, once its name has been read.
///
/// Three tiers, in falling order of how much they tell the user: the service's
/// own mark, a category glyph in the local brand's colour, a category glyph in
/// muted ink. A fourth — the name's first letter — is what [ServiceMarkTile]
/// falls back to when none of them matches, and it stays deliberately dull so
/// that a row with a real mark reads as the more informative of the two.
sealed class MarkSpec {
  const MarkSpec();
}

/// The service's own mark. [key] indexes [brandMarks].
final class BrandSpec extends MarkSpec {
  final String key;

  const BrandSpec(this.key);
}

/// A drawn glyph, for everything with no mark to draw.
final class GlyphSpec extends MarkSpec {
  final CategoryGlyph glyph;

  /// Only set for a local brand that ships no vector mark anywhere: Viettel,
  /// VieON, iTel. The shape says what kind of thing it is and the colour says
  /// whose, which together get most of the way to a logo without inventing
  /// one. Null for household admin, which has no brand to be wrong about.
  final int? brandColour;

  const GlyphSpec(this.glyph, {this.brandColour});
}

/// Name -> mark. See [SubdockMarks.detect].
abstract final class SubdockMarks {
  /// Every mark the app can draw, keyed the way [MarkSpec] is looked up.
  ///
  /// Ordered from most to least specific *within* a family, because [detect]
  /// takes the first substring hit: `internet viettel` has to be tested before
  /// `viettel`, or every FTTH line in the country turns into a SIM card.
  static const List<(String, MarkSpec)> _rules = [
    // -- streaming and music --------------------------------------------
    ('netflix', BrandSpec('netflix')),
    ('youtube', BrandSpec('youtube')),
    ('spotify', BrandSpec('spotify')),
    ('hbo', BrandSpec('hbo')),
    ('apple tv', BrandSpec('apple-tv')),
    ('apple music', BrandSpec('apple-music')),
    ('itunes', BrandSpec('apple-music')),
    // Disney publishes no mark under a licence this app can ship, so it gets
    // the shape plus Disney's blue rather than a redrawn approximation.
    ('disney', GlyphSpec(CategoryGlyph.streaming, brandColour: 0xFF113CCF)),
    ('fpt play', GlyphSpec(CategoryGlyph.streaming, brandColour: 0xFFFF6500)),
    ('vieon', GlyphSpec(CategoryGlyph.streaming, brandColour: 0xFF00C300)),
    (
      'galaxy play',
      GlyphSpec(CategoryGlyph.streaming, brandColour: 0xFF0F7CC0),
    ),
    ('glxplay', GlyphSpec(CategoryGlyph.streaming, brandColour: 0xFF0F7CC0)),
    ('nhaccuatui', GlyphSpec(CategoryGlyph.music, brandColour: 0xFF46D2C0)),
    ('nhac cua tui', GlyphSpec(CategoryGlyph.music, brandColour: 0xFF46D2C0)),
    ('zing mp3', GlyphSpec(CategoryGlyph.music, brandColour: 0xFF7309E7)),
    ('zingmp3', GlyphSpec(CategoryGlyph.music, brandColour: 0xFF7309E7)),

    // -- games -----------------------------------------------------------
    ('xbox', BrandSpec('xbox')),
    ('game pass', BrandSpec('xbox')),
    ('playstation', BrandSpec('playstation')),
    ('ps plus', BrandSpec('playstation')),
    ('nintendo', BrandSpec('nintendo-switch')),
    ('steam', BrandSpec('steam')),

    // -- ai and software --------------------------------------------------
    ('claude', BrandSpec('claude')),
    ('chatgpt', BrandSpec('chatgpt')),
    ('openai', BrandSpec('chatgpt')),
    ('gemini', BrandSpec('gemini')),
    ('copilot', BrandSpec('github-copilot')),
    ('cursor', BrandSpec('cursor')),
    ('midjourney', BrandSpec('midjourney')),
    ('perplexity', BrandSpec('perplexity')),
    ('adobe', BrandSpec('adobe')),
    ('creative cloud', BrandSpec('adobe')),
    ('figma', BrandSpec('figma')),
    ('notion', BrandSpec('notion')),
    ('jetbrains', BrandSpec('jetbrains')),
    // Before the bare `onedrive` / `365` rules so the Microsoft mark is not
    // claimed by whichever Microsoft product is listed first.
    ('onedrive', BrandSpec('onedrive')),
    ('microsoft 365', BrandSpec('microsoft')),
    ('office 365', BrandSpec('microsoft')),
    ('microsoft', BrandSpec('microsoft')),
    ('1password', BrandSpec('1password')),
    ('vercel', BrandSpec('vercel')),

    // -- storage ----------------------------------------------------------
    ('icloud', BrandSpec('icloud')),
    ('google one', BrandSpec('google-drive')),
    ('google drive', BrandSpec('google-drive')),
    ('dropbox', BrandSpec('dropbox')),
    ('backblaze', BrandSpec('backblaze')),

    // -- hosting ----------------------------------------------------------
    ('tên miền', GlyphSpec(CategoryGlyph.domain)),
    ('ten mien', GlyphSpec(CategoryGlyph.domain)),
    ('domain', GlyphSpec(CategoryGlyph.domain)),
    ('hosting', GlyphSpec(CategoryGlyph.server)),
    ('vps', GlyphSpec(CategoryGlyph.server)),

    // -- telecom ----------------------------------------------------------
    // Internet before SIM throughout: a Viettel line and a Viettel SIM differ
    // only by that word, and they are different rows in the list.
    ('internet fpt', GlyphSpec(CategoryGlyph.router, brandColour: 0xFFFF6500)),
    (
      'internet viettel',
      GlyphSpec(CategoryGlyph.router, brandColour: 0xFFEE0033),
    ),
    ('internet vnpt', GlyphSpec(CategoryGlyph.router, brandColour: 0xFF105CAA)),
    ('cáp quang', GlyphSpec(CategoryGlyph.router)),
    ('cap quang', GlyphSpec(CategoryGlyph.router)),
    ('internet', GlyphSpec(CategoryGlyph.router)),
    ('wifi', GlyphSpec(CategoryGlyph.router)),
    ('truyền hình', GlyphSpec(CategoryGlyph.television)),
    ('truyen hinh', GlyphSpec(CategoryGlyph.television)),
    ('viettel', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFFEE0033)),
    ('vinaphone', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFF004E9D)),
    ('mobifone', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFF0063AD)),
    ('vietnamobile', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFFF68232)),
    ('itel', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFFE60001)),
    ('wintel', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFFED1C24)),
    ('vnpt', GlyphSpec(CategoryGlyph.sim, brandColour: 0xFF105CAA)),
    ('gói cước', GlyphSpec(CategoryGlyph.sim)),
    ('goi cuoc', GlyphSpec(CategoryGlyph.sim)),
    ('sim', GlyphSpec(CategoryGlyph.sim)),

    // -- the flat ---------------------------------------------------------
    ('tiền điện', GlyphSpec(CategoryGlyph.power)),
    ('tien dien', GlyphSpec(CategoryGlyph.power)),
    ('điện', GlyphSpec(CategoryGlyph.power)),
    ('electric', GlyphSpec(CategoryGlyph.power)),
    ('nước', GlyphSpec(CategoryGlyph.water)),
    ('nuoc', GlyphSpec(CategoryGlyph.water)),
    ('water', GlyphSpec(CategoryGlyph.water)),
    ('gas', GlyphSpec(CategoryGlyph.gas)),
    ('gửi xe', GlyphSpec(CategoryGlyph.vehicle)),
    ('gui xe', GlyphSpec(CategoryGlyph.vehicle)),
    ('chung cư', GlyphSpec(CategoryGlyph.building)),
    ('chung cu', GlyphSpec(CategoryGlyph.building)),
    ('phí rác', GlyphSpec(CategoryGlyph.building)),
    ('phi rac', GlyphSpec(CategoryGlyph.building)),

    // -- money ------------------------------------------------------------
    // `thẻ tín dụng` and `phí thường niên thẻ` are both cards; a bare `thẻ`
    // is not, so it is never a rule on its own.
    ('tín dụng', GlyphSpec(CategoryGlyph.card)),
    ('tin dung', GlyphSpec(CategoryGlyph.card)),
    ('thường niên', GlyphSpec(CategoryGlyph.card)),
    ('thuong nien', GlyphSpec(CategoryGlyph.card)),
    ('credit card', GlyphSpec(CategoryGlyph.card)),
    ('khoản vay', GlyphSpec(CategoryGlyph.loan)),
    ('khoan vay', GlyphSpec(CategoryGlyph.loan)),
    ('trả góp', GlyphSpec(CategoryGlyph.loan)),
    ('tra gop', GlyphSpec(CategoryGlyph.loan)),
    ('loan', GlyphSpec(CategoryGlyph.loan)),

    // -- cover ------------------------------------------------------------
    ('bảo hiểm xe', GlyphSpec(CategoryGlyph.vehicle)),
    ('bao hiem xe', GlyphSpec(CategoryGlyph.vehicle)),
    ('bảo hiểm', GlyphSpec(CategoryGlyph.insurance)),
    ('bao hiem', GlyphSpec(CategoryGlyph.insurance)),
    ('insurance', GlyphSpec(CategoryGlyph.insurance)),

    // -- papers -----------------------------------------------------------
    // `visa` last of the document rules and after `visa card`, because the
    // travel document and the payment network share the word exactly.
    ('hộ chiếu', GlyphSpec(CategoryGlyph.passport)),
    ('ho chieu', GlyphSpec(CategoryGlyph.passport)),
    ('passport', GlyphSpec(CategoryGlyph.passport)),
    ('căn cước', GlyphSpec(CategoryGlyph.identityCard)),
    ('can cuoc', GlyphSpec(CategoryGlyph.identityCard)),
    ('cccd', GlyphSpec(CategoryGlyph.identityCard)),
    ('lái xe', GlyphSpec(CategoryGlyph.identityCard)),
    ('lai xe', GlyphSpec(CategoryGlyph.identityCard)),
    ('gplx', GlyphSpec(CategoryGlyph.identityCard)),
    ('tạm trú', GlyphSpec(CategoryGlyph.identityCard)),
    ('tam tru', GlyphSpec(CategoryGlyph.identityCard)),
    ('đăng kiểm', GlyphSpec(CategoryGlyph.vehicle)),
    ('dang kiem', GlyphSpec(CategoryGlyph.vehicle)),
    ('giấy phép', GlyphSpec(CategoryGlyph.certificate)),
    ('giay phep', GlyphSpec(CategoryGlyph.certificate)),
    ('chứng chỉ', GlyphSpec(CategoryGlyph.certificate)),
    ('chung chi', GlyphSpec(CategoryGlyph.certificate)),
    ('visa card', GlyphSpec(CategoryGlyph.card)),
    ('visa', GlyphSpec(CategoryGlyph.passport)),
  ];

  /// The mark this name suggests, or null when nothing does.
  ///
  /// Matched against what the user typed rather than against a catalog id: the
  /// catalog knows 71 services and a real list will not be 71 of them. A
  /// substring rule catches `Netflix Premium` and `Tiền điện tháng 9` alike,
  /// and it keeps working when the user renames a row.
  ///
  /// Null rather than a default shape. A wrong mark on every row is worse than
  /// a letter on some of them, because the mark is read before the name is.
  static MarkSpec? detect(String name) {
    final haystack = name.toLowerCase();
    for (final (keyword, spec) in _rules) {
      if (haystack.contains(keyword)) return spec;
    }
    return null;
  }
}

/// The square beside a row: a service's mark, a category glyph, or a letter.
///
/// The tile is tinted with whatever it is drawing — Netflix red at a tenth
/// strength behind the Netflix mark — which is what keeps a column of them
/// from reading as a column of grey chips without turning the list into a
/// swatch chart.
class ServiceMarkTile extends StatelessWidget {
  final String name;

  /// An explicit key: either a [brandMarks] key or a [CategoryGlyph] name.
  /// Null asks the name. Set once the user has overridden the guess, and an
  /// override is never re-guessed.
  final String? iconName;

  final double size;
  final double radius;
  final double fontSize;

  /// Set on the add form, where the tile is the way into the icon gallery.
  final VoidCallback? onTap;

  const ServiceMarkTile(
    this.name, {
    super.key,
    this.iconName,
    this.size = 34,
    this.radius = SubdockRadius.chip,
    this.fontSize = 14,
    this.onTap,
  });

  /// Look up an explicit key, in the one namespace both kinds of mark share.
  static MarkSpec? specFor(String key) {
    if (brandMarks.containsKey(key)) return BrandSpec(key);
    for (final glyph in CategoryGlyph.values) {
      if (glyph.name == key) return GlyphSpec(glyph);
    }
    return null;
  }

  Widget _letter(String trimmed) => Text(
    trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase(),
    style: SubdockText.tileLetter.copyWith(fontSize: fontSize),
  );

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final chosen = iconName;
    final spec = chosen == null
        ? SubdockMarks.detect(trimmed)
        : specFor(chosen);

    final (Widget child, Color tint) = switch (spec) {
      // An explicit key that no longer names anything -- a mark retired from a
      // later build -- falls through to the letter rather than to an empty
      // square, which is the one outcome that would look like a bug.
      BrandSpec(:final key) => switch (brandMarks[key]) {
        final BrandMark mark => (
          _BrandGlyph(mark: mark, size: size * 0.56),
          Color(mark.colour),
        ),
        null => (_letter(trimmed), SubdockColors.canvas),
      },
      GlyphSpec(:final glyph, brandColour: final int colour) => (
        CategoryMark(glyph: glyph, colour: Color(colour), size: size * 0.62),
        Color(colour),
      ),
      GlyphSpec(:final glyph) => (
        CategoryMark(
          glyph: glyph,
          colour: SubdockColors.inkMuted,
          size: size * 0.62,
        ),
        SubdockColors.canvas,
      ),
      null => (_letter(trimmed), SubdockColors.canvas),
    };

    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // A household glyph and the letter both keep the flat canvas fill the
        // tile always had; only a brand tints, so the colour in the column
        // means "this is that service" rather than "this row is a bill".
        color: tint == SubdockColors.canvas
            ? SubdockColors.canvas
            : tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SubdockColors.hairline),
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
}

class _BrandGlyph extends StatelessWidget {
  final BrandMark mark;
  final double size;

  const _BrandGlyph({required this.mark, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandPainter(mark)),
    );
  }
}

class _BrandPainter extends CustomPainter {
  final BrandMark mark;

  const _BrandPainter(this.mark);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / BrandMark.grid, size.height / BrandMark.grid);
    canvas.drawPath(mark.toPath(), Paint()..color = Color(mark.colour));
  }

  @override
  bool shouldRepaint(covariant _BrandPainter old) => old.mark != mark;
}
