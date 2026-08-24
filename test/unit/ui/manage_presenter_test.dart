import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/manage_link.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/manage_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  CatalogEntry entry({String? manageUrl = 'https://netflix.com/account'}) =>
      CatalogEntry(
        id: 'netflix',
        name: 'Netflix',
        category: Category.subscription,
        manageUrl: manageUrl,
      );

  TrackedItem item({
    PurchaseChannel channel = PurchaseChannel.unknown,
    Category category = Category.subscription,
    String name = 'Netflix',
  }) => TrackedItem(
    id: 'x',
    name: name,
    category: category,
    expiresOn: d('2026-09-01'),
    anchorDate: d('2026-09-01'),
    purchaseChannel: channel,
  );

  group('before the app knows where it was bought', () {
    test('leads with the vendor and offers the store underneath', () {
      final offer = ManagePresenter.of(item: item(), entry: entry());

      expect(offer!.primary.label, 'Open Netflix account');
      expect(offer.primary.url, 'https://netflix.com/account');
      expect(offer.alternate!.label, 'Bought through the App Store?');
      expect(offer.alternate!.url, ManageLinks.appStore);
    });

    // The tap is the question. Neither option may leave the channel unknown,
    // or the user would be asked the same thing on every visit.
    test('either tap settles the question', () {
      final offer = ManagePresenter.of(item: item(), entry: entry());

      expect(offer!.primary.records, PurchaseChannel.web);
      expect(offer.alternate!.records, PurchaseChannel.appStore);
    });

    test('a subscription with no vendor page still gets the store', () {
      final offer = ManagePresenter.of(
        item: item(),
        entry: entry(manageUrl: null),
      );

      expect(offer!.primary.label, 'Manage in the App Store');
      expect(offer.alternate, isNull);
    });

    test('an item with no catalog match at all still gets the store', () {
      final offer = ManagePresenter.of(item: item(), entry: null);
      expect(offer!.primary.url, ManageLinks.appStore);
    });
  });

  group('once the answer is on record', () {
    test('the question is never put again', () {
      for (final channel in [
        PurchaseChannel.web,
        PurchaseChannel.appStore,
        PurchaseChannel.playStore,
      ]) {
        final offer = ManagePresenter.of(
          item: item(channel: channel),
          entry: entry(),
        );
        expect(offer!.alternate, isNull, reason: channel.name);
      }
    });

    test('App Store goes to Apple, not to the vendor', () {
      final offer = ManagePresenter.of(
        item: item(channel: PurchaseChannel.appStore),
        entry: entry(),
      );

      expect(offer!.primary.url, ManageLinks.appStore);
      expect(offer.primary.label, 'Manage in the App Store');
    });

    test('web goes to the vendor', () {
      final offer = ManagePresenter.of(
        item: item(channel: PurchaseChannel.web),
        entry: entry(),
      );
      expect(offer!.primary.url, 'https://netflix.com/account');
    });

    // Someone who has already said "web" and whose service has no page gets no
    // button. The store is the one place their subscription certainly is not.
    test('web with no vendor page shows nothing', () {
      final offer = ManagePresenter.of(
        item: item(channel: PurchaseChannel.web),
        entry: entry(manageUrl: null),
      );
      expect(offer, isNull);
    });
  });

  group('the things that are not subscriptions', () {
    // A passport is not in anyone's App Store subscriptions and has no billing
    // page. A button here would be a button to a page guaranteed not to hold
    // the answer.
    test('a document, a bill and a loan get no button', () {
      for (final category in [
        Category.document,
        Category.bill,
        Category.other,
      ]) {
        final offer = ManagePresenter.of(
          item: item(category: category, name: 'Hộ chiếu'),
          entry: null,
        );
        expect(offer, isNull, reason: category.name);
      }
    });

    // ...unless the catalogue does have a page for it. An insurance policy
    // renewed on the insurer's own portal is worth a link.
    test('but a non-subscription with a real page keeps it', () {
      final offer = ManagePresenter.of(
        item: item(category: Category.insurance, name: 'Bảo hiểm'),
        entry: entry(manageUrl: 'https://insurer.example/policy'),
      );
      expect(offer!.primary.url, 'https://insurer.example/policy');
    });
  });

  test('the button names the catalog service, not the user own wording', () {
    final offer = ManagePresenter.of(
      item: item(name: 'netflix'),
      entry: entry(),
    );
    expect(offer!.primary.label, 'Open Netflix account');
  });
}
