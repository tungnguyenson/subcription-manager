import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// One line on the fake lock screen.
class PreviewNotification {
  final String name;
  final String iconKey;
  final String title;
  final String body;
  final String stamp;

  const PreviewNotification({
    required this.name,
    required this.iconKey,
    required this.title,
    required this.body,
    required this.stamp,
  });
}

/// The top of a phone's lock screen, with the app's own notifications
/// arriving on it.
///
/// A mock-up rather than a screenshot, for the reason the marquee is drawn
/// rather than photographed: the words in it are translated, the icons are the
/// same ones the real list draws, and a bitmap would go stale the first time
/// either changed.
///
/// It is cut off at the bottom on purpose — the card holds the top of a
/// screen, not a whole one. A complete phone drawn inside a card reads as a
/// picture of a different device; a cropped one reads as *your* screen.
class LockPreview extends StatefulWidget {
  final List<PreviewNotification> notifications;

  /// The clock in the corner. Fixed text, not the real time: a live clock
  /// here would be the one element of the mock-up claiming to be real.
  final String clock;

  const LockPreview({
    super.key,
    required this.notifications,
    this.clock = '09:41',
  });

  @override
  State<LockPreview> createState() => _LockPreviewState();
}

class _LockPreviewState extends State<LockPreview>
    with SingleTickerProviderStateMixin {
  /// One turn of the loop. Long enough that a notification stands still and
  /// legible for about three seconds, which is how long it takes to read one.
  static const Duration _period = Duration(seconds: 7);

  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: _period,
  );

  /// The moment in the loop where every notification is on screen and still.
  ///
  /// Where the animation is switched off -- Reduce Motion, or a test -- this is
  /// what is shown. Not zero: at zero nothing has arrived yet and the card
  /// would be an empty lock screen, which is the one frame of the loop that
  /// says nothing about what the app does.
  static const double _resting = 0.3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _run
        ..stop()
        ..value = _resting;
    } else if (!_run.isAnimating) {
      _run.repeat();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // A wash that fades downwards, so the card has no bottom edge and the
        // lock screen reads as continuing past the crop.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SubdockColors.banner, SubdockColors.banner.withAlpha(0)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: SubdockColors.glassEdge)),
      ),
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 4),
      child: Column(
        children: [
          _StatusRow(clock: widget.clock),
          const SizedBox(height: 14),
          for (var i = 0; i < widget.notifications.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _Arriving(
              run: _run,
              // Staggered so they land one after another, the way a phone
              // actually delivers them. Simultaneous arrival reads as a
              // screen redrawing rather than as news coming in.
              delay: i * 0.14,
              child: _NotificationCard(item: widget.notifications[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fades and drops one notification in, holds it, then takes it away again.
class _Arriving extends StatelessWidget {
  final Animation<double> run;
  final double delay;
  final Widget child;

  const _Arriving({
    required this.run,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: run,
      builder: (context, child) {
        // Wrapped rather than clamped: a delay past the end of the loop simply
        // starts this one earlier in the next turn, which is what a repeating
        // stagger has to do to stay evenly spaced.
        final phase = (run.value - delay) % 1.0;
        final appear = Curves.easeOutCubic.transform(
          (phase / 0.12).clamp(0.0, 1.0),
        );
        final leave = Curves.easeInCubic.transform(
          ((phase - 0.62) / 0.14).clamp(0.0, 1.0),
        );
        final shown = appear * (1 - leave);

        return Opacity(
          opacity: shown,
          child: Transform.translate(
            offset: Offset(0, -16 * (1 - appear) - 10 * leave),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final PreviewNotification item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Opaque, unlike every card in the app: this one is standing in for
        // the operating system's own surface, which is not made of glass.
        color: SubdockColors.solid,
        borderRadius: BorderRadius.circular(14),
        // No drop shadow, though a real phone draws one. On a ground this
        // close in lightness to the card, a shadow reads as a second grey
        // rectangle slid out from under the first rather than as lift -- the
        // exact failure trap 12 describes, and the reason nothing else in
        // this app casts one either. The hairline does the whole job.
        border: Border.all(color: SubdockColors.glassEdgeSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Row(
        children: [
          ServiceTile(
            item.name,
            iconName: item.iconKey,
            size: 26,
            radius: 8,
            fontSize: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.itemName.copyWith(
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SubdockText.itemSubtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(item.stamp, style: SubdockText.whenDate.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String clock;

  const _StatusRow({required this.clock});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(clock, style: SubdockText.whenDate.copyWith(fontSize: 11.5)),
          CustomPaint(
            size: const Size(30, 11),
            // Drawn rather than pulled from an icon font, like every other
            // mark in this app — and here there is a second reason: the
            // MaterialIcons font is not loaded under `flutter test`, so a
            // status bar built from `Icon` would be two empty squares in
            // every screenshot the repo takes.
            painter: _StatusPainter(SubdockColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  final Color colour;

  const _StatusPainter(this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;

    // Signal: four bars climbing left to right.
    for (var i = 0; i < 4; i++) {
      final height = 3.0 + i * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 3.5, size.height - height, 2.4, height),
          const Radius.circular(1),
        ),
        paint,
      );
    }

    // Battery: a body two thirds full, plus the cap on its right.
    final body = Rect.fromLTWH(size.width - 15, 1, 13, size.height - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2.6)),
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.left + 2, body.top + 2, 7, body.height - 4),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(body.right + 1, body.top + 3.2, 1.4, body.height - 6.4),
        const Radius.circular(0.7),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StatusPainter old) => old.colour != colour;
}
