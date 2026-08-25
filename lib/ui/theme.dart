import 'package:flutter/material.dart';

/// The Glass design tokens, transcribed from `Subdock Glass App.dc.html`.
///
/// The look is one idea, and it is the opposite of the Layered look this
/// replaced: **the ground carries the colour and a surface is a hole cut in
/// frosted glass.** There is a four-stop gradient behind everything, and a
/// card is translucent white with a bright white hairline around it. Nothing
/// casts a drop shadow. That is not a simplification of the design — the Glass
/// theme sets `cardLg` and `cardSm` to a single `inset 0 0 0 1px
/// rgba(255,255,255,.75)`, so the hairline *is* the whole separation.
///
/// Two consequences worth knowing before editing anything here:
///
/// 1. A card drawn with a drop shadow instead of the hairline disappears. The
///    gradient and the card are within a few percent of the same lightness, so
///    a shadow alone gives no edge to find.
/// 2. An opaque white card also breaks it, in the other direction: it reads as
///    a sheet of paper laid on the gradient rather than as part of it. Every
///    surface here is translucent on purpose, which is why the fills below
///    carry an alpha and are not hex triples.
///
/// The design frames are 390x844 at 1x, so every number is already in Flutter
/// logical pixels and can be transcribed literally.
abstract final class SubdockColors {
  /// The flat mid-tone of [SubdockGradients.page].
  ///
  /// Not the app background — that is the gradient. This is the fill for the
  /// few places that need one opaque colour and cannot take a gradient behind
  /// them: a platform date picker, a screenshot placeholder, a test that wants
  /// a deterministic ground.
  static const Color canvas = Color(0xFFEEF0F4);

  /// Every card, field, chip and the tab bar. Translucent by design; see the
  /// class comment before making it opaque.
  static const Color card = Color(0x8CFFFFFF); // rgba(255,255,255,.55)

  /// The bright hairline that gives a translucent surface its edge. This, not
  /// a shadow, is what separates a card from the ground.
  static const Color glassEdge = Color(0xBFFFFFFF); // rgba(255,255,255,.75)

  /// Where a surface has to be opaque because something is sliding under it:
  /// the toast, and the sheet that asks for notification permission.
  static const Color solid = Color(0xFAFCFCFB);

  static const Color ink = Color(0xFF1B2230);

  /// A row's label, a subtitle, a paragraph — `rgba(27,34,48,.62)`.
  ///
  /// The stronger of the two greys. Secondary text *says something* about the
  /// thing beside it.
  static const Color inkSecondary = Color(0x9E1B2230);

  /// A section heading, small print, an idle tab, a literal date under a
  /// countdown — `rgba(27,34,48,.5)`.
  ///
  /// The weaker grey, and the design is consistent about which is which: this
  /// one is for text that *names* a thing rather than telling you about it.
  static const Color inkMuted = Color(0x801B2230);

  /// The rule between two rows inside a card — `rgba(27,34,48,.10)`. Also the
  /// fill behind an inset control (`softBg` in the design tokens).
  static const Color hairline = Color(0x1A1B2230);

  /// The one accent — `oklch(.55 .13 262)`. Primary actions, the selected
  /// chip, the add button, a trial.
  static const Color accent = Color(0xFF466FBD);

  /// The accent as an outline around a card that needs marking without being
  /// filled: a trial row, the "did you see the date" prompt — 40%.
  static const Color accentEdge = Color(0x66466FBD);

  /// An inactive toggle track, and the bars on the spending chart — 22%.
  static const Color accentSoft = Color(0x38466FBD);

  /// The ground under the add form's summary block, and a selected flat
  /// chip — 12%.
  static const Color accentFaint = Color(0x1F466FBD);

  /// Kept for the few call sites that predate the Glass tokens. [accentEdge]
  /// and [accentSoft] are the named equivalents; prefer those.
  static const Color accentHalf = accentEdge;
  static const Color accentTrack = accentSoft;
  static const Color accentBar = accentSoft;

