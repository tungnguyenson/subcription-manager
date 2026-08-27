import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'package:subdock/domain/fx.dart';
import 'package:subdock/i18n.dart';

import 'theme/palette.dart';

export 'theme/palette.dart';

/// The palette every token below reads from.
///
/// A mutable global rather than something threaded through `BuildContext`,
/// and that is a deliberate trade. Roughly five hundred call sites say
/// `SubdockColors.ink` or `SubdockText.body`, and a good third of them are
/// inside static helpers — [SubdockSurface.card], `TabMark.tint`, a presenter
/// building a row — that have no context to thread. Making the tokens
/// context-bound would mean carrying a `BuildContext` into all of them.
///
/// The cost of the global is that setting it does **not** by itself repaint
/// anything, and Flutter will not repaint a pushed route just because an
/// ancestor rebuilt. That is what [SubdockTheme] is for, and why every screen
/// starts its `build` with `SubdockTheme.watch(context)`.
SubdockPalette _active = SubdockPalette.light;

/// Publishes [palette] to every token, and repaints the screens that asked.
///
/// Two jobs, and both are needed. Setting `_active` is what makes
/// `SubdockColors.ink` return the dark ink; the [InheritedWidget] underneath
/// is what makes an already-pushed route notice.
///
/// The second half is the part that is easy to get wrong. A route's page is
/// built once and cached by `_ModalScopeState`, so rebuilding this widget
/// hands the Navigator the same child instance and Flutter short-circuits the
/// whole subtree. An inherited dependency is the one channel that reaches
/// inside a cached route — but only the widgets that actually registered one.
/// Hence the rule: **a screen, sheet or dialog calls
/// [SubdockTheme.watch] at the top of its `build`.** A screen that forgets it
/// keeps the old palette until something else happens to rebuild it, which on
/// a system-driven theme change is a half-dark screen.
class SubdockTheme extends StatelessWidget {
  final SubdockPalette palette;

  /// The language, carried by the same scope as the colours.
  ///
  /// One scope rather than three, and that is the whole point. All three
  /// globals have the same repaint problem and the same fix, and a second
  /// inherited widget would mean a second line every screen has to remember. A
  /// screen that already follows the palette rule follows these for free; a
  /// screen that forgets it fails at all three at once, which is far easier to
  /// spot than a screen that recoloured but did not retranslate.
  final AppLocale locale;

  /// The currency the combined totals are stated in. Published here for the
  /// same reason [locale] is: `MoneyFormat` and every presenter read it as a
  /// global, so a change to it has to reach inside routes that are already
  /// built.
  final String currency;

  /// Every currency the user declared, [currency] among them.
  ///
  /// Optional, and null means "just the one". Almost every caller is a widget
  /// test putting a single screen under a bare scope, and making those name a
  /// list to say the thing they already said with [currency] would be noise in
  /// a hundred places to serve two.
  final List<String>? currencies;

  final Widget child;

  const SubdockTheme({
    super.key,
    required this.palette,
    this.locale = AppLocale.en,
    this.currency = Fx.defaultBase,
    this.currencies,
    required this.child,
  });

  /// The palette in force. Falls back to whatever is active when there is no
  /// scope above — a widget test that builds one screen under a bare
  /// `MaterialApp` is the normal case for that, and it should not have to
  /// know this class exists.
  static SubdockPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChromeScope>()?.palette ??
      _active;

  /// Registers this build as depending on the palette, the language *and* the
  /// currency. Call it first thing in the `build` of anything that is the root
  /// of a route.
  static void watch(BuildContext context) => of(context);

  @override
  Widget build(BuildContext context) {
    _active = palette;
    S.publish(locale);
    Fx.publishBase(currency);
    final declared = currencies ?? [currency];
    Fx.publishDeclared(declared);
    return _ChromeScope(
      palette: palette,
      locale: locale,
      currency: currency,
      currencies: declared,
      child: child,
    );
  }
}

class _ChromeScope extends InheritedWidget {
  final SubdockPalette palette;
  final AppLocale locale;
  final String currency;
  final List<String> currencies;

