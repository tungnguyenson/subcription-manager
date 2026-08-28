import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/screens/services_screen.dart';
import 'package:subdock/ui/services_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-15');

  TrackedItem item(
    String name, {
    String categoryId = 'STREAMING',
    String expiresOn = '2026-08-22',
    int? amountMinor = 260000,
    bool paused = false,
    ItemState state = ItemState.active,
    bool inTrial = false,
    String? paymentSourceId,
  }) => TrackedItem(
    id: name,
    name: name,
    categoryId: categoryId,
    expiresOn: d(expiresOn),
    anchorDate: d(expiresOn),
    cycle: Cycle.monthly,
    amountMinor: amountMinor,
    currency: amountMinor == null ? null : 'VND',
    paused: paused,
    state: state,
    inTrial: inTrial,
    paymentSourceId: paymentSourceId,
  );

  List<ServiceGroup> groupsOf(List<TrackedItem> items) =>
      ServicesPresenter.groups(items, CategoryBook.shipped, today);

  group('the service list', () {
    // One grouping, and it is the shelf the item carries. The old pair --
    // a five-value classification and the catalogue's own twenty-one-way
    // grouping -- could each answer only half of "do I still have a music
    // subscription": one put nearly everything under a single heading, the
    // other had no say in how anything behaved.
    test('shelves by the item own category, in the user order', () {
      final groups = groupsOf([
        item('Apple Music', categoryId: 'MUSIC'),
        item('Netflix'),
        item('Spotify', categoryId: 'MUSIC'),
      ]);

      expect(groups.map((g) => g.label), ['Streaming', 'Music']);
      expect(groups.last.rows.map((r) => r.name), ['Apple Music', 'Spotify']);
    });

    // Nothing is promoted by name any more, the SIM shelf included. A shelf
    // the app moves to the top on its own is a shelf the user cannot move back
    // down when the app has guessed wrong about them.
    test('no shelf jumps the queue', () {
      final groups = groupsOf([
        item('Netflix'),
        item('Viettel 0912 345 678', categoryId: 'PHONE'),
      ]);

      expect(groups.map((g) => g.label), ['Streaming', 'Mobile and SIM']);
    });

    // An empty shelf is not drawn: the list is what the user has, not what
    // they could have.
    test('a shelf with nothing on it is left off', () {
      final groups = groupsOf([item('Netflix')]);

      expect(groups.map((g) => g.label), ['Streaming']);
    });

    // The foreign key is supposed to make this impossible. It is drawn anyway
    // rather than dropped, because a service missing from this list is a
    // service the user believes they are not being charged for.
    test('an item on a shelf that is gone is still shown', () {
      final groups = groupsOf([
        item('Netflix'),
        item('Something local', categoryId: 'DELETED_SHELF'),
      ]);

      expect(groups.map((g) => g.label), ['Streaming', 'Other']);
      expect(groups.last.rows.single.name, 'Something local');
    });

    test('the subtitle says the next date and the amount', () {
      final groups = groupsOf([item('Netflix')]);

      expect(groups.single.rows.single.subtitle, 'Next 22/08 · 260,000 ₫');
      expect(groups.single.rows.single.on, isTrue);
    });

    // A paused item's next date is not a fact about the future any more —
    // nothing will happen on it — so showing it beside the word "off" would put
    // two contradictory things on one line.
    test('a paused row says only that it is off', () {
      final groups = groupsOf([item('Netflix', paused: true)]);

      expect(groups.single.rows.single.subtitle, 'Off · no reminders');
      expect(groups.single.rows.single.on, isFalse);
    });

    test('a trial names the day the free period ends', () {
      final groups = groupsOf([item('Claude Pro', inTrial: true)]);

      expect(
        groups.single.rows.single.subtitle,
        'Trial ends 22/08 · 260,000 ₫',
      );
    });

    // Inactive is finished, not paused: the last instalment of a course, a
    // cancelled plan whose period has run out. A switch on one would promise to
    // bring it back, which it cannot.
    test('an inactive item is not on the list', () {
      final groups = groupsOf([
        item('Netflix'),
        item('Old course', state: ItemState.inactive),
      ]);

      expect(groups.single.rows.map((r) => r.name), ['Netflix']);
    });

    // Cancelled is not the same as switched off, and the row carries both. The
    // switch is the loudest thing on it and it answers the smaller question --
    // whether the user wants to hear about this -- so without the badge a
    // cancelled service and a muted one are the same row.
    test('a cancelled item stays on the list and is marked', () {
      final rows = groupsOf([
        item('Netflix').copyWith(state: ItemState.cancelledStillActive),
      ]).single.rows;

      expect(rows.single.cancelled, isTrue);
      expect(rows.single.on, isTrue);
    });

    test('an ordinary item is not marked', () {
      expect(groupsOf([item('Netflix')]).single.rows.single.cancelled, isFalse);
    });

    test('an item with no amount shows only its date', () {
      final groups = groupsOf([item('Passport', amountMinor: null)]);

      expect(groups.single.rows.single.subtitle, 'Next 22/08');
    });
  });

  group('payment sources', () {
    const vcb = PaymentSource(id: 's1', name: 'VCB 4412');
    const momo = PaymentSource(
      id: 's2',
      name: 'Momo',
      glyph: SourceGlyph.wallet,
    );

    // Remove is destructive-looking and the user has to see what it costs
    // before tapping. "1 item" makes them guess; the name does not.
    test('one user is named rather than counted', () {
      final rows = ServicesPresenter.sourceRows(
        [vcb],
        [item('Netflix', paymentSourceId: 's1')],
      );

      expect(rows.single.usage, 'Netflix');
      expect(rows.single.itemCount, 1);
    });

    test('several users are counted', () {
      final rows = ServicesPresenter.sourceRows(
        [vcb],
        [
          item('Netflix', paymentSourceId: 's1'),
          item('Spotify', paymentSourceId: 's1'),
        ],
      );

      expect(rows.single.usage, '2 items');
    });

    test('an unused source says so, so removing it is obviously free', () {
      final rows = ServicesPresenter.sourceRows([momo], [item('Netflix')]);

      expect(rows.single.usage, 'Not used yet');
      expect(rows.single.itemCount, 0);
    });

    test('the rows keep the order the sources came in', () {
      final rows = ServicesPresenter.sourceRows([vcb, momo], const []);

      expect(rows.map((r) => r.source.name), ['VCB 4412', 'Momo']);
    });

    test('one row is flagged as where a new item starts', () {
      final rows = ServicesPresenter.sourceRows(
        [vcb, momo],
        const [],
        defaultId: momo.id,
      );

      expect(rows.map((r) => r.isDefault), [false, true]);
    });

    // The stored id can name a source that has since been removed. The flag
    // simply goes off every row rather than the list refusing to build.
    test('a default that no longer exists flags nothing', () {
      final rows = ServicesPresenter.sourceRows(
        [vcb],
        const [],
        defaultId: 'gone',
      );

      expect(rows.single.isDefault, isFalse);
    });
  });

  // A lapsed prepaid number cannot be bought back, so its shelf must not sit
  // below Streaming where a user scrolling for it gives up first.
  // The SIM shelf used to jump to the top of this screen no matter what, and
  // no longer does. Losing a prepaid number still costs more than anything
  // else in the app, but that is a judgement the shipped settings make -- the
  // shelf nags daily and reads as *expires* -- not one the list hard-codes.
  // A user who moves it to the bottom means it.
  group('the shelf SIMs go on', () {
    test('sits wherever the user has put it', () {
      final groups = groupsOf([
        item('Netflix'),
        item('Viettel 0912 345 678', categoryId: 'PHONE'),
      ]);

      expect(groups.map((g) => g.label), ['Streaming', 'Mobile and SIM']);
      expect(groups.last.rows.single.name, 'Viettel 0912 345 678');
    });

    test('still ships nagging daily and reading as expires', () {
      expect(CategoryBook.shipped['PHONE'].nag, NagPolicy.daily);
      expect(CategoryBook.shipped['PHONE'].wording, CategoryWording.expires);
    });
  });
}
