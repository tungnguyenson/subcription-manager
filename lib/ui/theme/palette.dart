import 'package:flutter/material.dart';

/// One complete set of colour tokens: every colour the app can paint, in one
/// brightness.
///
/// The Glass look has a light and a dark variant, and they are *the same
/// design* — same layout, same spacing, same radii, same type, same weights.
/// Only colour and opacity differ. Anything that would change between the two
/// beyond colour belongs somewhere else in `theme.dart`, not here.
///
/// The dark variant is not the light one inverted. Two rules drive it, and
/// both are the opposite of what an inversion would do:
///
/// 1. **Elevation is drawn with a border, never a shadow.** A drop shadow on a
///    dark ground is invisible — there is nothing left to darken. So the light
///    variant's `#14161A` shadows become empty lists in dark and the hairline
///    does the whole job, exactly as it already does for a card in light.
/// 2. **Text on a filled accent goes dark, not white.** The dark accent is
///    `oklch(.74 .11 262)`, a *light* blue, and white on it fails contrast.
///    That is what [onAccent] is for, and why it is a token rather than the
///    `Color(0xFFFFFFFF)` that used to be written at each call site.
///
/// One thing deliberately does not follow the theme: the letter inside a
/// service tile stays white in both, because it sits on a brand tint that is
/// the provider's colour and does not know what theme it is in.
@immutable
class SubdockPalette {
  final Brightness brightness;

  // ---- ground ----

  /// The flat mid-tone of [page].
  ///
  /// Not the app background — that is the gradient. This is the fill for the
  /// few places that need one opaque colour and cannot take a gradient behind
  /// them: a platform date picker, a screenshot placeholder, a test that wants
  /// a deterministic ground.
  final Color canvas;

  /// The app ground. Four stops at `160deg`, and the third one is warm in both
  /// variants: a two-stop ramp reads as a flat wash, and the whole reason the
  /// surfaces can be translucent is that there is something behind them worth
  /// seeing.
  final LinearGradient page;

  // ---- surfaces ----

  /// Every card, field and chip at rest. Translucent by design.
  final Color card;

  /// The hairline that gives a translucent surface its edge. This, not a
  /// shadow, is what separates a card from the ground.
  final Color glassEdge;

  /// The same hairline on a small surface — a chip, a tile. A shade weaker in
  /// dark (`.10` against `.12`), which is the design's `cardSm`. In light both
  /// are `rgba(255,255,255,.75)` and this is the same colour as [glassEdge].
  final Color glassEdgeSm;

  /// Where a surface has to be opaque because something is sliding under it:
  /// the toast, and the sheets.
  ///
  /// In dark this is *lighter* than [canvas], not darker. Raising a surface
  /// away from the ground is done with light on a dark theme, and the shadow
  /// that would have done it in light is gone.
  final Color solid;

  /// The top hairline of a sheet, which replaces the drop shadow in dark.
  /// Fully transparent in light, where [SubdockShadow.sheet] still does it.
  final Color sheetEdge;

  /// Behind a sheet: the ground dimmed so the sheet is the only thing to read.
  final Color scrim;

  /// The tab bar, which sits over scrolling content.
  final Color tabBar;

  /// Its top edge — a bright hairline, not a shadow. The same trick every
  /// other Glass surface uses, turned on its side.
  final Color tabBarEdge;

  /// The banner that says notifications are off. Fainter than a card: it is a
  /// notice, not a thing to act on.
  final Color banner;

  /// An empty tile inside a field, and its brighter edge.
  final Color thumb;
  final Color thumbEdge;

  /// The raised slab under the selected segment of a segmented control. The
  /// one surface in the app that is brighter than a card rather than equal to
  /// it, because it has to read as sitting on top of the track.
  final Color segmentSelected;

  /// The knob of a toggle. Fully opaque — a translucent knob on a translucent
  /// track has nothing left to read.
  final Color knob;

  /// Behind the lock-screen mock-up on the onboarding screen.
  final Color lockScreen;

  // ---- ink ----

  final Color ink;

  /// Text and marks drawn *on* a filled [ink] surface: the toast at the bottom
  /// of the screen, the one place in the app where the ink colour becomes a
  /// background. Same reason [onAccent] exists, and the same trap: in dark
  /// [ink] is near-white, so anything that reaches for a light token here
  /// paints white on white and the toast reads as a blank banner.
  final Color onInk;

  /// A row's label, a subtitle, a paragraph. The stronger of the two greys.
  /// Secondary text *says something* about the thing beside it.
  final Color inkSecondary;

  /// A section heading, small print, an idle tab, a literal date under a
  /// countdown. The weaker grey, for text that *names* a thing rather than
  /// telling you about it.
  final Color inkMuted;