  /// Overdue — `oklch(.52 .21 26)`.
  ///
  /// Its own hue family, deliberately not a tint of the accent: the accent
  /// means "you can act here" and this means "you already didn't".
  static const Color danger = Color(0xFFC5031B);

  /// The ground of an overdue row: the danger mixed 10% into the card fill,
  /// so it stays a piece of glass rather than becoming a red panel.
  static const Color dangerTint = Color(0x98FDEAE8);

  /// The hairline around an overdue row, replacing [glassEdge] there — 32%.
  static const Color dangerEdge = Color(0x52C5031B);

  /// Money the user would stop spending — `oklch(.53 .12 152)`.
  ///
  /// The second hue in the app, and it exists for one screen. Savings are the
  /// only place where a number is *good* news, and the accent cannot say that:
  /// it is already spent on "you can act here".
  static const Color savings = Color(0xFF267F47);
  static const Color savingsEdge = Color(0x61267F47); // 38%
  static const Color savingsFaint = Color(0x1F267F47); // 12%

  /// The tab bar, which sits over scrolling content and so is slightly more
  /// opaque than a card — `rgba(255,255,255,.62)`.
  static const Color tabBar = Color(0x9EFFFFFF);

  /// The banner that says notifications are off — `rgba(255,255,255,.42)`.
  /// Fainter than a card: it is a notice, not a thing to act on.
  static const Color banner = Color(0x6BFFFFFF);

  /// An empty tile inside a field, and its brighter edge.
  static const Color thumb = Color(0x80FFFFFF);
  static const Color thumbEdge = Color(0xCCFFFFFF);

  /// The knob of a toggle. Fully opaque — a translucent knob on a translucent
  /// track has nothing left to read.
  static const Color knob = Color(0xFFFFFFFF);

  /// Behind the lock-screen mock-up on the onboarding screen.
  static const Color lockScreen = Color(0xFFE4E7EE);
}

/// The gradients. There are two, and they are the same family: the page and
/// anything that has to sit flush against it.
abstract final class SubdockGradients {
  /// The app ground —
  /// `linear-gradient(160deg,#dfe6f6 0%,#eef0f4 42%,#f6ece6 74%,#e3edf1 100%)`.
  ///
  /// Four stops, and the warm one at 74% is the point of it: a two-stop
  /// blue-to-blue ramp reads as a flat wash, and the whole reason the surfaces
  /// can be translucent is that there is something behind them worth seeing.
  ///
  /// CSS `160deg` points down and slightly right; in Flutter's y-down
  /// alignment space that is `(sin 160°, -cos 160°)` = `(0.342, 0.940)`.
  static const LinearGradient page = LinearGradient(
    begin: Alignment(-0.342, -0.940),
    end: Alignment(0.342, 0.940),
    colors: [
      Color(0xFFDFE6F6),
      Color(0xFFEEF0F4),
      Color(0xFFF6ECE6),
      Color(0xFFE3EDF1),
    ],
    stops: [0.0, 0.42, 0.74, 1.0],
  );
}

/// Corner radii. The design uses a small fixed set; a value outside it is a
/// mistake rather than a variation.
abstract final class SubdockRadius {
  /// A chip, a date shortcut, a small control. `radiusSm` in the design
  /// tokens: `min(radius, 9)`.
  static const double chip = 9;

  /// Same number, different job: a segmented control, a tile inside a field.
  static const double control = 9;
  static const double tile = 9;

  /// The default for a card, a field and a full-width button. Almost
  /// everything. Two points larger than the Layered theme's 13 — a softer
  /// corner is what stops a translucent panel looking like a cut-out.
  static const double card = 15;
  static const double field = 15;

  /// The tile on an onboarding row.
  static const double featureTile = 15;

  /// The empty-state placard.
  static const double placard = 22;

  /// The toast, and the top corners of the permission sheet.
  static const double sheet = 26;
}

abstract final class SubdockSpacing {
  /// Left and right margin of every screen body.
  static const double screenH = 18;

