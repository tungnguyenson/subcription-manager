package space.denhan.data

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import app.cash.sqldelight.coroutines.mapToOneOrNull
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.datetime.LocalDate
import space.denhan.db.DenHanDb
import space.denhan.domain.DateSource
import space.denhan.domain.HandledEvent
import space.denhan.domain.ItemGroup
import space.denhan.domain.ItemState
import space.denhan.domain.TrackedItem

/**
 * The single way the rest of the app reaches storage.
 *
 * Reads come back as Flow so a UI layer can collect them directly; writes are
 * suspend and go through the same dispatcher.
 */
class ItemRepository(
    private val db: DenHanDb,
    private val io: CoroutineDispatcher,
) {
    private val items = db.itemQueries
    private val history = db.historyQueries

    // ---- items ----

    fun observeAll(): Flow<List<TrackedItem>> =
        items.selectAll().asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    fun observeActive(): Flow<List<TrackedItem>> =
        items.selectActive().asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    fun observeById(id: String): Flow<TrackedItem?> =
        items.selectById(id).asFlow().mapToOneOrNull(io).map { it?.toDomain() }

    fun observeByGroup(groupId: String): Flow<List<TrackedItem>> =
        items.selectByGroup(groupId).asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    fun upsert(item: TrackedItem, createdAtEpochSeconds: Long) {
        items.upsert(
            id = item.id,
            name = item.name,
            groupId = item.groupId,
            kind = item.kind.name,
            stake = item.stake.name,
            categoryId = item.categoryId,
            expiresOn = item.expiresOn.toString(),
            actByOffsetDays = item.actByOffsetDays.toLong(),
            anchorDate = item.anchorDate.toString(),
            cycle = item.cycle?.name,
            amountMinor = item.amountMinor,
            currency = item.currency,
            actionUrl = item.actionUrl,
            actionLabel = item.actionLabel,
            note = item.note,
            leadDays = item.encodedLeadDays(),
            remindAt = item.remindAt.toString(),
            nagAfterDue = item.nagAfterDue.name,
            verifyEveryDays = item.verifyEveryDays?.toLong(),
            lastVerifiedAt = item.lastVerifiedAt?.toString(),
            dateSource = item.dateSource.name,
            state = item.state.name,
            createdAt = createdAtEpochSeconds,
        )
    }

    fun setState(id: String, state: ItemState) = items.updateState(state.name, id)

    /**
     * Records a new expiry together with where it came from. Provenance is not
     * optional: a date the user confirmed with their carrier and one they typed
     * from memory must not look alike downstream.
     */
    fun setExpiry(id: String, expiresOn: LocalDate, source: DateSource) =
        items.updateExpiry(expiresOn.toString(), source.name, id)

    fun markVerified(id: String, on: LocalDate) = items.markVerified(on.toString(), id)

    fun delete(id: String) = items.deleteById(id)

    // ---- groups ----

    fun observeGroups(): Flow<List<ItemGroup>> =
        items.selectAllGroups().asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    fun upsertGroup(group: ItemGroup) = items.upsertGroup(group.id, group.name, group.kind.name)

    fun deleteGroup(id: String) = items.deleteGroup(id)

    // ---- history ----

    fun observeHistory(itemId: String): Flow<List<HandledEvent>> =
        history.selectForItem(itemId).asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    fun observeHistorySince(from: LocalDate): Flow<List<HandledEvent>> =
        history.selectSince(from.toString()).asFlow().mapToList(io).map { rows -> rows.map { it.toDomain() } }

    /**
     * Writes one completed occurrence. The FX snapshot on the event is what makes
     * "how much have I spent on this" stable: history reads the stored figure and
     * never recomputes it.
     */
    fun recordHandled(event: HandledEvent) {
        history.insert(
            id = event.id,
            itemId = event.itemId,
            handledAt = event.handledAtEpochSeconds,
            forDueDate = event.forDueDate.toString(),
            amountMinor = event.amountMinor,
            currency = event.currency,
            fxRateScaled = event.fxRateScaled,
            fxRateScale = event.fxRateScale?.toLong(),
            fxRateDate = event.fxRateDate?.toString(),
            fxSource = event.fxSource,
            baseAmountMinor = event.baseAmountMinor,
            actualChargedMinor = event.actualChargedMinor,
        )
    }

    /** The user correcting a figure from their bank statement. */
    fun setActualCharged(eventId: String, minor: Long) = history.setActualCharged(minor, eventId)

    fun transaction(body: () -> Unit) = db.transaction { body() }
}
