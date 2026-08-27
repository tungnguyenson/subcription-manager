import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/tab_mark.dart';

import 'package:subdock/i18n.dart';

/// The four top-level destinations.
///
/// Four, not three. [savings] joined the bar in the Glass design and it is the
/// one addition that had to be a tab rather than a row on Money: it is the only
/// screen in the app the user opens *without* a due date pushing them there, so
/// burying it one level down means it is never opened at all.
///
/// Everything else — an item, the service list, the payment sources, the
/// history — is still reached by opening a row.
enum ShellTab { upcoming, money, savings, settings }

class AppShell extends StatelessWidget {
  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback? onAdd;
  final Widget child;

  const AppShell({
    super.key,
    required this.current,
    required this.onSelect,
    required this.child,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return GlassBackground(
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        // The bar is translucent and blurs what is behind it, so the list has
        // to run underneath it rather than stop above it. `extendBody` is what
        // gives it something to blur; without it the bar frosts a flat gradient
        // and the effect is invisible.
        extendBody: true,
        body: SafeArea(bottom: false, child: child),
        bottomNavigationBar: _TabBar(
          current: current,
          onSelect: onSelect,
          onAdd: onAdd,
        ),
      ),
    );
  }
}

/// Five slots: four destinations around one add button.
///
/// Every destination is named in words and marked with an icon. The words
/// identify the tab — four short nouns are read faster than four marks that
/// have to be learned first. The icon carries the selected state, which a 13px
/// word cannot do on its own.
class _TabBar extends StatelessWidget {
  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback? onAdd;

  const _TabBar({required this.current, required this.onSelect, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return BlurLayer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SubdockColors.tabBar,
          // `0 -1px 0 rgba(255,255,255,.7)` in the design: a bright hairline
          // along the top edge, not a shadow. It is the same trick every other
          // Glass surface uses, turned on its side.
          border: Border(top: BorderSide(color: SubdockColors.tabBarEdge)),
        ),
        child: SafeArea(
          top: false,
          // The mock-up reserves 14px under the bar. On a phone with a home
          // indicator the system inset is larger and wins; on one without,
          // this keeps the labels off the bottom edge.
          minimum: const EdgeInsets.only(bottom: 14),
          child: SizedBox(
            height: 60,
            child: Padding(
              // Keeps the outer two labels off the screen edge. Without it
              // `Upcoming`, the longest of the four, all but touches it: at
              // 13px it is 71pt wide inside a 78pt fifth of the bar.
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _TabButton(
                    label: S.t.upcomingTitle,
                    glyph: TabGlyph.upcoming,
                    active: current == ShellTab.upcoming,
                    onTap: () => onSelect(ShellTab.upcoming),
                  ),
                  _TabButton(
                    label: S.t.spendingTitle,
                    glyph: TabGlyph.money,
                    active: current == ShellTab.money,
                    onTap: () => onSelect(ShellTab.money),
                  ),
                  // A fixed slot rather than a fifth of the bar. The button is
                  // 52pt and needs no more; the width an equal fifth would have
                  // given it is width the four labels beside it do need.
                  SizedBox(
                    width: 68,
                    child: Center(child: _AddButton(onTap: onAdd)),
                  ),
                  _TabButton(
                    label: S.t.savingsTitle,
                    glyph: TabGlyph.savings,
                    active: current == ShellTab.savings,
                    onTap: () => onSelect(ShellTab.savings),
                  ),
                  _TabButton(
                    label: S.t.settingsTitle,
                    glyph: TabGlyph.settings,
                    active: current == ShellTab.settings,
                    onTap: () => onSelect(ShellTab.settings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final TabGlyph glyph;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.glyph,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = active ? TabMark.tint(glyph) : SubdockColors.inkMuted;

    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TabMark(glyph: glyph, active: active, size: 23),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (active ? SubdockText.tabActive : SubdockText.tab)
                    .copyWith(color: tint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one place in the app where the accent is a shape rather than a fill on
/// something the user already asked for.
///
/// 56px and overlapping the bar's top edge in the design, which is what makes
/// it read as an action rather than as a fifth destination. It is kept inside
/// the bar's height here so it cannot be clipped by the blur layer above it —
/// a circle drawn half outside a `ClipRRect` loses its top half.
class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    // A tooltip rather than a bare Semantics label. It carries the same name
    // to VoiceOver, and it is the one affordance on this bar with no visible
    // word beside it, so a long press naming it is worth having.
    return Tooltip(
      message: S.t.addAnItem,
      child: Material(
        color: SubdockColors.accent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(
                '+',
                style: TextStyle(
                  fontFamily: SubdockText.family,
                  fontSize: 34,
                  height: 1,
                  fontWeight: SubdockWeight.hairline,
                  color: SubdockColors.onAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
