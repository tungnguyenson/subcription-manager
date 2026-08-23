import 'package:flutter/material.dart';

/// The Layered design tokens, transcribed from `Subdock Layered.dc.html`.
///
/// The whole look is built from one idea: a flat grey ground with white cards
/// floating above it. There are no borders around a card and no fills behind a
/// row — depth comes entirely from stacked shadows, which is why
/// [SubdockShadow] carries four layers rather than one and why every card in
/// the app goes through [GroupedCard] instead of drawing its own box.
///
/// The design frames are 390x844 at 1x, so every number here is already in
/// Flutter logical pixels and can be transcribed literally.
abstract final class SubdockColors {
  /// The app background, and the fill of an empty tile sitting on a card.
  static const Color canvas = Color(0xFFECECEB);

  /// Every card, the tab bar, and every field.
  static const Color card = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF14161A);

  /// Secondary text: row labels, subtitles, section headings, idle tabs.
  static const Color inkMuted = Color(0xFF5A5C60);

  /// Secondary text: a list row's second line, the line under a screen title,
  /// a paragraph. `rgba(20,22,26,.66)`. Distinct from [inkMuted], which the
  /// hand-off reserves for labels — a label names a thing, secondary text says
  /// something about it, and they are not the same weight of voice.
  static const Color inkSecondary = Color(0xA814161A);

  /// The rule between rows inside a card, and the hairline around a tile.
  /// `rgba(20,22,26,.09)`.
  static const Color hairline = Color(0x1714161A);

  /// The one accent. Primary actions, the selected chip, the add button.
  static const Color accent = Color(0xFF3767B5);

  /// The accent at the four opacities the design uses, in order of strength:
  /// the current instalment, an inactive toggle track, a chart bar, a spent
  /// instalment's remainder.
  static const Color accentHalf = Color(0x733767B5); // 45%
  static const Color accentTrack = Color(0x2E3767B5); // 18%
  static const Color accentBar = Color(0x293767B5); // 16%
  static const Color accentFaint = Color(0x243767B5); // 14%

  /// Overdue. `oklch(.52 .17 25)` converted to sRGB.
  ///
  /// Its own hue family, deliberately not a tint of the accent: the accent
  /// means "you can act here" and this means "you already didn't".
  static const Color danger = Color(0xFFB63132);

  /// The ground behind a warning banner. Barely pink — a full red panel at the
  /// top of the list would outrank the list.
  static const Color dangerTint = Color(0xFFFDF3F1);

  /// Behind the lock screen on the notification mock-up. Slightly darker than
  /// [canvas] so the notification card still reads as lifted.
  static const Color lockScreen = Color(0xFFE4E4E2);
}

/// Corner radii. The design uses a small fixed set; a value outside it is a
/// mistake rather than a variation.
abstract final class SubdockRadius {
  /// A tile inside a field.
  static const double tile = 8;

  /// A chip, a suggestion tile, a small control.
  static const double chip = 9;

  /// A segmented button, a notification action.
  static const double control = 10;

  /// A field box, and the tile beside a detail title.
  static const double field = 12;

  /// The default for a card and a full-width button. Almost everything.
  static const double card = 13;

  /// The tile on an onboarding row.
  static const double featureTile = 14;

  /// The empty-state placard.
  static const double placard = 22;
}

abstract final class SubdockSpacing {
  /// Left and right margin of every screen body.
  static const double screenH = 18;

  /// Padding inside a card row.
  static const double rowH = 14;
  static const double rowV = 14;

  /// Gap above an uppercase section label, and below it.
  static const double sectionTop = 28;
  static const double sectionBottom = 10;

  /// A field's label to the control under it.
  static const double labelToControl = 8;

  /// Between two blocks of a form.
  static const double formBlock = 24;

  /// The last thing on a screen to the tab bar under it.
  static const double contentBottom = 18;
}

/// The four-layer elevations. Transcribed rather than approximated: the look
/// depends on several nearly-invisible layers summing, and collapsing them to
/// one Material elevation loses it.
abstract final class SubdockShadow {
  /// A card, a primary button, the add button. The deepest thing on screen.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0B14161A),
      offset: Offset(0, 1),
      blurRadius: 1,
    ), // .045
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, 8), blurRadius: 12),
    BoxShadow(color: Color(0x0D14161A), offset: Offset(0, 16), blurRadius: 24),
  ];

  /// A field, a chip, a secondary button. Shallower, so a control never floats
  /// higher than the card it is standing on.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0D14161A), offset: Offset(0, 1), blurRadius: 1),
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, 2), blurRadius: 3),
    BoxShadow(color: Color(0x0914161A), offset: Offset(0, 6), blurRadius: 8),
  ];

  /// The tab bar, thrown upward.
  static const List<BoxShadow> tabBar = [
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, -1), blurRadius: 1),
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, -2), blurRadius: 6),
    BoxShadow(color: Color(0x0A14161A), offset: Offset(0, -10), blurRadius: 20),
  ];

  /// The knob of a toggle.
  static const List<BoxShadow> knob = [
    BoxShadow(color: Color(0x4D14161A), offset: Offset(0, 1), blurRadius: 2),
  ];
}

