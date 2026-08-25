import 'package:drift/drift.dart';

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

extension CategoryRowMapper on CategoryRowData {
  Category toDomain() => Category(
    id: id,
    label: label,
    iconName: iconName,
    // An unrecognised wording reads as money owed, which is what all but three
    // shipped shelves are. Being told a payment is due when nothing will be
    // taken is a wasted glance; being told nothing when a passport lapses is
    // the failure the app exists to prevent.
    wording: enumFromWire(CategoryWording.values, wording, CategoryWording.due),
    // An unrecognised nag policy stays quiet rather than nagging daily. A shelf
    // written by a newer build must not turn into an alarm on an older one.
    nag: enumFromWire(NagPolicy.values, nag, NagPolicy.none),
    leadDays: decodeLeadDays(leadDays),
    verifyEveryDays: verifyEveryDays,
    countsTowardSpend: countsTowardSpend,
    builtIn: builtIn,
    sortOrder: sortOrder,
  );
}

extension CategoryToRow on Category {
  CategoryRowCompanion toCompanion() => CategoryRowCompanion(
    id: Value(id),
    label: Value(label),
    iconName: Value(iconName),
    wording: Value(wording.wireName),
    nag: Value(nag.wireName),
    leadDays: Value(encodeLeadDays(leadDays)),
    verifyEveryDays: Value(verifyEveryDays),
    countsTowardSpend: Value(countsTowardSpend),
    builtIn: Value(builtIn),
    sortOrder: Value(sortOrder),
  );
}

extension ItemRowMapper on ItemRowData {
  TrackedItem toDomain() => TrackedItem(
    id: id,
    name: name,
    categoryId: category,
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
    inTrial: inTrial,
    paymentSourceId: paymentSourceId,
    paused: paused,
    // Undecided is the safe fallback: an unrecognised value shows the
    // suggestion again, which is a mild annoyance. Falling back to `skipped`
    // would silently hide money the user could save.
    yearlyChoice: enumFromWire(
      YearlyChoice.values,
      yearlyChoice,
      YearlyChoice.undecided,
    ),
  );
}

extension PaymentSourceRowMapper on PaymentSourceRowData {
  PaymentSource toDomain() => PaymentSource(
    id: id,
    name: name,
    // An unrecognised glyph draws a card rather than nothing. The name is what
    // identifies the source; the mark is decoration, and a blank square beside
    // a name reads as a bug.
    glyph: enumFromWire(SourceGlyph.values, glyph, SourceGlyph.card),
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
