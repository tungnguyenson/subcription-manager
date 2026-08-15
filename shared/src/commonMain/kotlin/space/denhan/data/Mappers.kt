package space.denhan.data

import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import space.denhan.db.HandledEventRow
import space.denhan.db.ItemRow
import space.denhan.db.ItemGroupRow
import space.denhan.db.SimProfileRow
import space.denhan.domain.Carrier
import space.denhan.domain.Cycle
import space.denhan.domain.DateSource
import space.denhan.domain.GroupKind
import space.denhan.domain.HandledEvent
import space.denhan.domain.ItemGroup
import space.denhan.domain.ItemState
import space.denhan.domain.Kind
import space.denhan.domain.NagPolicy
import space.denhan.domain.SimProfile
import space.denhan.domain.Stake
import space.denhan.domain.TrackedItem
import space.denhan.domain.TriState

/**
 * Row-to-model conversion.
 *
 * Enums are stored as their names rather than ordinals so that reordering an
 * enum cannot silently reinterpret existing rows, and so the database stays
 * legible in a sqlite3 shell. Unknown values fall back to a safe default rather
 * than throwing: a row written by a newer build must not crash an older one.
 */

private inline fun <reified T : Enum<T>> String.toEnumOr(fallback: T): T =
    enumValues<T>().firstOrNull { it.name == this } ?: fallback

private fun String.toDate(): LocalDate = LocalDate.parse(this)
private fun String?.toDateOrNull(): LocalDate? = this?.let { LocalDate.parse(it) }

private fun String.toLeadDays(): List<Int> =
    if (isBlank()) emptyList() else split(',').mapNotNull { it.trim().toIntOrNull() }

private fun List<Int>.encodeLeadDays(): String = joinToString(",")

fun ItemRow.toDomain() = TrackedItem(
    id = id,
    name = name,
    groupId = groupId,
    kind = kind.toEnumOr(Kind.RECURRING),
    stake = stake.toEnumOr(Stake.INFO),
    categoryId = categoryId,
    expiresOn = expiresOn.toDate(),
    actByOffsetDays = actByOffsetDays.toInt(),
    anchorDate = anchorDate.toDate(),
    cycle = cycle?.let { c -> Cycle.entries.firstOrNull { it.name == c } },
    amountMinor = amountMinor,
    currency = currency,
    actionUrl = actionUrl,
    actionLabel = actionLabel,
    note = note,
    leadDays = leadDays.toLeadDays(),
    remindAt = LocalTime.parse(remindAt),
    nagAfterDue = nagAfterDue.toEnumOr(NagPolicy.NONE),
    verifyEveryDays = verifyEveryDays?.toInt(),
    lastVerifiedAt = lastVerifiedAt.toDateOrNull(),
    // An unrecognised source must read as less trustworthy, not more.
    dateSource = dateSource.toEnumOr(DateSource.USER_ESTIMATED),
    state = state.toEnumOr(ItemState.ACTIVE),
)

fun ItemGroupRow.toDomain() = ItemGroup(
    id = id,
    name = name,
    kind = kind.toEnumOr(GroupKind.OTHER),
)

fun SimProfileRow.toDomain() = SimProfile(
    groupId = groupId,
    carrier = carrier.toEnumOr(Carrier.OTHER),
    msisdn = msisdn,
    isDormant = isDormant != 0L,
    hsdConfirmedDate = hsdConfirmedDate.toDateOrNull(),
    hsdConfirmedAt = hsdConfirmedAt.toDateOrNull(),
    // Anything unrecognised means "we have not established this", never YES.
    identityVerified = identityVerified.toEnumOr(TriState.UNKNOWN),
    identityCheckedAt = identityCheckedAt.toDateOrNull(),
    lastDeviceChangeAt = lastDeviceChangeAt.toDateOrNull(),
    retentionPackage = retentionPackage,
    retentionExpiryDate = retentionExpiryDate.toDateOrNull(),
)

fun HandledEventRow.toDomain() = HandledEvent(
    id = id,
    itemId = itemId,
    handledAtEpochSeconds = handledAt,
    forDueDate = forDueDate.toDate(),
    amountMinor = amountMinor,
    currency = currency,
    fxRateScaled = fxRateScaled,
    fxRateScale = fxRateScale?.toInt(),
    fxRateDate = fxRateDate.toDateOrNull(),
    fxSource = fxSource,
    baseAmountMinor = baseAmountMinor,
    actualChargedMinor = actualChargedMinor,
)

internal fun TrackedItem.encodedLeadDays() = leadDays.encodeLeadDays()
