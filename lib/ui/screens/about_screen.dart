import 'package:flutter/material.dart';

import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/headers.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/i18n.dart';

/// What this build is, and what the app does with what it is given.
///
/// The version is the reason the screen exists: it is the one thing a person
/// has to be able to read off the app when something has gone wrong and they
/// are describing it to someone else.
///
/// The numbers arrive as strings rather than being read here. Asking the
/// platform for them is a channel call, and a screen that cannot be built
/// without one is a screen that cannot be tested.
class AboutScreen extends StatelessWidget {
  /// `1.0.0`, or `—` where the platform would not say.
  final String version;

  /// The build number behind the version. Its own row because the two answer
  /// different questions: the version says which release, this says which copy
  /// of it, and a bug report needs the second one.
  ///
  /// Not called `build`: that is [StatelessWidget.build]'s name.
  final String buildNumber;

  final VoidCallback? onBack;

  const AboutScreen({
    super.key,
    required this.version,
    required this.buildNumber,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    SubdockTheme.watch(context);
    return ListView(
      padding: SubdockSpacing.screenPadding(context),
      children: [
        BackLink(onTap: onBack),
        Text(S.t.aboutTitle, style: SubdockText.screenTitle),
        const SizedBox(height: 6),
        Text(S.t.aboutLead, style: SubdockText.summary),
        SectionLabel(S.t.aboutThisBuild),
        GroupedCard(
          children: [
            DetailRow(label: S.t.aboutVersion, value: version, monoValue: true),
            DetailRow(
              label: S.t.aboutBuild,
              value: buildNumber,
              monoValue: true,
            ),
          ],
        ),
        SectionLabel(S.t.aboutWhatItDoes),
        GroupedCard(
          children: [
            // Three answers to the question a careful person asks about an app
            // that knows when their bills are due. Value rows rather than
            // prose, because the shape is what makes them read as facts.
            DetailRow(label: S.t.aboutAccount, value: S.t.aboutNone),
            DetailRow(label: S.t.aboutServer, value: S.t.aboutNone),
            DetailRow(label: S.t.aboutYourList, value: S.t.aboutOnThisPhone),
          ],
        ),
        Footnote(S.t.aboutPrices),
      ],
    );
  }
}
