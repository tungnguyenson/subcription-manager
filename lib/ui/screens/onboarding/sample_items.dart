import 'package:subdock/i18n.dart';

/// One row in the marquee on the first onboarding card.
///
/// [iconKey] is an explicit mark key rather than something detected from
/// [name], and that is the point of the field. `SubdockMarks.detect` reads the
/// words a user typed, so a translated name would find a different icon in
/// each language — `Electricity` matches nothing and `Tiền điện` matches the
/// power glyph, which would leave an English reader looking at a bare letter
/// on the very first screen. Naming the key keeps the drawing fixed and lets
/// the words move.
class SampleItem {
  final String name;
  final String iconKey;
  final String when;

  const SampleItem(this.name, this.iconKey, this.when);
}

/// The ten rows that scroll past on the first card.
///
/// Chosen to make one argument in one glance: the list holds a streaming
/// subscription and a prepaid SIM and a driving licence, and the app treats
/// them alike. Four of the ten carry the provider's real mark — Netflix,
/// Spotify, Adobe, Claude — because a wall of drawn glyphs would read as
/// clip art, and the marks are what say "your actual list will look like
/// this".
/// The dates are written the way [MoneyFormat.shortDate] writes a real one,
/// day first, because this card is a picture of the list the user is about to
/// have and a differently shaped date would be a small lie in it.
List<SampleItem> sampleItems() => [
  SampleItem(S.t.sampleMobileSim, 'sim', S.t.expiresOn('23/09')),
  SampleItem(S.t.sampleElectricity, 'power', S.t.dueOn('20/08')),
  SampleItem('Netflix', 'netflix', S.t.renewsOn('22/08')),
  SampleItem('Adobe CC', 'adobe', S.t.renewsOn('23/08')),
  SampleItem(S.t.sampleCarInsurance, 'insurance', S.t.dueOn('04/11')),
  SampleItem(S.t.sampleDrivingLicence, 'identityCard', S.t.expiresOn('12/12')),
  SampleItem(S.t.sampleHomeInternet, 'router', S.t.dueOn('28/08')),
  SampleItem('Spotify', 'spotify', S.t.renewsOn('02/09')),
  SampleItem(S.t.sampleWaterBill, 'water', S.t.dueOn('30/08')),
  SampleItem('Claude Pro', 'claude', S.t.trialEndsOn('17/08')),
];
