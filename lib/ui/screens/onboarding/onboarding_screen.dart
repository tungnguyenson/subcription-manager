import 'package:flutter/material.dart';

import 'package:subdock/domain/currency_picks.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/screens/onboarding/setup_page.dart';
import 'package:subdock/ui/screens/onboarding/value_props_page.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The two screens shown before the list exists.
///
/// Two, and in this order, because the first one has to earn the second. The
/// currency and language questions are the only two the app genuinely cannot
/// answer for itself, and asked cold at first launch they are a form standing
/// between a person and an app they have not seen yet. Asked after the three
/// cards, they are the last step of something already understood.
///
/// What is deliberately *not* here any more: the notification permission and
/// the restore-from-backup button. The permission is asked the moment the
/// first item is saved, where the sheet can name the date it is about — see
/// [NotificationAsk], where the timing is the whole feature. Restore has moved
/// to Settings.
class OnboardingScreen extends StatefulWidget {
  final CurrencyPicks picks;
  final AppLocale locale;

  /// Called as the user taps, not at the end. Both choices take effect
  /// immediately — the language so the rest of this screen is already in it,
  /// and the currency so the sample figures are.
  final ValueChanged<CurrencyPicks> onCurrency;
  final ValueChanged<AppLocale> onLocale;

  /// The list is ready to be opened.
  final VoidCallback? onStart;

  const OnboardingScreen({
    super.key,
    required this.picks,
    required this.locale,
    required this.onCurrency,
    required this.onLocale,
    this.onStart,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _page == _pageCount - 1;

  static const int _pageCount = 2;

  void _advance() {
    if (_last) {
      widget.onStart?.call();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // The dots are on both pages, not only the second the way the design
          // frames show them. They cost five points and they are what stops
          // the title jumping down the screen between the two.
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _Dots(count: _pageCount, current: _page),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              // Not `const`. A const child is the same widget instance on
              // every rebuild, and Flutter skips an identical subtree
              // outright -- so a page that reads `S.t` or `Fx.base` from a
              // const seat keeps the language and the currency it was first
              // built with. Same rule as the palette; see trap 34.
              _Scrollable(child: ValuePropsPage()),
              _Scrollable(
                child: SetupPage(
                  picks: widget.picks,
                  locale: widget.locale,
                  onCurrency: widget.onCurrency,
                  onLocale: widget.onLocale,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: PrimaryButton(
            _last ? S.t.getStarted : S.t.continueOn,
            onPressed: _advance,
          ),
        ),
      ],
    );
  }
}

/// Each page scrolls on its own.
///
/// It has to: the first page is three cards tall on a 390x844 frame and only
/// just fits, and a phone one size smaller, or a reader whose text scale is
/// turned up, would otherwise lose the bottom card with no way to reach it.
class _Scrollable extends StatelessWidget {
  final Widget child;

  const _Scrollable({required this.child});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    child: child,
  );
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 22,
            height: 5,
            decoration: BoxDecoration(
              color: i == current
                  ? SubdockColors.accent
                  : SubdockColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}