  const _ChromeScope({
    required this.palette,
    required this.locale,
    required this.currency,
    required this.currencies,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ChromeScope old) =>
      old.palette != palette ||
      old.locale != locale ||
      old.currency != currency ||
      !_same(old.currencies, currencies);

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The colour tokens.
///
/// The Glass look is one idea: **the ground carries the colour and a surface
/// is a hole cut in frosted glass.** There is a four-stop gradient behind
/// everything, and a card is a translucent wash with a hairline around it.
/// Nothing casts a drop shadow — [SubdockShadow] is empty for cards on
/// purpose, because the hairline *is* the whole separation.
///
/// Two consequences worth knowing before editing anything here:
///
/// 1. A card drawn with a drop shadow instead of the hairline disappears. In
///    light the gradient and the card are within a few percent of the same
///    lightness; in dark there is nothing left for a shadow to darken.
/// 2. An opaque card breaks it in the other direction: it reads as a sheet of
///    paper laid on the gradient rather than as part of it. Every surface here
///    is translucent on purpose, which is why the fills carry an alpha and are
///    not hex triples.
///
/// The values live in [SubdockPalette]; this class is the reader. Adding a
/// colour means adding a field there — in **both** variants — and a getter
/// here.
///
/// The design frames are 390x844 at 1x, so every number is already in Flutter
/// logical pixels and can be transcribed literally.
abstract final class SubdockColors {
  static Color get canvas => _active.canvas;
  static Color get card => _active.card;
  static Color get glassEdge => _active.glassEdge;
  static Color get glassEdgeSm => _active.glassEdgeSm;
  static Color get solid => _active.solid;
  static Color get sheetEdge => _active.sheetEdge;
  static Color get scrim => _active.scrim;
  static Color get tabBar => _active.tabBar;
  static Color get tabBarEdge => _active.tabBarEdge;
  static Color get banner => _active.banner;
  static Color get thumb => _active.thumb;
  static Color get thumbEdge => _active.thumbEdge;
  static Color get segmentSelected => _active.segmentSelected;
  static Color get knob => _active.knob;
  static Color get lockScreen => _active.lockScreen;

  static Color get ink => _active.ink;
  static Color get inkSecondary => _active.inkSecondary;
  static Color get inkMuted => _active.inkMuted;
  static Color get hairline => _active.hairline;

  static Color get accent => _active.accent;
  static Color get onAccent => _active.onAccent;
  static Color get onAccentSoft => _active.onAccentSoft;
  static Color get accentEdge => _active.accentEdge;
  static Color get accentSoft => _active.accentSoft;
  static Color get accentFaint => _active.accentFaint;
  static Color get chartAhead => _active.chartAhead;
  static Color get chartAheadSelected => _active.chartAheadSelected;

  static Color get danger => _active.danger;
  static Color get onDanger => _active.onDanger;
  static Color get dangerTint => _active.dangerTint;
  static Color get dangerEdge => _active.dangerEdge;

  static Color get savings => _active.savings;
  static Color get onSavings => _active.onSavings;
  static Color get savingsEdge => _active.savingsEdge;
  static Color get savingsFaint => _active.savingsFaint;

  /// Kept for the few call sites that predate the Glass tokens. [accentEdge]
  /// and [accentSoft] are the named equivalents; prefer those.
  static Color get accentHalf => accentEdge;
  static Color get accentTrack => accentSoft;
  static Color get accentBar => accentSoft;

  /// The letter inside a service tile, which does not follow the theme: it
  /// sits on the provider's brand tint, and that tint does not know what
  /// theme it is in.
  static const Color onBrand = Color(0xFFFFFFFF);
}

/// The gradients. There is one, and everything sits on it.
abstract final class SubdockGradients {
  /// The app ground. See [SubdockPalette.page] for why it has four stops.
  static LinearGradient get page => _active.page;
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
  ///
  /// One number for every gap on the add form, and the form adds nothing on
  /// top of it. It used to be 26 with ad-hoc margins layered over it, which
  /// made the real gaps 14, 26 and 40 depending on which two blocks you were
  /// looking at -- a rhythm the reader feels as "this belongs together" and
  /// "this does not", saying things the form did not mean.
  static const double formBlock = 22;

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
/// Three of the four are empty in both variants, and that is the Glass theme
/// rather than an omission: `cardLg` and `cardSm` are a border, which lives on
/// the decoration and not here. See [SubdockSurface].
///
/// What is left are the places where something genuinely floats over content
/// rather than sitting in the same plane as it — and **all of them are empty
/// in dark.** A drop shadow needs something to darken, and a dark ground has
/// nothing. Their job passes to [SubdockPalette.sheetEdge] and to the
/// hairlines the surfaces already carry.
abstract final class SubdockShadow {
  /// A card, a field, a button. Nothing — the hairline does this job.
  static const List<BoxShadow> card = [];
  static const List<BoxShadow> soft = [];
  static const List<BoxShadow> tabBar = [];

  /// The sheet that rises over the list —
  /// `0 -20px 44px rgba(20,22,26,.22)`.
  static List<BoxShadow> get sheet => _active.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x3814161A),
            offset: Offset(0, -20),
            blurRadius: 44,
          ),
        ];