  /// The rule between two rows inside a card. Also the fill behind an inset
  /// control (`softBg` in the design tokens).
  final Color hairline;

  // ---- accent ----

  /// The one accent. Primary actions, the selected chip, the add button.
  final Color accent;

  /// Text and marks drawn *on* a filled [accent]. White in light, near-black
  /// in dark. Never hardcode `Color(0xFFFFFFFF)` for this.
  final Color onAccent;

  /// [onAccent] at 80%, for a second line inside a filled accent surface.
  final Color onAccentSoft;

  /// The accent as an outline around a card that needs marking without being
  /// filled: a trial row, the "did you see the date" prompt.
  final Color accentEdge;

  /// An inactive toggle track, and the bars on the spending chart.
  final Color accentSoft;

  /// The ground under the add form's summary block, and a selected flat chip.
  final Color accentFaint;

  /// The spending chart's bar for a month that has not happened yet, and the
  /// same bar when it is the selected one.
  ///
  /// Their own pair rather than [accentFaint] and [accent], because a
  /// projected month stays visibly lighter than a settled one *even while
  /// selected* — see trap 22.
  final Color chartAhead;
  final Color chartAheadSelected;

  // ---- danger ----

  /// Overdue. Its own hue family, deliberately not a tint of the accent: the
  /// accent means "you can act here" and this means "you already didn't".
  final Color danger;

  /// Text on a filled [danger] — the countdown pill on an overdue row.
  final Color onDanger;

  /// The ground of an overdue row: the danger mixed 10% into the card fill, so
  /// it stays a piece of glass rather than becoming a red panel.
  final Color dangerTint;

  /// The hairline around an overdue row, replacing [glassEdge] there.
  final Color dangerEdge;

  // ---- savings ----

  /// Money the user would stop spending. The second hue in the app, and it
  /// exists for one screen. Savings are the only place where a number is
  /// *good* news, and the accent cannot say that: it is already spent on "you
  /// can act here".
  final Color savings;

  /// Text on a filled [savings] button.
  final Color onSavings;

  final Color savingsEdge;
  final Color savingsFaint;

  const SubdockPalette({
    required this.brightness,
    required this.canvas,
    required this.page,
    required this.card,
    required this.glassEdge,
    required this.glassEdgeSm,
    required this.solid,
    required this.sheetEdge,
    required this.scrim,
    required this.tabBar,
    required this.tabBarEdge,
    required this.banner,
    required this.thumb,
    required this.thumbEdge,
    required this.segmentSelected,
    required this.knob,
    required this.lockScreen,
    required this.ink,
    required this.onInk,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.onAccentSoft,
    required this.accentEdge,
    required this.accentSoft,
    required this.accentFaint,
    required this.chartAhead,
    required this.chartAheadSelected,
    required this.danger,
    required this.onDanger,
    required this.dangerTint,
    required this.dangerEdge,
    required this.savings,
    required this.onSavings,
    required this.savingsEdge,
    required this.savingsFaint,
  });

  bool get isDark => brightness == Brightness.dark;

  /// The original Glass tokens, transcribed from `Subdock Glass App.dc.html`.
  static const SubdockPalette light = SubdockPalette(
    brightness: Brightness.light,
    canvas: Color(0xFFEEF0F4),
    page: LinearGradient(
      // CSS `160deg` points down and slightly right; in Flutter's y-down
      // alignment space that is `(sin 160°, -cos 160°)` = `(0.342, 0.940)`.
      begin: Alignment(-0.342, -0.940),
      end: Alignment(0.342, 0.940),
      colors: [
        Color(0xFFDFE6F6),
        Color(0xFFEEF0F4),
        Color(0xFFF6ECE6),
        Color(0xFFE3EDF1),
      ],
      stops: [0.0, 0.42, 0.74, 1.0],
    ),
    card: Color(0x8CFFFFFF), // rgba(255,255,255,.55)
    glassEdge: Color(0xBFFFFFFF), // rgba(255,255,255,.75)
    glassEdgeSm: Color(0xBFFFFFFF), // cardSm is the same hairline in light
    solid: Color(0xFAFCFCFB),
    sheetEdge: Color(0x00FFFFFF), // the drop shadow does this job in light
    scrim: Color(0x5C14161A),
    tabBar: Color(0x8CFFFFFF),
    tabBarEdge: Color(0xB3FFFFFF), // rgba(255,255,255,.70)
    banner: Color(0x6BFFFFFF), // rgba(255,255,255,.42)
    thumb: Color(0x80FFFFFF),
    thumbEdge: Color(0xCCFFFFFF),
    segmentSelected: Color(0xE6FFFFFF),
    knob: Color(0xFFFFFFFF),
    lockScreen: Color(0xFFE4E7EE),
    ink: Color(0xFF1B2230),
    onInk: Color(0xFFFFFFFF),
    inkSecondary: Color(0x9E1B2230), // rgba(27,34,48,.62)
    inkMuted: Color(0x801B2230), // rgba(27,34,48,.50)
    hairline: Color(0x1A1B2230), // rgba(27,34,48,.10)
    accent: Color(0xFF466FBD), // oklch(.55 .13 262)
    onAccent: Color(0xFFFFFFFF),
    onAccentSoft: Color(0xCCFFFFFF),
    accentEdge: Color(0x66466FBD), // 40%
    accentSoft: Color(0x38466FBD), // 22%
    accentFaint: Color(0x1F466FBD), // 12%
    chartAhead: Color(0x1C466FBD), // 11%
    chartAheadSelected: Color(0x8C466FBD), // 55%
    danger: Color(0xFFC5031B), // oklch(.52 .21 26)
    onDanger: Color(0xFFFFFFFF),
    dangerTint: Color(0x98FDEAE8),
    dangerEdge: Color(0x52C5031B), // 32%
    savings: Color(0xFF267F47), // oklch(.53 .12 152)
    onSavings: Color(0xFFFFFFFF),
    savingsEdge: Color(0x61267F47), // 38%
    savingsFaint: Color(0x1F267F47), // 12%
  );

