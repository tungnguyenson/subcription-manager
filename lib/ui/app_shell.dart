import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/tab_mark.dart';

/// The three top-level destinations.
///
/// Three, not five. Everything else in the app is reached by opening a row,
/// which means the bar never has to carry a destination the user has no
/// standing reason to visit.
enum ShellTab { upcoming, money, settings }

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
    return Scaffold(
      backgroundColor: SubdockColors.canvas,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _TabBar(
        current: current,
        onSelect: onSelect,
        onAdd: onAdd,
      ),
    );
  }
}

/// Every destination is named in words and marked with an icon.
///
/// The words identify the tab — three short nouns are read faster than three
/// marks that have to be learned first. The icon carries the selected state,
/// which a 12px word cannot do on its own: the selected one is filled, sits in
/// a tinted slab and takes the accent, and the other two are outlined and
/// grey.
class _TabBar extends StatelessWidget {
  final ShellTab current;
  final ValueChanged<ShellTab> onSelect;
  final VoidCallback? onAdd;

  const _TabBar({required this.current, required this.onSelect, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SubdockColors.card,
        boxShadow: SubdockShadow.tabBar,
      ),
      child: SafeArea(
        top: false,
        // The mock-up reserves 14px under the bar. On a phone with a home
        // indicator the system inset is larger and wins; on one without, this
        // keeps the labels off the bottom edge.
        minimum: const EdgeInsets.only(bottom: 14),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _TabButton(
                label: 'Upcoming',
                glyph: TabGlyph.upcoming,
                active: current == ShellTab.upcoming,
                onTap: () => onSelect(ShellTab.upcoming),
              ),
              _TabButton(
                label: 'Money',
                glyph: TabGlyph.money,
                active: current == ShellTab.money,
                onTap: () => onSelect(ShellTab.money),
              ),
              Expanded(
                child: Center(child: _AddButton(onTap: onAdd)),
              ),
              _TabButton(
                label: 'Settings',
                glyph: TabGlyph.settings,
                active: current == ShellTab.settings,
                onTap: () => onSelect(ShellTab.settings),
              ),
            ],
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
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The selected mark sits in a tinted, accent-outlined slab. The
              // unselected ones get no container at all: three empty outlines
              // would compete with the one that means something.
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: 40,
                height: 27,
                decoration: BoxDecoration(
                  color: active
                      ? SubdockColors.accentFaint
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(SubdockRadius.control),
                  border: Border.all(
                    color: active
                        ? SubdockColors.accentHalf
                        : const Color(0x00000000),
                  ),
                ),
                alignment: Alignment.center,
                child: TabMark(glyph: glyph, active: active, size: 19),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: active ? SubdockText.tabActive : SubdockText.tab,
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
class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    // A tooltip rather than a bare Semantics label. It carries the same name
    // to VoiceOver, and it is the one affordance on this bar with no visible
    // word beside it, so a long press naming it is worth having.
    return Tooltip(
      message: 'Add an item',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: SubdockShadow.card,
        ),
        child: Material(
          color: SubdockColors.accent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    fontFamily: SubdockText.family,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    color: SubdockColors.card,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