  /// The toast — `0 10px 24px rgba(20,22,26,.28)`.
  static List<BoxShadow> get toast => _active.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x4714161A),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ];

  /// The knob of a toggle. The one shadow the light design keeps on a control,
  /// because the knob has to read as a solid object on a tinted track. In dark
  /// the knob is near-white on a translucent track and already does.
  static List<BoxShadow> get knob => _active.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x4D14161A),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
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
  ///
  /// The hairline weakens on a small surface, which is the design's `cardSm`.
  /// Read off the radius rather than asked for: every small surface in the app
  /// is already the one that takes [SubdockRadius.chip], so a second parameter
  /// would only be a way to get the pair wrong.
  static BoxDecoration card({
    double radius = SubdockRadius.card,
    Color? color,
    Color? edge,
  }) => BoxDecoration(
    color: color ?? SubdockColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color:
          edge ??
          (radius <= SubdockRadius.chip
              ? SubdockColors.glassEdgeSm
              : SubdockColors.glassEdge),
    ),
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

  /// A sheet that rises over the list.
  ///
  /// Opaque, unlike every other surface here: the list is sliding underneath,
  /// and a translucent sheet would let the row the user just acted on show
  /// through the sentence about it.
  ///
  /// The separation swaps hands between the variants. In light it is the drop
  /// shadow; in dark that shadow has nothing to darken, so a hairline along
  /// the top edge takes over. The border is dropped rather than drawn
  /// transparent where it is not wanted, because a 1px transparent side still
  /// takes 1px out of the sheet's inside.
  static BoxDecoration sheet({double radius = SubdockRadius.sheet}) =>
      BoxDecoration(
        color: SubdockColors.solid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        border: SubdockColors.sheetEdge.a == 0
            ? null
            : Border(top: BorderSide(color: SubdockColors.sheetEdge)),
        boxShadow: SubdockShadow.sheet,
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
  static TextStyle get screenTitle => TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.15,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.68, // -.02em
    color: SubdockColors.ink,
  );

  /// The title on a screen that is filling something in.
  static TextStyle get editorTitle => TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.2,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.56,
    color: SubdockColors.ink,
  );

  /// An item's name at the top of its detail screen, beside the tile.
  static TextStyle get detailTitle => TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.25,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: -0.72,
    color: SubdockColors.ink,
  );

  static TextStyle get onboardTitle => TextStyle(
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
  static TextStyle get sectionLabel => TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    height: 1,
    fontWeight: SubdockWeight.semibold,
    letterSpacing: 1.25, // .1em
    color: SubdockColors.inkMuted,
  );

  // ---- rows ----

  /// The left half of a label/value row.
  static TextStyle get rowLabel => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The right half. Heavier and darker, because the value is the answer.
  static TextStyle get rowValue => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.ink,
  );

  /// A plain row that is a destination rather than a fact: a settings entry.
  static TextStyle get rowLink => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.ink,
  );

  /// An item's name in the Upcoming list.
  static TextStyle get itemName => TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: SubdockWeight.medium,
    letterSpacing: -0.17,
    color: SubdockColors.ink,
  );

  /// The second line of a list row: the amount, the instalment count.
  static TextStyle get itemSubtitle => TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.4,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The payment source appended to that second line. A shade quieter, so
  /// "· Momo" never outranks the amount it follows.
  static TextStyle get itemAside => TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.4,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkMuted,
  );

  // ---- prose ----

  /// The line under a screen title.
  static TextStyle get summary => TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.45,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// A paragraph. Only onboarding and the empty state have one.
  static TextStyle get body => TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.7,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The small print under a card.
  static TextStyle get footnote => TextStyle(
    fontFamily: family,
    fontSize: 13.5,
    height: 1.5,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  /// The smallest print: a provenance line, a caveat about a figure.
  static TextStyle get caption => TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.5,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkMuted,
  );

  // ---- controls ----

  static TextStyle get button => TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1,
    fontWeight: SubdockWeight.medium,
    letterSpacing: -0.17,
  );

  /// A text-only action, the quietest of the three action weights.
  static TextStyle get quietAction => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  static TextStyle get chip => TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.inkSecondary,
  );

  static TextStyle get chipSelected => TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.onAccent,
  );

  /// The text typed into a field, and a field's placeholder at the same size.
  static TextStyle get fieldValue => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.2,
    fontWeight: SubdockWeight.regular,
    color: SubdockColors.ink,
  );

  static TextStyle get tab => TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.inkMuted,
  );

  /// The selected tab. Same size and weight, and only the colour changes —
  /// the Glass tab bar has no slab behind the selected mark, so a weight jump
  /// here would make the row of five words visibly ragged.
  static TextStyle get tabActive => TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1,
    fontWeight: SubdockWeight.medium,
    color: SubdockColors.accent,
  );

  /// The letter inside a service tile.
  static TextStyle get tileLetter => TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: SubdockWeight.semibold,
    color: SubdockColors.onBrand,
  );

  // ---- mono ----

  /// The countdown on a list row: `Tomorrow`, `6d`, `Late`.
  static TextStyle get when => TextStyle(
    fontFamily: mono,
    fontSize: 15,
    height: 1.2,
    fontWeight: SubdockWeight.monoMedium,
    letterSpacing: -0.3,
    color: SubdockColors.ink,
  );

  /// The literal date under it.
  static TextStyle get whenDate => TextStyle(
    fontFamily: mono,
    fontSize: 13,
    height: 1.2,
    fontWeight: SubdockWeight.monoRegular,
    letterSpacing: -0.13,
    color: SubdockColors.inkMuted,
  );

  /// A figure in the right-hand column of a card row.
  static TextStyle get monoValue => TextStyle(
    fontFamily: mono,
    fontSize: 15.5,
    height: 1.2,
    fontWeight: SubdockWeight.monoMedium,
    letterSpacing: -0.31,
    color: SubdockColors.ink,
  );

  /// The one big number on the Spending screen.
  static TextStyle get figure => TextStyle(
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
  static TextStyle get figureLight => TextStyle(
    fontFamily: family,
    fontSize: 40,
    height: 1.05,
    fontWeight: SubdockWeight.hairline,
    letterSpacing: -1.2,
    color: SubdockColors.savings,
  );

  /// A date sitting inside a sentence.
  static TextStyle get monoInline => TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 1.4,
    fontWeight: SubdockWeight.monoRegular,
    letterSpacing: -0.14,
    color: SubdockColors.inkMuted,
  );
}

