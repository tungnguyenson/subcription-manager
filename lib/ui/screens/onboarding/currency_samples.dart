import 'package:meta/meta.dart';

import 'package:subdock/domain/money.dart';

/// One bill, drawn on the card that stands for a currency.
///
/// The card shows a bill rather than the currency's name and symbol, and that
/// is the whole argument of the screen: the question is not "which glyph do
/// you like", it is "what do your bills look like", and a row reading
/// `Netflix · Standard · 231,000 ₫` answers that in a glance where `VND ·
/// Vietnamese đồng` only answers a quiz.
///
/// [tier] is null where the service sells one thing, because a sample line
/// reading `Monthly · monthly` is worse than one reading `monthly`.
@immutable
class SampleBill {
  /// An explicit mark key, for the same reason [SampleItem] carries one: the
  /// name shown here is a provider's name and must not be re-detected per
  /// language. A key naming no mark falls through to the drawn letter, which
  /// is the normal outcome for most of this list.
  final String iconKey;

  final String name;
  final String? tier;
  final Money amount;

  const SampleBill(this.iconKey, this.name, this.tier, this.amount);
}

/// A believable monthly bill per currency.
///
/// Two of them are not invented. `USD` and `VND` come off the app's own
/// catalog, with the price the catalog carries and a source behind it, because
/// those two are the currencies almost everyone picking here will pick and a
/// made-up figure on this screen would be a figure the app itself contradicts
/// three taps later on the same service's page.
///
/// The other ten are illustrative and no more, in the way the marquee's dates
/// on the previous page are. They name a service people in that currency
/// actually pay and a plausible price for it; nothing in the app reads them,
/// nothing is totalled from them, and no screen ever presents them as a fact
/// about a provider.
///
/// A currency with no entry here is not a gap. [sampleBillFor] returns null
/// and the card falls back to the currency's own name and mark, which is what
/// the picker showed for every currency before this table existed.
SampleBill? sampleBillFor(String currency) => _bills[currency.toUpperCase()];

final Map<String, SampleBill> _bills = {
  'USD': SampleBill('spotify', 'Spotify', 'Individual', Money(1299, 'USD')),
  'VND': SampleBill('netflix', 'Netflix', 'Standard', Money(231000, 'VND')),
  'EUR': SampleBill('spotify', 'Spotify', 'Individual', Money(1099, 'EUR')),
  'GBP': SampleBill('news', 'The Guardian', 'Digital', Money(1200, 'GBP')),
  'JPY': SampleBill(
    'gaming',
    'Nintendo Switch Online',
    'Individual',
    Money(306, 'JPY'),
  ),
  'KRW': SampleBill(
    'streaming',
    'Coupang Play',
    'Standard',
    Money(7900, 'KRW'),
  ),
  'SGD': SampleBill('travel', 'Grab', 'Unlimited', Money(599, 'SGD')),
  'AUD': SampleBill('streaming', 'Stan', 'Basic', Money(1200, 'AUD')),
  'INR': SampleBill('streaming', 'JioHotstar', 'Super', Money(29900, 'INR')),
  'THB': SampleBill('streaming', 'Viu', 'Premium', Money(14900, 'THB')),
  'CAD': SampleBill('fitness', 'GoodLife Fitness', null, Money(6499, 'CAD')),
  'PHP': SampleBill('router', 'Globe At Home', null, Money(169900, 'PHP')),
};
