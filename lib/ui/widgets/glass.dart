import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';

/// The gradient ground, painted once under the whole app.
///
/// Once, not per screen. Every surface above it is translucent, so a second
/// gradient started at a route boundary would show up as a seam running across
/// a card that straddles it — and during a push transition the two would slide
/// past each other.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Its own dependency, not its parent's. `_push` bakes this widget into a
    // route's cached page, so nothing above it will ever hand it a new child;
    // the gradient repaints on a theme change only because of this line.
    SubdockTheme.watch(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: SubdockGradients.page),
      child: child,
    );
  }
}

/// A real frosted-glass layer: it blurs whatever is behind it.
///
/// Used in exactly two places — the tab bar and the permission sheet — and the
/// restraint is deliberate, not a shortcut. A [BackdropFilter] forces a
/// `saveLayer` for every instance, and the Upcoming list can hold a dozen
/// cards at once; blurring each one costs real frames on Android for no
/// visible gain, because [SubdockGradients.page] has no detail in it to blur.
/// A blur only earns its cost where something with edges is sliding
/// underneath, which is what these two have and a card sitting on the ground
/// does not.
///
/// Everything else uses [SubdockSurface] — translucent fill plus hairline —
/// which is what actually carries the look.
class BlurLayer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  /// CSS `blur(14px)` is a Gaussian standard deviation of 14px, which is what
  /// `sigma` means here too.
  final double sigma;

  const BlurLayer({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.sigma = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}

/// The two-line right-hand column of a list row: a countdown over a date.
///
/// Its own widget because the pair has a rule the rest of the row does not:
/// the countdown is the thing being compared down the column and so is always
/// mono and always the same width, and the literal date under it is always
/// quieter. Built per-screen instead, one list ends up with a bold date and a
/// grey countdown and the column stops scanning.
class DueStack extends StatelessWidget {
  final String countdown;
  final String? date;

  /// Overdue rows put the countdown in a filled danger pill instead of plain
  /// text. That is the one state in the app that gets a fill on a list row.
  final bool urgent;

  final Color? color;

  const DueStack({
    super.key,
    required this.countdown,
    this.date,
    this.urgent = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final label = urgent
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: SubdockColors.danger,
              borderRadius: BorderRadius.circular(SubdockRadius.chip),
            ),
            child: Text(
              countdown,
              style: SubdockText.when.copyWith(
                fontFamily: SubdockText.family,
                fontSize: 14,
                color: SubdockColors.onDanger,
              ),
            ),
          )
        : Text(
            countdown,
            style: color == null
                ? SubdockText.when
                : SubdockText.when.copyWith(color: color),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        if (date != null) ...[
          const SizedBox(height: 3),
          Text(date!, style: SubdockText.whenDate),
        ],
      ],
    );
  }
}
