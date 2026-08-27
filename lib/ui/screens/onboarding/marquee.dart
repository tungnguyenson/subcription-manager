import 'package:flutter/material.dart';

import 'package:subdock/ui/screens/onboarding/sample_items.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The row of sample items sliding past, under the first card's title.
///
/// One long row that scrolls forever rather than a list the user can drag.
/// This is a picture of what the app holds, not a control: a scrollable strip
/// on an onboarding card invites a drag, and a drag that leads nowhere is a
/// dead end on the first screen. It ignores pointers entirely.
class SampleMarquee extends StatefulWidget {
  /// One pass over the real list. The strip is drawn twice end to end and
  /// translated by half its width, so the seam lands where the two copies meet
  /// and never appears.
  final List<SampleItem> items;

  final double height;

  /// How long one full pass takes. Slow on purpose: fast enough to read as
  /// motion within a second of the screen appearing, slow enough that a name
  /// can be read as it goes by.
  final Duration period;

  const SampleMarquee({
    super.key,
    required this.items,
    this.height = 52,
    this.period = const Duration(seconds: 26),
  });

  @override
  State<SampleMarquee> createState() => _SampleMarqueeState();
}

class _SampleMarqueeState extends State<SampleMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  /// Started here rather than in `initState`, because whether it should run at
  /// all is a question about the reader: a phone with Reduce Motion turned on
  /// is asking for nothing to move on its own, and an endless strip sliding
  /// past is exactly what that setting is for. Held still at the start of the
  /// loop instead, which is a legible row of items rather than a blank.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _run
        ..stop()
        ..value = 0;
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
    final strip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in [...widget.items, ...widget.items])
          // Wider than it was when each chip had a border to end it: with the
          // box gone, the gap is the only thing separating one item's date
          // from the next item's icon.
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: _SampleChip(item: item),
          ),
      ],
    );

    return SizedBox(
      height: widget.height,
      child: IgnorePointer(
        // The fade at both ends is what makes the strip read as continuing
        // past the card rather than being cut off by it. A hard edge against
        // the hairline would look like a clipping bug.
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: const [0, 0.12, 0.88, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: AnimatedBuilder(
                animation: _run,
                // The strip is laid out once and only shifted, so a 26-second
                // loop costs one transform per frame rather than a rebuild of
                // twenty chips.
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(-_run.value / 2, 0),
                  child: child,
                ),
                child: strip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleChip extends StatelessWidget {
  final SampleItem item;

  const _SampleChip({required this.item});

  @override
  Widget build(BuildContext context) {
    // No surface of its own: the chip sits inside a card already, and a second
    // hairline a few millimetres inside the first reads as a box in a box
    // rather than as one item in a list. The icon tile carries the shape.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ServiceTile(
            item.name,
            iconName: item.iconKey,
            size: 36,
            radius: 11,
            fontSize: 15,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                softWrap: false,
                style: SubdockText.itemName.copyWith(fontSize: 13, height: 1.2),
              ),
              const SizedBox(height: 2),
              Text(
                item.when,
                maxLines: 1,
                softWrap: false,
                style: SubdockText.whenDate.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
