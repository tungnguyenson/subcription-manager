package space.denhan.backup

import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import space.denhan.data.ItemRepository
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
 * Writes a decoded backup back into storage.
 *
 * A backup that cannot be restored is not a backup, so this path has tests
 * rather than just existing. Restores in one transaction: a half-restored
 * database, with items whose group rows never arrived, is worse than a failed
 * restore.
 */
class BackupRestore(private val repo: ItemRepository) {

    fun restore(file: BackupFile, nowEpochSeconds: Long): RestoreReport {
        var items = 0
        var groups = 0
        var sims = 0
        var events = 0
        val skipped = mutableListOf<String>()

        repo.transaction {
            // Groups first: items reference them.
            file.groups.forEach { row ->
                runCatching { repo.upsertGroup(row.toDomain()) }
                    .onSuccess { groups++ }
                    .onFailure { skipped += "nhóm ${row.id}: ${it.message}" }
            }

            file.items.forEach { row ->
                runCatching { repo.upsert(row.toDomain(), nowEpochSeconds) }
                    .onSuccess { items++ }
                    .onFailure { skipped += "mục ${row.id}: ${it.message}" }
            }

            file.sims.forEach { row ->
                runCatching { repo.upsertSim(row.toDomain()) }
                    .onSuccess { sims++ }
                    .onFailure { skipped += "SIM ${row.groupId}: ${it.message}" }
            }

            file.history.forEach { row ->
                runCatching { repo.recordHandled(row.toDomain()) }
                    .onSuccess { events++ }
                    .onFailure { skipped += "lịch sử ${row.id}: ${it.message}" }
            }
        }

        return RestoreReport(items, groups, sims, events, skipped)
    }
}

/** Reports what was skipped rather than failing silently on a partial file. */
data class RestoreReport(
    val items: Int,
    val groups: Int,
    val sims: Int,
    val events: Int,
    val skipped: List<String>,
) {
    val isClean: Boolean get() = skipped.isEmpty()
}

private inline fun <reified T : Enum<T>> String.toEnumOr(fallback: T): T =
    enumValues<T>().firstOrNull { it.name == this } ?: fallback

private fun BackupGroup.toDomain() = ItemGroup(id, name, kind.toEnumOr(GroupKind.OTHER))

private fun BackupItem.toDomain(): TrackedItem {
    val itemKind = kind.toEnumOr(Kind.RECURRING)
    return TrackedItem(
        id = id,
        name = name,
        groupId = groupId,
        kind = itemKind,
        stake = stake.toEnumOr(Stake.INFO),
        categoryId = categoryId,
        expiresOn = LocalDate.parse(expiresOn),
        actByOffsetDays = actByOffsetDays,
        anchorDate = LocalDate.parse(anchorDate),
        cycle = cycle?.let { c -> Cycle.entries.firstOrNull { it.name == c } },
        amountMinor = amountMinor,
        currency = currency,
        actionUrl = actionUrl,
        actionLabel = actionLabel,
        note = note,
        leadDays = leadDays,
        remindAt = LocalTime.parse(remindAt),
        nagAfterDue = nagAfterDue.toEnumOr(NagPolicy.NONE),
        verifyEveryDays = verifyEveryDays,
        lastVerifiedAt = lastVerifiedAt?.let { LocalDate.parse(it) },
        dateSource = dateSource.toEnumOr(DateSource.USER_ESTIMATED),
        state = state.toEnumOr(ItemState.ACTIVE),
    )
}

private fun BackupSim.toDomain() = SimProfile(
    groupId = groupId,
    carrier = carrier.toEnumOr(Carrier.OTHER),
    msisdn = msisdn,
    isDormant = isDormant,
    hsdConfirmedDate = hsdConfirmedDate?.let { LocalDate.parse(it) },
    hsdConfirmedAt = hsdConfirmedAt?.let { LocalDate.parse(it) },
    // Never restores as YES on an unrecognised value.
    identityVerified = identityVerified.toEnumOr(TriState.UNKNOWN),
    identityCheckedAt = identityCheckedAt?.let { LocalDate.parse(it) },
    lastDeviceChangeAt = lastDeviceChangeAt?.let { LocalDate.parse(it) },
    retentionPackage = retentionPackage,
    retentionExpiryDate = retentionExpiryDate?.let { LocalDate.parse(it) },
)

private fun BackupEvent.toDomain() = HandledEvent(
    id = id,
    itemId = itemId,
    handledAtEpochSeconds = handledAt,
    forDueDate = LocalDate.parse(forDueDate),
    amountMinor = amountMinor,
    currency = currency,
    fxRateScaled = fxRateScaled,
    fxRateScale = fxRateScale,
    fxRateDate = fxRateDate?.let { LocalDate.parse(it) },
    fxSource = fxSource,
    baseAmountMinor = baseAmountMinor,
    actualChargedMinor = actualChargedMinor,
)
