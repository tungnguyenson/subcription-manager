import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/backup/backup.dart';
import 'package:subdock/backup/backup_restore.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';

void main() {
  late SubdockDatabase db;
  late ItemRepository repo;

  LocalDate d(String iso) => LocalDate.parse(iso);

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    repo = ItemRepository(db);
  });

  tearDown(() => db.close());

  BackupFile sampleFile() => Backup.build(
    '2026-08-15T10:00:00Z',
    [
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
        note: 'Hủy phải vào web',
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
    ],
    [
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
    ],
  );

  test('a full round trip restores every record', () async {
    final decoded = Backup.decode(Backup.encode(sampleFile()));
    final report = await BackupRestore(repo).restore(decoded, 1755000100);

    expect(report.isClean, isTrue, reason: 'skipped: ${report.skipped}');
    expect(report.items, 3);
    expect(report.events, 1);
    expect((await repo.observeAll().first).length, 3);
  });

  test('restored items keep every field that matters', () async {
    await BackupRestore(repo)
        .restore(Backup.decode(Backup.encode(sampleFile())), 1);

    final netflix = await repo.findById('netflix');
    expect(netflix?.name, 'Netflix');
    expect(netflix?.cycle, Cycle.monthly);
    expect(netflix?.amountMinor, 231000);
    expect(netflix?.currency, 'VND');
    expect(netflix?.note, 'Hủy phải vào web');
    expect(netflix?.anchorDate, d('2026-01-01'));
  });

  // Provenance must survive: a date the user confirmed with their provider and
  // one typed from memory cannot come back looking alike.
  test('date provenance survives the restore', () async {
    await BackupRestore(repo)
        .restore(Backup.decode(Backup.encode(sampleFile())), 1);

    final hsd = await repo.findById('hsd');
    expect(hsd?.dateSource, DateSource.userConfirmed);
    expect(hsd?.lastVerifiedAt, d('2026-08-15'));
    expect(hsd?.actByOffsetDays, 7);
  });

  test('the FX snapshot survives so history stays frozen', () async {
    await BackupRestore(repo)
        .restore(Backup.decode(Backup.encode(sampleFile())), 1);

    final event = (await repo.observeHistory('claude').first).single;
    expect(event.baseAmountMinor, 520920);
    expect(event.fxSource, 'bundled');
    expect(event.fxRateDate, d('2026-08-04'));
    expect(event.actualChargedMinor, 532745);
  });

  // A restore that silently drops a row is worse than one that fails: the user
  // believes their data came back.
  test('a partial file restores what it can and reports the rest', () async {
    final good = sampleFile();
    final broken = good.copyWith(
      items: [
        ...good.items,
        good.items.first.copyWith(id: 'bad', expiresOn: 'not-a-date'),
      ],
    );

    final report = await BackupRestore(repo).restore(broken, 1);

    expect(report.items, 3, reason: 'the good rows still land');
    expect(report.skipped, isNotEmpty, reason: 'the bad row must be reported');
    expect(report.isClean, isFalse);
  });
}
