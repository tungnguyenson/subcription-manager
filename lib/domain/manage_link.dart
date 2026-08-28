/// Where to send someone who wants to see the subscription they are tracking.
///
/// The app never sees the provider's records, so the closest it can get to a
/// confirmed renewal date is putting the user one tap from the page that has
/// one. Which page that is depends on where they bought it, and that is the
/// part the app cannot work out on its own: a service sold through the web,
/// the App Store and Google Play at once has three different pages, and only
/// two of them will be empty for any given person.
///
/// Hence [PurchaseChannel] on the item rather than on the catalogue entry, and
/// hence the alternate under the button in `ManagePresenter`: an item whose
/// channel is still unknown shows the one page the catalogue does know about
/// and offers the store beneath it, and the tap that lands is the answer.
/// Asking up front would put a question about billing plumbing between the
/// user and adding their first item.
///
/// Two constants and nothing else. This file used to carry `primary` and
/// `alternates`, a second copy of the same decision `ManagePresenter` makes,
/// reached by nothing but its own test -- including the guess that an unknown
/// channel means the App Store. Two copies of one rule drift, and the copy
/// with a green test drifts silently.
abstract final class ManageLinks {
  /// Apple's own documented link for this. On iOS it opens the Subscriptions
  /// screen inside the App Store app, not Settings, and it needs no
  /// `itms-apps://` variant.
  static const appStore = 'https://apps.apple.com/account/subscriptions';

  static const playStore =
      'https://play.google.com/store/account/subscriptions';
}
