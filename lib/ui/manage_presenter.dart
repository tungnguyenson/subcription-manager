import 'package:meta/meta.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/manage_link.dart';
import 'package:subdock/domain/model.dart';

/// One tappable way out of the app, and what tapping it tells us.
@immutable
class ManageAction {
  final String label;
  final String url;

  /// What the app learns from this tap. Someone who opens the App Store
  /// listing has just said where they bought the thing, and saying it twice is
  /// something no user should be asked to do.
  final PurchaseChannel records;

  const ManageAction({
    required this.label,
    required this.url,
    required this.records,
  });

  @override
  bool operator ==(Object other) =>
      other is ManageAction &&
      other.label == label &&
      other.url == url &&
      other.records == records;

  @override
  int get hashCode => Object.hash(label, url, records);
}

/// The button block, or nothing.
@immutable
class ManageOffer {
  final ManageAction primary;

  /// The escape hatch under the button, offered only while the app still does
  /// not know where this subscription was bought. It disappears for good on
  /// the first tap of either option.
  final ManageAction? alternate;

  const ManageOffer({required this.primary, this.alternate});
}

abstract final class ManagePresenter {
  /// Where to send someone who wants to see this subscription as the provider
  /// has it, or null when there is nowhere worth sending them.
  ///
  /// The null case is not a gap to fill later. A passport, an electricity bill
  /// and a loan instalment have no vendor billing page and are not in anyone's
  /// App Store subscriptions, so a button here would be a button to a page
  /// that is guaranteed not to hold the answer.
  static ManageOffer? of({required TrackedItem item, CatalogEntry? entry}) {
    final vendorUrl = entry?.manageUrl;
    final name = entry?.name ?? item.name;

    final vendor = vendorUrl == null || vendorUrl.isEmpty
        ? null
        : ManageAction(
            label: 'Open $name account',
            url: vendorUrl,
            records: PurchaseChannel.web,
          );

    const store = ManageAction(
      label: 'Manage in the App Store',
      url: ManageLinks.appStore,
      records: PurchaseChannel.appStore,
    );

    return switch (item.purchaseChannel) {
      // Already answered. One button, no question under it.
      PurchaseChannel.appStore => const ManageOffer(primary: store),
      PurchaseChannel.playStore => const ManageOffer(
        primary: ManageAction(
          label: 'Manage in Google Play',
          url: ManageLinks.playStore,
          records: PurchaseChannel.playStore,
        ),
      ),
      PurchaseChannel.web =>
        vendor == null ? null : ManageOffer(primary: vendor),

      // Not answered yet. The vendor's page is the better guess when there is
      // one, with the store offered underneath; the tap that lands is the
      // answer, so the question is never put to the user directly.
      PurchaseChannel.unknown when vendor != null => ManageOffer(
        primary: vendor,
        alternate: const ManageAction(
          label: 'Bought through the App Store?',
          url: ManageLinks.appStore,
          records: PurchaseChannel.appStore,
        ),
      ),

      // No vendor page. The store is still a real answer for something that
      // renews, and no answer at all for anything else.
      PurchaseChannel.unknown =>
        item.category == Category.subscription
            ? const ManageOffer(primary: store)
            : null,
    };
  }
}