  /// Padding inside a card row.
  static const double rowH = 14;
  static const double rowV = 14;

  /// The gap between two cards in a stack of them.
  static const double rowGap = 10;

  /// Gap above an uppercase section label, and below it.
  static const double sectionTop = 28;
  static const double sectionBottom = 10;

  /// A field's label to the control under it.
  static const double labelToControl = 8;

  /// Between two blocks of a form.
  static const double formBlock = 26;

  /// The last thing on a screen to the tab bar under it.
  ///
  /// Only the gap. The bar's own height is *not* in here, and must not be:
  /// [AppShell] runs the list underneath the bar on purpose, so the bar has
  /// something to blur. Use [screenPadding], which adds the bar back.
  static const double contentBottom = 18;

  /// The padding a full-screen scrolling list takes.
  ///
  /// The bottom is the tab bar plus [contentBottom], read off the MediaQuery
  /// rather than hardcoded: `Scaffold(extendBody: true)` reports the bar's
  /// height as bottom padding to its body, and the height itself moves with
  /// the home indicator. Hardcoding [contentBottom] alone leaves the last row
  /// of every screen under the bar, where it cannot be tapped -- which is what
  /// happened to `Delete this item`.
  static EdgeInsets screenPadding(BuildContext context) => EdgeInsets.fromLTRB(
    screenH,
    6,
    screenH,
    contentBottom + MediaQuery.paddingOf(context).bottom,
  );
}

/// The elevations.
///
/// Three of the four are empty, and that is the Glass theme rather than an
/// omission: `cardLg` and `cardSm` are both `inset 0 0 0 1px
/// rgba(255,255,255,.75)`, which is a border and lives on the decoration, not
/// here. See [SubdockSurface].
///
/// What is left are the two places where something genuinely floats over
/// content rather than sitting in the same plane as it.
abstract final class SubdockShadow {
  /// A card, a field, a button. Nothing — the hairline does this job.
  static const List<BoxShadow> card = [];
  static const List<BoxShadow> soft = [];
  static const List<BoxShadow> tabBar = [];

  /// The sheet that rises over the list to ask for notification permission —
  /// `0 -20px 44px rgba(20,22,26,.22)`.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x3814161A), offset: Offset(0, -20), blurRadius: 44),
  ];

  /// The toast — `0 10px 24px rgba(20,22,26,.28)`.
  static const List<BoxShadow> toast = [
    BoxShadow(color: Color(0x4714161A), offset: Offset(0, 10), blurRadius: 24),
  ];

  /// The knob of a toggle. The one shadow the design keeps on a control,
  /// because the knob has to read as a solid object on a tinted track.
  static const List<BoxShadow> knob = [
    BoxShadow(color: Color(0x4D14161A), offset: Offset(0, 1), blurRadius: 2),
  ];
}

/// The decorations every translucent surface is built from.
///
/// Centralised because the fill and the hairline are a matched pair: either
/// alone gives a surface that cannot be seen, or one that does not belong to
/// the theme. A screen that writes its own `BoxDecoration` with
/// `SubdockColors.card` and no border is the single most likely way to break
/// the look, so there is no reason for one to exist.
abstract final class SubdockSurface {
  /// A card, a field, a chip at rest. The default surface.
  static BoxDecoration card({
    double radius = SubdockRadius.card,
    Color? color,
    Color? edge,
  }) => BoxDecoration(
    color: color ?? SubdockColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: edge ?? SubdockColors.glassEdge),
  );

  /// An overdue row: the same shape, carrying the danger hue in both halves.
  static BoxDecoration overdue({double radius = SubdockRadius.card}) => card(
    radius: radius,
    color: SubdockColors.dangerTint,
    edge: SubdockColors.dangerEdge,
  );

  /// A card the accent is calling attention to without filling: a free trial,
  /// the prompt after a trip to a provider's page. A 1.5px edge rather than
  /// 1px, which is what the design uses to outrank the plain hairline.
  static BoxDecoration accented({double radius = SubdockRadius.card}) =>
      BoxDecoration(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SubdockColors.accentEdge, width: 1.5),
      );

  /// The same, in the savings hue.
  static BoxDecoration saving({double radius = SubdockRadius.card}) =>
      BoxDecoration(
        color: SubdockColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SubdockColors.savingsEdge, width: 1.5),
      );
}

