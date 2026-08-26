import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/backup.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  /// Every nullable field filled and every enum off its default.
  ///
  /// The point is the round-trip assertion below: a field added to
  /// [TrackedItem] and forgotten in the codec comes back as its default here,
  /// and the comparison fails. That is the only thing standing between a new
  /// column and a backup that silently does not contain it.
  final loaded = TrackedItem(
    id: 'sim',
    name: 'Viettel SIM',
    categoryId: 'PHONE',
    iconName: 'viettel',
    expiresOn: d('2026-09-01'),
    actByOffsetDays: 3,
    anchorDate: d('2025-09-01'),
    cycle: Cycle.yearly,
    repeatCount: 6,
    amountMinor: 260000,
    currency: 'VND',
    actionUrl: 'https://viettel.vn/billing',
    actionLabel: 'Top up',
    note: 'Số dùng từ 2014.',
    leadDays: const [30, 7, 0],
    remindAt: const LocalTime(21, 15),
    nagAfterDue: NagPolicy.daily,
    verifyEveryDays: 90,
    lastVerifiedAt: d('2026-06-01'),
    dateSource: DateSource.userConfirmed,
    snoozedUntil: d('2026-08-28'),
    state: ItemState.cancelledStillActive,
    purchaseChannel: PurchaseChannel.appStore,
    inTrial: true,
    paymentSourceId: 'card-1',
    paused: true,
    yearlyChoice: YearlyChoice.skipped,
  );

  final source = const PaymentSource(
    id: 'card-1',
    name: 'Techcombank Visa',
    glyph: SourceGlyph.wallet,
  );

  final shelf = const Category(
    id: 'PHONE',
    label: 'Điện thoại',
    iconName: 'sim',
    wording: CategoryWording.expires,
    nag: NagPolicy.daily,
    leadDays: [30, 7],
    verifyEveryDays: 60,
    countsTowardSpend: false,
    builtIn: true,
    sortOrder: 4,
  );

  final event = HandledEvent(
    id: 'e1',
    itemId: 'sim',
    handledAtEpochSeconds: 1756000000,
    forDueDate: d('2025-09-01'),
    amountMinor: 2000,
    currency: 'USD',
    fxRateScaled: 254130,
    fxRateScale: 10,
    fxRateDate: d('2025-09-01'),
    fxSource: 'vietcombank',
    baseAmountMinor: 508260,
    actualChargedMinor: 520000,
  );

  Backup full() => Backup(
    categories: [shelf],
    sources: [source],
    items: [loaded],
    history: [event],
    defaultLeadDays: const [7, 1],
    remindAt: const LocalTime(6, 45),
    defaultSourceId: 'card-1',
    exportedAt: '2026-08-25T11:40:00.000Z',
    createdAt: const {'sim': 1700000000, 'card-1': 1690000000},
  );

  Backup roundTrip(Backup backup) =>
      BackupCodec.decode(BackupCodec.encode(backup));

  group('round trip', () {
    // Field by field rather than through an == that these classes do not
    // define. A `toString` comparison would pass on a class whose toString
    // omits the field that was dropped.
    test('an item keeps every field it went in with', () {
      final out = roundTrip(full()).items.single;

      expect(out.id, loaded.id);
      expect(out.name, loaded.name);
      expect(out.categoryId, loaded.categoryId);
      expect(out.iconName, loaded.iconName);
      expect(out.expiresOn, loaded.expiresOn);
      expect(out.actByOffsetDays, loaded.actByOffsetDays);
      expect(out.anchorDate, loaded.anchorDate);
      expect(out.cycle, loaded.cycle);
      expect(out.repeatCount, loaded.repeatCount);
      expect(out.amountMinor, loaded.amountMinor);
      expect(out.currency, loaded.currency);
      expect(out.actionUrl, loaded.actionUrl);
      expect(out.actionLabel, loaded.actionLabel);
      expect(out.note, loaded.note);
      expect(out.leadDays, loaded.leadDays);
      expect(out.remindAt, loaded.remindAt);
      expect(out.nagAfterDue, loaded.nagAfterDue);
      expect(out.verifyEveryDays, loaded.verifyEveryDays);
      expect(out.lastVerifiedAt, loaded.lastVerifiedAt);
      expect(out.dateSource, loaded.dateSource);
      expect(out.snoozedUntil, loaded.snoozedUntil);
      expect(out.state, loaded.state);
      expect(out.purchaseChannel, loaded.purchaseChannel);
      expect(out.inTrial, loaded.inTrial);
      expect(out.paymentSourceId, loaded.paymentSourceId);
      expect(out.paused, loaded.paused);
      expect(out.yearlyChoice, loaded.yearlyChoice);
    });

    test('a category keeps every field it went in with', () {
      final out = roundTrip(full()).categories.single;

      expect(out.id, shelf.id);
      expect(out.label, shelf.label);
      expect(out.iconName, shelf.iconName);
      expect(out.wording, shelf.wording);
      expect(out.nag, shelf.nag);
      expect(out.leadDays, shelf.leadDays);
      expect(out.verifyEveryDays, shelf.verifyEveryDays);
      expect(out.countsTowardSpend, shelf.countsTowardSpend);
      expect(out.builtIn, shelf.builtIn);
      expect(out.sortOrder, shelf.sortOrder);
    });

    // The FX snapshot is the reason history is worth backing up at all: it is
    // the only record of what a foreign charge actually cost on the day, and
    // nothing recomputes it. See spec 6.3.
    test('a recorded payment keeps its FX snapshot', () {
      final out = roundTrip(full()).history.single;

      expect(out.id, event.id);
      expect(out.itemId, event.itemId);
      expect(out.handledAtEpochSeconds, event.handledAtEpochSeconds);
      expect(out.forDueDate, event.forDueDate);
      expect(out.amountMinor, event.amountMinor);
      expect(out.currency, event.currency);
      expect(out.fxRateScaled, event.fxRateScaled);
      expect(out.fxRateScale, event.fxRateScale);
      expect(out.fxRateDate, event.fxRateDate);
      expect(out.fxSource, event.fxSource);
      expect(out.baseAmountMinor, event.baseAmountMinor);
      expect(out.actualChargedMinor, event.actualChargedMinor);
    });

    test('a payment source keeps its name and mark', () {
      final out = roundTrip(full()).sources.single;

      expect(out.id, source.id);
      expect(out.name, source.name);
      expect(out.glyph, source.glyph);
    });

    // Nothing on screen shows when a card was added, but the sources list is
    // ordered by it, so losing it shuffles the user's list on restore.
    test('creation timestamps survive', () {
      final out = roundTrip(full());

      expect(out.createdAtFor('sim', -1), 1700000000);
      expect(out.createdAtFor('card-1', -1), 1690000000);
    });

    test('the app-wide reminder defaults survive', () {
      final out = roundTrip(full());

      expect(out.defaultLeadDays, [7, 1]);
      expect(out.remindAt, const LocalTime(6, 45));
      // The sources come with the file and keep their ids, so this one still
      // names something on the other side.
      expect(out.defaultSourceId, 'card-1');
    });

    test('a custom cycle survives as itself', () {
      final every10 = full().items.single.copyWith(
        cycle: () => Cycle.every(10, CycleField.day),
      );
      final out = roundTrip(
        Backup(
          categories: [shelf],
          sources: const [],
          items: [every10],
          history: const [],
          exportedAt: '',
        ),
      ).items.single;

      expect(out.cycle, Cycle.every(10, CycleField.day));
    });
  });

  group('reading a file the app did not write', () {
    test('anything that is not JSON is refused by name', () {
      expect(
        () => BackupCodec.decode('hello'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('not a Subdock backup'),
          ),
        ),
      );
    });

    test('JSON without the marker is refused', () {
      expect(
        () => BackupCodec.decode('{"items": []}'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    // Refused rather than half-read. A newer file has fields this build cannot
    // represent, and restoring it would quietly drop them.
    test('a newer format is refused and says so', () {
      final ahead = jsonDecode(BackupCodec.encode(full()));
      ahead['version'] = Backup.version + 1;

      expect(
        () => BackupCodec.decode(jsonEncode(ahead)),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    // The normal case for a backup, and the reason the format is a copy of the
    // model rather than a dump of the SQLite file.
    test('an older file missing fields restores on defaults', () {
      const older = '''
{
  "format": "subdock.backup",
  "version": 1,
  "items": [
    {"id": "n", "name": "Netflix", "categoryId": "STREAMING",
     "expiresOn": "2026-09-01"}
  ]
}
''';
      final out = BackupCodec.decode(older);
      final item = out.items.single;

      expect(item.name, 'Netflix');
      expect(item.anchorDate, d('2026-09-01'), reason: 'falls back to expiry');
      expect(item.state, ItemState.active);
      expect(item.dateSource, DateSource.userEstimated);
      expect(item.inTrial, isFalse);
      expect(item.paused, isFalse);
      expect(item.yearlyChoice, YearlyChoice.undecided);
      expect(out.defaultLeadDays, const [3, 0]);
      expect(out.remindAt, const LocalTime(8, 30));
      expect(out.defaultSourceId, isNull);
    });

    // The anchor is what every cycle counts from. Falling back to today would
    // silently re-date the whole series to the day of the restore.
    test('a missing anchor falls back to the expiry, never to today', () {
      final out = BackupCodec.decode('''
{"format": "subdock.backup", "version": 1,
 "items": [{"id": "n", "name": "N", "categoryId": "S",
            "expiresOn": "2020-01-15"}]}
''');
      expect(out.items.single.anchorDate, d('2020-01-15'));
    });

    // One typo must not cost the user the other forty rows. An unreadable enum
    // takes the same fallback the row mappers give it.
    test('an unrecognised enum falls back rather than throwing', () {
      final out = BackupCodec.decode('''
{"format": "subdock.backup", "version": 1,
 "items": [{"id": "n", "name": "N", "categoryId": "S",
            "expiresOn": "2026-09-01", "state": "SOMETHING_ELSE",
            "dateSource": "??", "purchaseChannel": "??"}]}
''');
      final item = out.items.single;

      expect(item.state, ItemState.active);
      expect(item.dateSource, DateSource.userEstimated);
      expect(item.purchaseChannel, PurchaseChannel.unknown);
    });

    // An item with no date is not an item. Everything else has a blank that
    // means something; this does not.
    test('an item with no date is named in the error', () {
      expect(
        () => BackupCodec.decode('''
{"format": "subdock.backup", "version": 1,
 "items": [{"id": "n", "name": "Netflix", "categoryId": "S"}]}
'''),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            contains('Netflix'),
          ),
        ),
      );
    });
  });

  group('summary', () {
    test('counts what the user is about to overwrite', () {
      expect(full().summary, '1 item, 1 payment, 1 payment source');
    });

    test('says nothing about sources when there are none', () {
      const empty = Backup(
        categories: [],
        sources: [],
        items: [],
        history: [],
        exportedAt: '',
      );
      expect(empty.summary, '0 items, 0 payments');
    });
  });
}