  /// The dark variant.
  ///
  /// The three hues are the light ones lifted in lightness and pulled in
  /// chroma — `oklch(.55 .13 262)` becomes `oklch(.74 .11 262)`, and danger
  /// and savings move by the same amount. That is what keeps them reading as
  /// the same three colours rather than as a second, unrelated palette.
  ///
  /// The accent *tints* do not come from [accent] though: they are built on
  /// `#96AFFF`, a lighter blue still. A 16%-opacity wash of the accent itself
  /// is invisible on a dark ground, and raising the opacity instead would give
  /// a filled panel where the design wants a hint.
  static const SubdockPalette dark = SubdockPalette(
    brightness: Brightness.dark,
    canvas: Color(0xFF1A1D24), // the 42% stop of [page]
    page: LinearGradient(
      begin: Alignment(-0.342, -0.940),
      end: Alignment(0.342, 0.940),
      colors: [
        Color(0xFF181F31),
        Color(0xFF1A1D24),
        Color(0xFF241B19),
        Color(0xFF141D21),
      ],
      stops: [0.0, 0.42, 0.74, 1.0],
    ),
    card: Color(0x13FFFFFF), // rgba(255,255,255,.075)
    glassEdge: Color(0x1FFFFFFF), // rgba(255,255,255,.12)
    glassEdgeSm: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
    solid: Color(0xFA21242D),
    sheetEdge: Color(0x1FFFFFFF),
    scrim: Color(0x8C000000),
    tabBar: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    tabBarEdge: Color(0x1FFFFFFF),
    banner: Color(0x0DFFFFFF), // rgba(255,255,255,.05)
    thumb: Color(0x17FFFFFF), // rgba(255,255,255,.09)
    thumbEdge: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    segmentSelected: Color(0x2EFFFFFF), // rgba(255,255,255,.18)
    knob: Color(0xFFE9ECF3),
    lockScreen: Color(0xFF23262E),
    ink: Color(0xFFE9ECF3),
    onInk: Color(0xFF111624),
    inkSecondary: Color(0x9EE9ECF3), // rgba(233,236,243,.62)
    inkMuted: Color(0x75E9ECF3), // rgba(233,236,243,.46)
    hairline: Color(0x21FFFFFF), // rgba(255,255,255,.13)
    accent: Color(0xFF85ABF0), // oklch(.74 .11 262)
    onAccent: Color(0xFF111624),
    onAccentSoft: Color(0xCC111624),
    accentEdge: Color(0x7396AFFF), // rgba(150,175,255,.45)
    accentSoft: Color(0x3D96AFFF), // rgba(150,175,255,.24)
    accentFaint: Color(0x2996AFFF), // rgba(150,175,255,.16)
    chartAhead: Color(0x2496AFFF), // rgba(150,175,255,.14)
    chartAheadSelected: Color(0x7396AFFF),
    danger: Color(0xFFF27168), // oklch(.70 .16 26)
    onDanger: Color(0xFF14161A),
    // danger at 10% over the card fill, flattened to one colour: a
    // BoxDecoration takes a single fill, so the two layers are composited
    // here rather than stacked at every overdue row.
    dangerTint: Color(0x2BF7AAA5),
    dangerEdge: Color(0x52F27168), // 32%
    savings: Color(0xFF73B785), // oklch(.72 .10 152)
    onSavings: Color(0xFF11241A),
    savingsEdge: Color(0x7373B785), // 45%
    savingsFaint: Color(0x2973B785), // 16%
  );
}