/// The type scale.
///
/// Two families, and which one a string belongs to is a rule, not a taste:
/// **anything the reader compares against another instance of itself is mono**
/// — dates, amounts, countdowns, instalment counts, times. Everything else is
/// Be Vietnam Pro. Mixing them per-widget instead would let two dates in the
/// same column come out at different widths.
///
/// Be Vietnam Pro is kept even though the copy is English: the app still
/// renders Vietnamese service names, and a face drawn for Vietnamese keeps
/// stacked diacritics (ế, ữ, ợ) off the line above.
/// The one step of extra weight the app carries over the design's CSS.
///
/// The design frames were rendered by a browser on macOS, which paints text
/// visibly heavier than Flutter does on iOS at the same nominal weight. Setting
/// the CSS numbers literally is *correct* and looks wrong: the app comes out
/// thinner than the frames it was drawn from, which reads as a different, more
/// fragile typeface rather than as the same one rendered differently.
///
/// So every weight below is named by the role it plays in the design, and each
/// resolves one step heavier than the CSS says. Changing the look back to a
/// literal transcription is four edits here and nothing else — which is the
/// point of the indirection, because whether this bump is right is a judgement
/// about a rendering pipeline, not a fact about the design.
///
/// Mono stops at [monoBold]: the bundled IBM Plex Mono has no 700, and asking
/// for one gets the 600 back with no visible change.
abstract final class SubdockWeight {
  /// Design `300`. Only the add button's `+`.
  static const FontWeight hairline = FontWeight.w400;

  /// Design `400`. Body, subtitles, captions, labels.
  static const FontWeight regular = FontWeight.w500;

  /// Design `500`. Item names, values, buttons, tab labels.
  static const FontWeight medium = FontWeight.w600;

  /// Design `600`. Screen titles, section labels, the letter in a tile.
  static const FontWeight semibold = FontWeight.w700;

  /// Design `400` in IBM Plex Mono.
  static const FontWeight monoRegular = FontWeight.w500;

  /// Design `500` in IBM Plex Mono.
  static const FontWeight monoMedium = FontWeight.w600;

  /// Design `600` in IBM Plex Mono. Capped: there is no 700 in the bundle.
  static const FontWeight monoBold = FontWeight.w600;
}

abstract final class SubdockText {
  static const String family = 'Be Vietnam Pro';
  static const String mono = 'IBM Plex Mono';

  // ---- titles ----

