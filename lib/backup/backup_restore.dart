import 'package:meta/meta.dart';
import 'package:subdock/backup/backup.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';

/// Writes a decoded backup back into storage.
///
/// A backup that cannot be restored is not a backup, so this path has tests
/// rather than just existing. Restores in one transaction: a half-restored
/// database, with items whose group rows never arrived, is worse than a failed
/// restore.
class BackupRestore {
  final ItemRepository _repo;

  BackupRestore(this._repo);

  Future<RestoreReport> restore(BackupFile file, int nowEpochSeconds) async {
    var items = 0;
    var events = 0;
    final skipped = <String>[];

    await _repo.transaction(() async {
      for (final row in file.items) {
        try {
          await _repo.upsert(_itemOf(row), nowEpochSeconds);
          items++;
        } on Exception catch (e) {
          skipped.add('item ${row.id}: $e');
        }
      }

      for (final row in file.history) {
        try {
          await _repo.recordHandled(_eventOf(row));
          events++;
        } on Exception catch (e) {
          skipped.add('history ${row.id}: $e');
        }
      }
    });

    return RestoreReport(
      items: items,
      events: events,
      skipped: List.unmodifiable(skipped),
    );
  }

  TrackedItem _itemOf(BackupItem row) {
    return TrackedItem(
      id: row.id,
      name: row.name,
      categoryId: row.category,
      iconName: row.iconName,
      expiresOn: LocalDate.parse(row.expiresOn),
      actByOffsetDays: row.actByOffsetDays,
      anchorDate: LocalDate.parse(row.anchorDate),
      cycle: CycleWire.fromWire(row.cycle),
      repeatCount: row.repeatCount,
      amountMinor: row.amountMinor,
      currency: row.currency,
      actionUrl: row.actionUrl,
      actionLabel: row.actionLabel,
      note: row.note,
      leadDays: row.leadDays,
      remindAt: LocalTime.parse(row.remindAt),
      nagAfterDue: enumFromWire(
        NagPolicy.values,
        row.nagAfterDue,
        NagPolicy.none,
      ),
      verifyEveryDays: row.verifyEveryDays,
      lastVerifiedAt: row.lastVerifiedAt == null
          ? null
          : LocalDate.parse(row.lastVerifiedAt!),
      dateSource: enumFromWire(
        DateSource.values,
        row.dateSource,
        DateSource.userEstimated,
      ),
      snoozedUntil: row.snoozedUntil == null
          ? null
          : LocalDate.parse(row.snoozedUntil!),
      state: enumFromWire(ItemState.values, row.state, ItemState.active),
      purchaseChannel: enumFromWire(
        PurchaseChannel.values,
        row.purchaseChannel,
        PurchaseChannel.unknown,
      ),
    );
  }

  HandledEvent _eventOf(BackupEvent row) => HandledEvent(
    id: row.id,
    itemId: row.itemId,
    handledAtEpochSeconds: row.handledAt,
    forDueDate: LocalDate.parse(row.forDueDate),
    amountMinor: row.amountMinor,
    currency: row.currency,
    fxRateScaled: row.fxRateScaled,
    fxRateScale: row.fxRateScale,
    fxRateDate: row.fxRateDate == null
        ? null
        : LocalDate.parse(row.fxRateDate!),
    fxSource: row.fxSource,
    baseAmountMinor: row.baseAmountMinor,
    actualChargedMinor: row.actualChargedMinor,
  );
}

/// Reports what was skipped rather than failing silently on a partial file.
@immutable
class RestoreReport {
  final int items;
  final int events;
  final List<String> skipped;

  const RestoreReport({
    required this.items,
    required this.events,
    required this.skipped,
  });

  bool get isClean => skipped.isEmpty;
}