/// The Material theme, which the app barely uses.
///
/// Almost everything is drawn from the tokens above rather than from
/// `Theme.of`. What is left here is the handful of things Flutter reaches for
/// on its own: the text selection handles, a platform date picker, the ripple.
///
/// [palette]'s brightness is the one thing the framework genuinely needs told
/// — a `CupertinoDatePicker` and the on-screen keyboard both read it, and
/// neither looks at [SubdockColors]. It defaults to
/// [SubdockPalette.light] so a widget test that only wants *a* theme does not
/// have to name one.
ThemeData buildSubdockTheme([SubdockPalette palette = SubdockPalette.light]) {
  final dark = palette.isDark;
  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    // Transparent, not [SubdockPalette.canvas]: the gradient is painted by
    // [GlassBackground] under the whole app, and an opaque scaffold would
    // cover it.
    scaffoldBackgroundColor: const Color(0x00000000),
    fontFamily: SubdockText.family,
    colorScheme: ColorScheme(
      brightness: palette.brightness,
      surface: palette.canvas,
      onSurface: palette.ink,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      outline: palette.hairline,
      error: palette.danger,
      onError: palette.onDanger,
    ),
    // Named explicitly because ColorScheme derives it from `surface`, and the
    // derivation lands on a container that is lighter than the sheet it would
    // sit in.
    canvasColor: palette.canvas,
    splashFactory: dark ? InkRipple.splashFactory : InkSparkle.splashFactory,
  );
}

/// What the status bar and the Android navigation bar should draw over the
/// gradient.
///
/// `dark` here means dark *content* on a light ground, which is what the light
/// variant needs, and it is the value the app used to pin at startup back when
/// there was only one look.
SystemUiOverlayStyle subdockOverlayStyle(SubdockPalette palette) =>
    palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
