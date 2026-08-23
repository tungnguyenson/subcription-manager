import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/backup/backup.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  final items = [
    TrackedItem(
      id: 'hsd',
      name: 'Hạn số',
      category: Category.subscription,
      expiresOn: d('2027-02-01'),
      actByOffsetDays: 7,
      anchorDate: d('2027-02-01'),
      dateSource: DateSource.userConfirmed,
      lastVerifiedAt: d('2026-08-15'),
    ),
    TrackedItem(
      id: 'netflix',
      name: 'Netflix',
      category: Category.subscription,
      expiresOn: d('2026-09-01'),
      anchorDate: d('2026-01-01'),
      cycle: Cycle.monthly,
      amountMinor: 231000,
      currency: 'VND',
      actionUrl: 'https://netflix.com/cancelplan',
      actionLabel: 'Hủy Netflix',
      note: 'Hủy phải vào web, trong app không hủy được',
    ),
    TrackedItem(
      id: 'claude',
      name: 'Claude',
      category: Category.subscription,
      expiresOn: d('2026-09-05'),
      anchorDate: d('2026-02-05'),
      cycle: Cycle.monthly,
      amountMinor: 2000,
      currency: 'USD',
    ),
  ];

  final history = [
    HandledEvent(
      id: 'e1',
      itemId: 'claude',
      handledAtEpochSeconds: 1755000000,
      forDueDate: d('2026-08-05'),
      amountMinor: 2000,
      currency: 'USD',
      fxRateScaled: 260460000,
      fxRateScale: 4,
      fxRateDate: d('2026-08-04'),
      fxSource: 'bundled',
      baseAmountMinor: 520920,
      actualChargedMinor: 532745,
    ),
  ];

  BackupFile sampleFile() =>
      Backup.build('2026-08-15T10:00:00Z', items, history);

  // A backup that cannot be restored is not a backup. This is the whole point
  // of the file.
  test('a full round trip carries every record', () {
    final decoded = Backup.decode(Backup.encode(sampleFile()));

    expect(decoded.items.length, 3);
    expect(decoded.history.length, 1);
  });

  test('restored items keep every field that matters', () {
    final decoded = Backup.decode(Backup.encode(sampleFile()));
    final netflix = decoded.items.firstWhere((e) => e.id == 'netflix');

    expect(netflix.name, 'Netflix');
    expect(netflix.cycle, 'MONTHLY');
    expect(netflix.amountMinor, 231000);
    expect(netflix.currency, 'VND');
    expect(netflix.actionUrl, 'https://netflix.com/cancelplan');
    expect(netflix.note, 'Hủy phải vào web, trong app không hủy được');
    expect(netflix.anchorDate, '2026-01-01');
  });

  // Provenance must survive: a date the user confirmed with their provider and
  // one typed from memory cannot come back looking alike.
  test('date provenance survives the round trip', () {
    final decoded = Backup.decode(Backup.encode(sampleFile()));
    final hsd = decoded.items.firstWhere((e) => e.id == 'hsd');

    expect(hsd.dateSource, 'USER_CONFIRMED');
    expect(hsd.lastVerifiedAt, '2026-08-15');
    expect(hsd.actByOffsetDays, 7);
  });

  test('the FX snapshot survives so history stays frozen', () {
    final decoded = Backup.decode(Backup.encode(sampleFile()));
    final event = decoded.history.single;

    expect(event.baseAmountMinor, 520920);
    expect(event.fxSource, 'bundled');
    expect(event.fxRateDate, '2026-08-04');
    expect(event.actualChargedMinor, 532745);
  });

  // An older export has `kind` plus a spend `categoryId` and no `category` at
  // all. Restoring it must not quietly reclassify a passport as a
  // subscription, which is what a bare default would do.
  test('a schema-2 file maps its two old fields onto one category', () {
    String category(Map<String, dynamic> json) =>
        BackupItem.categoryFromJson(json);

    expect(
      category({'kind': 'DOCUMENT', 'categoryId': 'documents'}),
      'DOCUMENT',
    );
    expect(
      category({'kind': 'RECURRING', 'categoryId': 'insurance'}),
      'INSURANCE',
    );
    expect(category({'kind': 'RECURRING', 'categoryId': 'home_bills'}), 'BILL');
    expect(
      category({'kind': 'TRIAL', 'categoryId': 'entertainment'}),
      'SUBSCRIPTION',
    );
    expect(
      category({'kind': 'PREPAID', 'categoryId': 'telecom'}),
      'SUBSCRIPTION',
    );
    expect(
      category({'category': 'INSURANCE', 'kind': 'BILL'}),
      'INSURANCE',
      reason: 'a current file is never re-derived',
    );
    expect(() => category({}), throwsFormatException);
  });

  test('a corrupt file fails rather than restoring garbage', () {
    expect(() => Backup.decode('not json at all'), throwsFormatException);
    expect(() => Backup.decode('{}'), throwsFormatException);
  });

  test('a file from a newer app version is refused with an explanation', () {
    final future = Backup.encode(sampleFile())
        .replaceAll('"schemaVersion": 3', '"schemaVersion": 99');

    expect(
      () => Backup.decode(future),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('from a newer version'),
        ),
      ),
    );
  });

  test('unknown fields are ignored so a newer file still restores', () {
    final withExtra = Backup.encode(sampleFile())
        .replaceFirst('{', '{"futureField": "whatever",');

    expect(Backup.decode(withExtra).items.length, 3);
  });

  group('CSV', () {
    test('has a header and one row per item', () {
      final lines = Backup.toCsv(items).split('\n');
      expect(lines.length, 4);
      expect(lines.first, startsWith('id,name,category'));
    });

    // A spreadsheet would read "231.000" as a decimal and silently divide a
    // Vietnamese amount by a thousand, so amounts stay in minor units.
    test('writes raw minor units with the currency in its own column', () {
      final row = Backup.toCsv(items)
          .split('\n')
          .firstWhere((l) => l.startsWith('netflix'));

      expect(row, contains('231000'));
      expect(row, contains('VND'));
      expect(
        row,
        isNot(contains('231.000')),
        reason: 'must not be pre-formatted',
      );
    });

    test('escapes commas and quotes', () {
      final tricky = [
        TrackedItem(
          id: 'x',
          name: 'Netflix, "Premium" plan',
          category: Category.subscription,
          expiresOn: d('2026-09-01'),
          anchorDate: d('2026-09-01'),
        ),
      ];
      final row = Backup.toCsv(tricky).split('\n').last;
      expect(row, contains('"Netflix, ""Premium"" plan"'));
    });

    test('an empty export is still valid', () {
      final empty = Backup.build('2026-08-15T10:00:00Z', [], []);
      expect(Backup.decode(Backup.encode(empty)).items, isEmpty);
      expect(Backup.toCsv([]).split('\n').length, 1, reason: 'header only');
    });
  });
}
