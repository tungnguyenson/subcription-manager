package space.denhan.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import space.denhan.domain.Cycle
import space.denhan.domain.DateSource
import space.denhan.domain.HandledEvent
import space.denhan.domain.ItemGroup
import space.denhan.domain.ItemState
import space.denhan.domain.GroupKind
import space.denhan.domain.Kind
import space.denhan.domain.Stake
import space.denhan.domain.TrackedItem
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ItemRepositoryTest {

    private lateinit var repo: ItemRepository

    private fun d(iso: String) = LocalDate.parse(iso)

    @BeforeTest
    fun setUp() {
        repo = ItemRepository(createDatabase(DriverFactory()), Dispatchers.Default)
    }

    private fun sampleItem(
        id: String = "netflix",
        name: String = "Netflix Premium",
        kind: Kind = Kind.RECURRING,
        groupId: String? = null,
        state: ItemState = ItemState.ACTIVE,
    ) = TrackedItem(
        id = id,
        name = name,
        groupId = groupId,
        kind = kind,
        expiresOn = d("2026-09-01"),
        anchorDate = d("2026-01-01"),
        cycle = Cycle.MONTHLY,
        amountMinor = 260_000,
        currency = "VND",
        actionUrl = "https://netflix.com/cancelplan",
        actionLabel = "Hủy Netflix",
        state = state,
    )

    @Test
    fun `an item round-trips through storage unchanged`() = runTest {
        val item = sampleItem()
        repo.upsert(item, createdAtEpochSeconds = 1_755_000_000)

        val loaded = repo.observeById("netflix").first()
        assertNotNull(loaded)
        assertEquals(item.name, loaded.name)
        assertEquals(item.kind, loaded.kind)
        assertEquals(item.expiresOn, loaded.expiresOn)
        assertEquals(item.anchorDate, loaded.anchorDate)
        assertEquals(item.cycle, loaded.cycle)
        assertEquals(item.amountMinor, loaded.amountMinor)
        assertEquals(item.currency, loaded.currency)
        assertEquals(item.actionUrl, loaded.actionUrl)
        assertEquals(item.leadDays, loaded.leadDays)
        assertEquals(item.remindAt, loaded.remindAt)
        assertEquals(item.nagAfterDue, loaded.nagAfterDue)
    }

    @Test
    fun `stake is persisted rather than re-inferred on read`() = runTest {
        // A user override must survive a round trip.
        val overridden = sampleItem().copy(stake = Stake.ASSET)
        repo.upsert(overridden, 1)

        assertEquals(Stake.ASSET, repo.observeById("netflix").first()?.stake)
    }

    @Test
    fun `lead days survive as a list including the empty case`() = runTest {
        repo.upsert(sampleItem(id = "a").copy(leadDays = listOf(30, 14, 7, 3, 1, 0)), 1)
        repo.upsert(sampleItem(id = "b").copy(leadDays = emptyList()), 1)

        assertEquals(listOf(30, 14, 7, 3, 1, 0), repo.observeById("a").first()?.leadDays)
        assertEquals(emptyList(), repo.observeById("b").first()?.leadDays)
    }

    @Test
    fun `only active items appear in the active query`() = runTest {
        repo.upsert(sampleItem(id = "live"), 1)
        repo.upsert(sampleItem(id = "gone", state = ItemState.ARCHIVED), 1)

        assertEquals(listOf("live"), repo.observeActive().first().map { it.id })
        assertEquals(2, repo.observeAll().first().size)
    }

    @Test
    fun `cancelled but still active is a distinct state, not a deletion`() = runTest {
        repo.upsert(sampleItem(), 1)
        repo.setState("netflix", ItemState.CANCELLED_STILL_ACTIVE)

        val loaded = repo.observeById("netflix").first()
        assertEquals(ItemState.CANCELLED_STILL_ACTIVE, loaded?.state)
        assertNotNull(loaded, "the row must still exist")
    }

    @Test
    fun `recording a new expiry also records where it came from`() = runTest {
        repo.upsert(sampleItem(), 1)
        repo.setExpiry("netflix", d("2026-10-01"), DateSource.USER_CONFIRMED)

        val loaded = repo.observeById("netflix").first()
        assertEquals(d("2026-10-01"), loaded?.expiresOn)
        assertEquals(DateSource.USER_CONFIRMED, loaded?.dateSource)
    }

    @Test
    fun `items are grouped so one SIM collapses to a single row upstream`() = runTest {
        repo.upsertGroup(ItemGroup("sim1", "SIM Viettel 0912 345 678", GroupKind.SIM))
        repo.upsert(sampleItem(id = "hsd", name = "Hạn số", kind = Kind.PREPAID, groupId = "sim1"), 1)
        repo.upsert(sampleItem(id = "plan", name = "Gói ST70", kind = Kind.RECURRING, groupId = "sim1"), 1)
        repo.upsert(sampleItem(id = "loose"), 1)

        assertEquals(setOf("hsd", "plan"), repo.observeByGroup("sim1").first().map { it.id }.toSet())
    }

    @Test
    fun `deleting a group leaves its items but detaches them`() = runTest {
        repo.upsertGroup(ItemGroup("sim1", "SIM", GroupKind.SIM))
        repo.upsert(sampleItem(id = "hsd", groupId = "sim1"), 1)
        repo.deleteGroup("sim1")

        val loaded = repo.observeById("hsd").first()
        assertNotNull(loaded, "the item must not vanish with its group")
        assertNull(loaded.groupId)
    }





    @Test
    fun `history stores the FX snapshot so past totals never move`() = runTest {
        repo.upsert(sampleItem(id = "claude", name = "Claude"), 1)
        repo.recordHandled(
            HandledEvent(
                id = "e1",
                itemId = "claude",
                handledAtEpochSeconds = 1_755_000_000,
                forDueDate = d("2026-08-01"),
                amountMinor = 2000,
                currency = "USD",
                fxRateScaled = 260_460_000,
                fxRateScale = 4,
                fxRateDate = d("2026-08-01"),
                fxSource = "bundled",
                baseAmountMinor = 520_920,
            ),
        )

        val event = repo.observeHistory("claude").first().single()
        assertEquals(520_920, event.baseAmountMinor)
        assertEquals("bundled", event.fxSource)
        assertEquals(d("2026-08-01"), event.fxRateDate)
    }

    @Test
    fun `one occurrence cannot be recorded twice`() = runTest {
        repo.upsert(sampleItem(), 1)
        val event = HandledEvent("e1", "netflix", 1, d("2026-08-01"))
        repo.recordHandled(event)
        repo.recordHandled(event.copy(id = "e2"))

        assertEquals(1, repo.observeHistory("netflix").first().size)
    }

    @Test
    fun `the user can correct a figure from their bank statement`() = runTest {
        repo.upsert(sampleItem(id = "claude"), 1)
        repo.recordHandled(
            HandledEvent("e1", "claude", 1, d("2026-08-01"), baseAmountMinor = 520_920),
        )
        // The bank's foreign-currency fee makes the computed figure structurally low.
        repo.setActualCharged("e1", 532_745)

        assertEquals(532_745, repo.observeHistory("claude").first().single().actualChargedMinor)
    }

    @Test
    fun `deleting an item removes its history`() = runTest {
        repo.upsert(sampleItem(), 1)
        repo.recordHandled(HandledEvent("e1", "netflix", 1, d("2026-08-01")))
        repo.delete("netflix")

        assertTrue(repo.observeHistory("netflix").first().isEmpty())
    }

    @Test
    fun `marking verified records the date the user last checked`() = runTest {
        repo.upsert(sampleItem(id = "sim", kind = Kind.PREPAID), 1)
        repo.markVerified("sim", d("2026-08-15"))

        assertEquals(d("2026-08-15"), repo.observeById("sim").first()?.lastVerifiedAt)
    }
}
