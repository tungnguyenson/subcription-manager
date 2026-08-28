import 'package:meta/meta.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/manage_link.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/i18n.dart';

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
  static ManageOffer? of({
    required TrackedItem item,
    required Category category,
    CatalogEntry? entry,
  }) {
    // Only something that renews can be sitting in a store's subscription list.
    // A shelf that keeps nagging after the date is an obligation -- a bill, a
    // policy, a passport -- and none of those is cancelled from the App Store.
    final renews = !category.isObligation;

    final vendorUrl = entry?.manageUrl;
    final name = entry?.name ?? item.name;

    final vendor = vendorUrl == null || vendorUrl.isEmpty
        ? null
        : ManageAction(
            label: S.t.openAccount(name),
            url: vendorUrl,
            records: PurchaseChannel.web,
          );

    final store = ManageAction(
      label: S.t.manageInAppStore,
      url: ManageLinks.appStore,
      records: PurchaseChannel.appStore,
    );

    return switch (item.purchaseChannel) {
      // Already answered. One button, no question under it.
      PurchaseChannel.appStore => ManageOffer(primary: store),
      PurchaseChannel.playStore => ManageOffer(
        primary: ManageAction(
          label: S.t.manageInGooglePlay,
          url: ManageLinks.playStore,
          records: PurchaseChannel.playStore,
        ),
      ),
      PurchaseChannel.web =>
        vendor == null ? null : ManageOffer(primary: vendor),

      // Not answered yet, and the only thing the app has to go on is the
      // catalogue's page. It leads, with the store offered underneath as a
      // question; the tap that lands is the answer, so the question is never
      // put to the user directly.
      //
      // No page means no button. The app knows nothing about where this item
      // was bought -- there is no field for it on the form, and a hand-typed
      // item carries the `unknown` the column defaults to -- so a store button
      // here would be a guess wearing the clothes of an answer, on a screen
      // whose whole job is saying how much the app actually knows. It used to
      // show one anyway, reasoning that a shelf which stops nagging renews and
      // a thing that renews might be in a store. That reasoning holds nothing
      // about the item in front of it: a hand-typed Vietnamese service billed
      // on the vendor's own site got `Manage in the App Store`, pointing at a
      // list it is guaranteed not to be in.
      //
      // Worse than a dead end, because the tap writes. `_openManage` records
      // the channel the button claims, so one curious tap tells the app the
      // item was bought from Apple for good, and `SavingsPresenter.cancelTarget`
      // then puts that ahead of the vendor's own cancellation page.
      PurchaseChannel.unknown =>
        vendor == null
            ? null
            : ManageOffer(
                primary: vendor,
                // Only where a store could plausibly hold it. An insurance
                // policy with a renewal portal is worth linking; asking whether
                // it came from the App Store is not.
                alternate: renews
                    ? ManageAction(
                        label: S.t.boughtThroughAppStore,
                        url: ManageLinks.appStore,
                        records: PurchaseChannel.appStore,
                      )
                    : null,
              ),
    };
  }
}
