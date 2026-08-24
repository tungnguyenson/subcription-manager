import 'package:meta/meta.dart';

import 'package:subdock/domain/model.dart';

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
/// hence [alternates]: an item whose channel is still [PurchaseChannel.unknown]
/// shows its best guess and offers the others, and the tap that lands is the
/// answer. Asking up front would put a question about billing plumbing between
/// the user and adding their first item.
@immutable
class ManageDestination {
  final String url;
  final PurchaseChannel channel;

  const ManageDestination(this.channel, this.url);

  @override
  bool operator ==(Object other) =>
      other is ManageDestination &&
      other.url == url &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(url, channel);

  @override
  String toString() => '${channel.wireName} -> $url';
}

abstract final class ManageLinks {
  /// Apple's own documented link for this. On iOS it opens the Subscriptions
  /// screen inside the App Store app, not Settings, and it needs no
  /// `itms-apps://` variant.
  static const appStore = 'https://apps.apple.com/account/subscriptions';

  static const playStore =
      'https://play.google.com/store/account/subscriptions';

  static String? _storeFor(PurchaseChannel channel) => switch (channel) {
    PurchaseChannel.appStore => appStore,
    PurchaseChannel.playStore => playStore,
    PurchaseChannel.web || PurchaseChannel.unknown => null,
  };

  /// The one destination to put on the button.
  ///
  /// Null when there is nowhere useful to go: a bill or a document has no
  /// vendor page, and pointing at a store that will not list it is worse than
  /// showing no button at all.
  static ManageDestination? primary(
    PurchaseChannel channel, {
    String? vendorUrl,
  }) {
    final store = _storeFor(channel);
    if (store != null) return ManageDestination(channel, store);

    if (vendorUrl != null && vendorUrl.isNotEmpty) {
      return ManageDestination(channel, vendorUrl);
    }

    // Nothing was recorded and the catalogue has no page. The store is still a
    // real answer for a phone subscription, so offer it rather than nothing --
    // but only when the channel is genuinely unknown. A user who already said
    // "web" and whose service has no page gets no button, because the store is
    // the one place their subscription is definitely not.
    if (channel == PurchaseChannel.unknown) {
      return const ManageDestination(PurchaseChannel.appStore, appStore);
    }
    return null;
  }

  /// The other places this subscription could be, offered so a wrong guess
  /// costs one tap to fix.
  ///
  /// Empty once the channel is known: someone who has told the app where they
  /// bought it should not keep being asked.
  static List<ManageDestination> alternates(
    PurchaseChannel channel, {
    String? vendorUrl,
    bool includePlayStore = false,
  }) {
    if (channel != PurchaseChannel.unknown) return const [];

    final first = primary(channel, vendorUrl: vendorUrl);
    final all = [
      if (vendorUrl != null && vendorUrl.isNotEmpty)
        ManageDestination(PurchaseChannel.web, vendorUrl),
      const ManageDestination(PurchaseChannel.appStore, appStore),
      if (includePlayStore)
        const ManageDestination(PurchaseChannel.playStore, playStore),
    ];
    return all.where((d) => d.url != first?.url).toList(growable: false);
  }
}
