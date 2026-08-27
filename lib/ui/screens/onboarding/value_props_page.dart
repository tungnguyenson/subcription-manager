import 'package:flutter/material.dart';

import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/onboarding/lock_preview.dart';
import 'package:subdock/ui/screens/onboarding/marquee.dart';
import 'package:subdock/ui/screens/onboarding/sample_items.dart';
import 'package:subdock/ui/screens/onboarding/spend_preview.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The first onboarding page: three claims, each one shown rather than stated.
///
/// The order is the order the app is used in, and each card carries a moving
/// picture of the claim above it. A card that only made the claim in words
/// would be a slide; the marquee, the arriving notifications and the growing
/// chart are the three screens the user is about to have, running before they
/// have typed anything.
class ValuePropsPage extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  ValuePropsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          S.t.onboardTitle,
          // 23, from the design. See the same line on the setup page for why
          // it is not the app's own `onboardTitle` size.
          style: SubdockText.onboardTitle.copyWith(fontSize: 23, height: 1.3),
        ),
        const SizedBox(height: 24),
        _Card(
          title: S.t.onboardListTitle,
          // Zero side padding, because the strip has to run out past the
          // card's edge for the fade to mean anything.
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 15),
          titleInset: 14,
          child: SampleMarquee(items: sampleItems()),
        ),
        const SizedBox(height: 14),
        _Card(
          title: S.t.onboardNotifyTitle,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: LockPreview(notifications: _notifications()),
        ),
        const SizedBox(height: 14),
        _Card(
          title: S.t.onboardSpendTitle,
          padding: const EdgeInsets.all(14),
          child: SpendPreview(),
        ),
      ],
    );
  }

  /// The two lines shown arriving on the lock screen.
  ///
  /// Deliberately not two subscriptions. The first is a prepaid SIM three days
  /// from lapsing, which is the loss this app exists to prevent, and the
  /// second is Netflix renewing tomorrow, which is the loss it is usually
  /// installed for. Showing only the second would sell a cheaper app than
  /// this one.
  List<PreviewNotification> _notifications() => [
    PreviewNotification(
      name: S.t.sampleMobileSim,
      iconKey: 'sim',
      title: S.t.notifSimTitle(3),
      body: S.t.notifSimBody,
      stamp: S.t.notifNow,
    ),
    PreviewNotification(
      name: 'Netflix',
      iconKey: 'netflix',
      title: S.t.notifNetflixTitle,
      body: S.t.notifNetflixBody(MoneyFormat.full(_sampleCharge(Fx.base))),
      stamp: S.t.notifAge(1),
    ),
  ];

  /// A month of streaming in the currency in force. Round, for the reason
  /// [SpendPreview.sampleTotal] is round.
  static Money _sampleCharge(String currency) =>
      Money(Currencies.exponentOf(currency) == 0 ? 260000 : 1099, currency);
}

/// One value-prop card: a claim, then the picture of it.
class _Card extends StatelessWidget {
  final String title;
  final EdgeInsets padding;

  /// Extra left and right inset for the title alone, used by the card whose
  /// picture bleeds to the edge.
  final double titleInset;

  final Widget child;

  const _Card({
    required this.title,
    required this.padding,
    required this.child,
    this.titleInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      padding: padding,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: titleInset),
          child: Text(
            title,
            style: SubdockText.itemName.copyWith(fontSize: 17, height: 1.35),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