/// The type scale.
///
/// Two families, and which one a string belongs to is a rule, not a taste:
/// **anything the reader compares against another instance of itself is mono**
/// — dates, amounts, countdowns, instalment counts, times. Everything else is
/// Be Vietnam Pro. Mixing them per-widget instead would let two dates in the
/// same column come out at different widths.
///
/// Be Vietnam Pro is kept from the previous design even though the copy is now
/// English: the app still renders Vietnamese service names, and a face drawn
/// for Vietnamese keeps stacked diacritics (ế, ữ, ợ) off the line above.
abstract final class SubdockText {
  static const String family = 'Be Vietnam Pro';
  static const String mono = 'IBM Plex Mono';

  // ---- titles ----

  /// The big title on a root screen: Upcoming, Money, Settings, History.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.02, // -.03em
    color: SubdockColors.ink,
  );

  /// The title on a screen that is filling something in.
  static const TextStyle editorTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.84,
    color: SubdockColors.ink,
  );

  /// An item's name at the top of its detail screen, beside the tile.
  static const TextStyle detailTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.84,
    color: SubdockColors.ink,
  );

  static const TextStyle onboardTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.02,
    color: SubdockColors.ink,
  );

  // ---- labels ----

  /// The uppercase heading above a card, and the label above a field. One
  /// style for both: the design does not distinguish them.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    height: 1,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.25, // .1em
    color: SubdockColors.inkMuted,
  );

  // ---- rows ----

  /// The left half of a label/value row.
  static const TextStyle rowLabel = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkMuted,
  );

  /// The right half. Heavier and darker, because the value is the answer.
  static const TextStyle rowValue = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w500,
    color: SubdockColors.ink,
  );

  /// A plain row that is a destination rather than a fact: a settings entry.
  static const TextStyle rowLink = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w400,
    color: SubdockColors.ink,
  );

  /// An item's name in the Upcoming list.
  static const TextStyle itemName = TextStyle(
    fontFamily: family,
    fontSize: 16.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.33,
    color: SubdockColors.ink,
  );

  /// The second line of a list row: the amount, the instalment count.
  static const TextStyle itemSubtitle = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkSecondary,
  );

  // ---- prose ----

  /// The line under a screen title.
  static const TextStyle summary = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkSecondary,
  );

  /// A paragraph. Only onboarding and the empty state have one.
  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.7,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkSecondary,
  );

  /// The small print under a card.
  static const TextStyle footnote = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkSecondary,
  );

  // ---- controls ----

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 15.5,
    height: 1,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.155,
  );

  /// A text-only action, the quietest of the three action weights.
  static const TextStyle quietAction = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    height: 1,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkMuted,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w400,
    color: SubdockColors.inkMuted,
  );

  static const TextStyle chipSelected = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: FontWeight.w500,
    color: SubdockColors.card,
  );

  /// The text typed into a field, and a field's placeholder at the same size.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w400,
    color: SubdockColors.ink,
  );

  static const TextStyle tab = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w500,
    color: SubdockColors.inkMuted,
  );

  /// The selected tab. Heavier and in the accent, so the state survives being
  /// read out of the corner of the eye — 11px of colour alone does not.
  static const TextStyle tabActive = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w600,
    color: SubdockColors.accent,
  );

  /// The letter inside a service tile, at each of the three tile sizes.
  static const TextStyle tileLetter = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1,
    fontWeight: FontWeight.w600,
    color: SubdockColors.inkMuted,
  );

  // ---- mono ----

  /// The countdown on a list row: `Tomorrow`, `6 days`, `Overdue`.
  static const TextStyle when = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.14,
    color: SubdockColors.ink,
  );

  /// The literal date under it.
  static const TextStyle whenDate = TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.13,
    color: SubdockColors.inkMuted,
  );

  /// A figure in the right-hand column of a card row.
  static const TextStyle monoValue = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.15,
    color: SubdockColors.ink,
  );

  /// The one big number on the Money screen.
  static const TextStyle figure = TextStyle(
    fontFamily: mono,
    fontSize: 34,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.02,
    color: SubdockColors.ink,
  );

  /// A date sitting inside a sentence.
  static const TextStyle monoInline = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.14,
    color: SubdockColors.inkSecondary,
  );
}

ThemeData buildSubdockTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SubdockColors.canvas,
    fontFamily: SubdockText.family,
    colorScheme: const ColorScheme.light(
      surface: SubdockColors.canvas,
      surfaceContainer: SubdockColors.card,
      primary: SubdockColors.accent,
      onPrimary: SubdockColors.card,
      outline: SubdockColors.hairline,
      error: SubdockColors.danger,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
