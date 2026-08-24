import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';

import 'database.dart';

/// Row-to-model conversion.
///
/// Enums are stored as their wire names rather than ordinals so that reordering
/// an enum cannot silently reinterpret existing rows, and so the database stays
/// legible in a sqlite3 shell. Unknown values fall back to a safe default rather
/// than throwing: a row written by a newer build must not crash an older one.

List<int> decodeLeadDays(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList(growable: false);
}

String encodeLeadDays(List<int> leadDays) => leadDays.join(',');

extension ItemRowMapper on ItemRowData {
  TrackedItem toDomain() => TrackedItem(
    id: id,
    name: name,
    category: enumFromWire(Category.values, category, Category.other),
    iconName: iconName,
    expiresOn: LocalDate.parse(expiresOn),
    actByOffsetDays: actByOffsetDays,
    anchorDate: LocalDate.parse(anchorDate),
    cycle: CycleWire.fromWire(cycle),
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: currency,
    actionUrl: actionUrl,
    actionLabel: actionLabel,
    note: note,
    leadDays: decodeLeadDays(leadDays),
    remindAt: LocalTime.parse(remindAt),
    nagAfterDue: enumFromWire(NagPolicy.values, nagAfterDue, NagPolicy.none),
    verifyEveryDays: verifyEveryDays,
    verifyEveryDaysIsExplicit: true,
    lastVerifiedAt: lastVerifiedAt == null
        ? null
        : LocalDate.parse(lastVerifiedAt!),
    // An unrecognised source must read as less trustworthy, not more.
    dateSource: enumFromWire(
      DateSource.values,
      dateSource,
      DateSource.userEstimated,
    ),
    snoozedUntil: snoozedUntil == null ? null : LocalDate.parse(snoozedUntil!),
    state: enumFromWire(ItemState.values, state, ItemState.active),
    // An unrecognised channel must fall back to "we do not know", never to a
    // guess: pointing someone at the wrong billing page wastes the trip.
    purchaseChannel: enumFromWire(
      PurchaseChannel.values,
      purchaseChannel,
      PurchaseChannel.unknown,
    ),
  );
}

extension HandledEventRowMapper on HandledEventRowData {
  HandledEvent toDomain() => HandledEvent(
    id: id,
    itemId: itemId,
    handledAtEpochSeconds: handledAt,
    forDueDate: LocalDate.parse(forDueDate),
    amountMinor: amountMinor,
    currency: currency,
    fxRateScaled: fxRateScaled,
    fxRateScale: fxRateScale,
    fxRateDate: fxRateDate == null ? null : LocalDate.parse(fxRateDate!),
    fxSource: fxSource,
    baseAmountMinor: baseAmountMinor,
    actualChargedMinor: actualChargedMinor,
  );
}
