import 'package:flutter/material.dart';

import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/theme.dart';

/// The little bar chart on the third onboarding card.
///
/// Made-up figures, and they have to be: the user has nothing in the app yet,
/// so a chart drawn from their data would be twelve empty columns. What it
/// promises is the *shape* of the Money screen — a bar per month, the one
/// being totalled picked out in the accent — and that promise is kept.
///
/// The amount is stated in whatever currency is in force, so someone whose
/// phone suggested dollars is not shown a seven-figure sum. See [sampleTotal].
class SpendPreview extends StatefulWidget {
  /// Column heights as a fraction of the tallest, left to right.
  static const List<double> shape = [
    0.42, 0.55, 0.36, 0.50, 0.62, 0.44, 0.70, 0.58, 1.0, //
  ];

  // Not a const constructor. This widget reads `Fx.base`, a global that can
  // change while the app is open, and a const instance would be identical
  // across rebuilds -- which Flutter takes as licence to skip the subtree
  // entirely. See trap 34.
  // ignore: prefer_const_constructors_in_immutables
  SpendPreview({super.key});

  /// A believable year of subscriptions in [Fx.base].
  ///
  /// Two figures rather than one converted number. Converting would need a
  /// rate the app only holds for one pair, and it would land on an amount like
  /// 545.31 that reads as a real total someone might go looking for. These are
  /// round on purpose: a made-up number should look made up.
  static Money sampleTotal(String currency) =>
      Money(Currencies.exponentOf(currency) == 0 ? 14208000 : 59200, currency);

  @override
  State<SpendPreview> createState() => _SpendPreviewState();
}

class _SpendPreviewState extends State<SpendPreview>
    with SingleTickerProviderStateMixin {
  /// Plays once, on arrival, and stops. The marquee and the notifications
  /// loop because they are showing a thing that keeps happening; a chart that
  /// kept regrowing would be a fidget in the corner of the screen.
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _grow.value = 1;
    } else if (!_grow.isAnimating && _grow.value == 0) {
      _grow.forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bars = SpendPreview.shape;
    final last = bars.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < bars.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _grow,
                    builder: (context, _) {
                      final start = i * 0.07;
                      final t = Curves.easeOutCubic.transform(
                        ((_grow.value - start) / 0.45).clamp(0.0, 1.0),
                      );
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          // A floor rather than zero, so the row reads as a
                          // set of columns from the first frame instead of
                          // sprouting out of nothing.
                          height: 76 * bars[i] * (0.06 + 0.94 * t),
                          decoration: BoxDecoration(
                            color: i == last
                                ? SubdockColors.accent
                                : SubdockColors.accentSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 11),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                S.t.onboardNextTwelveMonths,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SubdockText.itemSubtitle.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              MoneyFormat.full(SpendPreview.sampleTotal(Fx.base)),
              style: SubdockText.monoValue.copyWith(
                fontSize: 15,
                color: SubdockColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
