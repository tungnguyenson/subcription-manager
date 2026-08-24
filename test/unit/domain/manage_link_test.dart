import 'package:flutter_test/flutter_test.dart';

import 'package:subdock/domain/manage_link.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';

void main() {
  const vendor = 'https://www.netflix.com/account';

  group('where the button goes', () {
    test('a web purchase goes to the vendor', () {
      expect(
        ManageLinks.primary(PurchaseChannel.web, vendorUrl: vendor)?.url,
        vendor,
      );
    });

    // The whole reason this file exists: the vendor's own page does not list a
    // subscription bought through Apple, so sending an App Store buyer there
    // shows them an empty account and no renewal date.
    test('an App Store purchase goes to Apple, not to the vendor', () {
      expect(
        ManageLinks.primary(PurchaseChannel.appStore, vendorUrl: vendor)?.url,
        ManageLinks.appStore,
      );
    });

    test('a Play Store purchase goes to Google', () {
      expect(
        ManageLinks.primary(PurchaseChannel.playStore, vendorUrl: vendor)?.url,
        ManageLinks.playStore,
      );
    });

    test('an unknown channel starts at the vendor when there is one', () {
      expect(
        ManageLinks.primary(PurchaseChannel.unknown, vendorUrl: vendor)?.url,
        vendor,
      );
    });

    test('an unknown channel with no vendor page still offers the store', () {
      final destination = ManageLinks.primary(PurchaseChannel.unknown);
      expect(destination?.url, ManageLinks.appStore);
      expect(destination?.channel, PurchaseChannel.appStore);
    });

    // A power bill has no vendor page and is definitely not an in-app
    // purchase. A button to Apple's subscriptions screen would be a dead end.
    test('a web purchase with no vendor page gets no button at all', () {
      expect(ManageLinks.primary(PurchaseChannel.web), isNull);
    });
  });

  group('the other options', () {
    test('an unknown channel offers the store beside the vendor', () {
      final others = ManageLinks.alternates(
        PurchaseChannel.unknown,
        vendorUrl: vendor,
      );
      expect(others.map((d) => d.url), [ManageLinks.appStore]);
    });

    test('never repeats whatever the button already goes to', () {
      final others = ManageLinks.alternates(PurchaseChannel.unknown);
      final first = ManageLinks.primary(PurchaseChannel.unknown);
      expect(others.map((d) => d.url), isNot(contains(first!.url)));
    });

    test('Play is offered only where it applies', () {
      expect(
        ManageLinks.alternates(
          PurchaseChannel.unknown,
          vendorUrl: vendor,
          includePlayStore: true,
        ).map((d) => d.channel),
        [PurchaseChannel.appStore, PurchaseChannel.playStore],
      );
    });

    // Once the answer is recorded, the question stops being asked. Otherwise
    // every row keeps a "did you buy this elsewhere?" affordance forever.
    test('nothing more is offered once the channel is known', () {
      for (final channel in [
        PurchaseChannel.web,
        PurchaseChannel.appStore,
        PurchaseChannel.playStore,
      ]) {
        expect(
          ManageLinks.alternates(channel, vendorUrl: vendor),
          isEmpty,
          reason: channel.wireName,
        );
      }
    });
  });

  group('the item carries the channel', () {
    test('defaults to unknown, because nobody has been asked yet', () {
      final item = TrackedItem(
        id: 'a',
        name: 'Netflix',
        category: Category.subscription,
        expiresOn: LocalDate(2026, 9, 1),
        anchorDate: LocalDate(2026, 9, 1),
      );
      expect(item.purchaseChannel, PurchaseChannel.unknown);
    });

    test('a tap records it and it survives a copy', () {
      final item = TrackedItem(
        id: 'a',
        name: 'Netflix',
        category: Category.subscription,
        expiresOn: LocalDate(2026, 9, 1),
        anchorDate: LocalDate(2026, 9, 1),
      ).copyWith(purchaseChannel: PurchaseChannel.appStore);

      expect(item.purchaseChannel, PurchaseChannel.appStore);
      expect(
        item.copyWith(name: 'Netflix Premium').purchaseChannel,
        PurchaseChannel.appStore,
      );
    });
  });
}