  /// The big title on a root screen: Upcoming, Money, Savings, Settings.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.15,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.68, // -.02em
    color: SubdockColors.ink,
  );

  /// The title on a screen that is filling something in.
  static const TextStyle editorTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.2,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.56,
    color: SubdockColors.ink,
  );

  /// An item's name at the top of its detail screen, beside the tile.
  static const TextStyle detailTitle = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.25,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.72,
    color: SubdockColors.ink,
  );

  static const TextStyle onboardTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.25,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.68,
    color: SubdockColors.ink,
  );

  // ---- labels ----

  /// The uppercase heading above a card, and the label above a field. One
  /// style for both: the design does not distinguish them.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    height: 1,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: 1.25, // .1em
    color: SubdockColors.inkMuted,
  );

  // ---- rows ----

  /// The left half of a label/value row.
  static const TextStyle rowLabel = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The right half. Heavier and darker, because the value is the answer.
  static const TextStyle rowValue = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.ink,
  );

  /// A plain row that is a destination rather than a fact: a settings entry.
  static const TextStyle rowLink = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.ink,
  );

  /// An item's name in the Upcoming list.
  static const TextStyle itemName = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: SubdockWeight.medium,
    letterSpacing: -0.17,
    color: SubdockColors.ink,
  );

  /// The second line of a list row: the amount, the instalment count.
  static const TextStyle itemSubtitle = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The payment source appended to that second line. A shade quieter, so
  /// "· Momo" never outranks the amount it follows.
  static const TextStyle itemAside = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.4,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkMuted,
  );

  // ---- prose ----

  /// The line under a screen title.
  static const TextStyle summary = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.45,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// A paragraph. Only onboarding and the empty state have one.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.7,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The small print under a card.
  static const TextStyle footnote = TextStyle(
    fontFamily: family,
    fontSize: 13.5,
    height: 1.5,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The smallest print: a provenance line, a caveat about a figure.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.5,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkMuted,
  );

  // ---- controls ----

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1,
    fontWeight: SubdockWeight.medium,
    letterSpacing: -0.17,
  );

  /// A text-only action, the quietest of the three action weights.
  static const TextStyle quietAction = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  static const TextStyle chipSelected = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: Color(0xFFFFFFFF),
  );

  /// The text typed into a field, and a field's placeholder at the same size.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.2,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.ink,
  );

  static const TextStyle tab = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.inkMuted,
  );

  /// The selected tab. Same size and weight, and only the colour changes —
  /// the Glass tab bar has no slab behind the selected mark, so a weight jump
  /// here would make the row of five words visibly ragged.
  static const TextStyle tabActive = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.accent,
  );

  /// The letter inside a service tile.
  static const TextStyle tileLetter = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.semibold,
    color: Color(0xFFFFFFFF),
  );

  // ---- mono ----

  /// The countdown on a list row: `Tomorrow`, `6d`, `Late`.
  static const TextStyle when = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    height: 1.2,
    fontWeight: SubdockWeight.monoMedium,
    letterSpacing: -0.3,
    color: SubdockColors.ink,
  );

  /// The literal date under it.
  static const TextStyle whenDate = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 1.2,
    fontWeight: SubdockWeight.monoRegular,
    letterSpacing: -0.13,
    color: SubdockColors.inkMuted,
  );

  /// A figure in the right-hand column of a card row.
  static const TextStyle monoValue = TextStyle(
    fontFamily: mono,
    fontSize: 15.5,
    height: 1.2,
    fontWeight: SubdockWeight.monoMedium,
    letterSpacing: -0.31,
    color: SubdockColors.ink,
  );

  /// The one big number on the Spending screen.
  static const TextStyle figure = TextStyle(
    fontFamily: mono,
    fontSize: 36,
    height: 1.2,
    fontWeight: SubdockWeight.monoBold,
    letterSpacing: -1.08,
    color: SubdockColors.ink,
  );

  /// The one big number on Savings.
  ///
  /// Light and large rather than heavy and large. It is the only figure in the
  /// app the user is not being asked to pay, and 300 weight is how the design
  /// keeps it from reading as another bill.
  static const TextStyle figureLight = TextStyle(
    fontFamily: family,
    fontSize: 40,
    height: 1.05,
    fontWeight: SubdockWeight.hairline,
    letterSpacing: -1.2,
    color: SubdockColors.savings,
  );

  /// A date sitting inside a sentence.
  static const TextStyle monoInline = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 1.4,
    fontWeight: SubdockWeight.monoRegular,
    letterSpacing: -0.14,
    color: SubdockColors.inkMuted,
  );
}

ThemeData buildSubdockTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    // Transparent, not [SubdockColors.canvas]: the gradient is painted by
    // [GlassBackground] under the whole app, and an opaque scaffold would
    // cover it.
    scaffoldBackgroundColor: const Color(0x00000000),
    fontFamily: SubdockText.family,
    colorScheme: const ColorScheme.light(
      surface: SubdockColors.canvas,
      surfaceContainer: SubdockColors.canvas,
      primary: SubdockColors.accent,
      onPrimary: Color(0xFFFFFFFF),
      outline: SubdockColors.hairline,
      error: SubdockColors.danger,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
