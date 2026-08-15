package space.denhan.backup

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import space.denhan.data.DriverFactory
import space.denhan.data.ItemRepository
import space.denhan.data.createDatabase
import space.denhan.domain.Carrier
import space.denhan.domain.Cycle
import space.denhan.domain.DateSource
import space.denhan.domain.GroupKind
import space.denhan.domain.HandledEvent
import space.denhan.domain.ItemGroup
import space.denhan.domain.Kind
import space.denhan.domain.SimProfile
import space.denhan.domain.TrackedItem
import space.denhan.domain.TriState
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class BackupTest {

    private fun d(iso: String) = LocalDate.parse(iso)
    private fun repo() = ItemRepository(createDatabase(DriverFactory()), Dispatchers.Default)

    private val group = ItemGroup("sim1", "SIM Viettel 0912 345 678", GroupKind.SIM)

    private val sim = SimProfile(
        groupId = "sim1",
        carrier = Carrier.VIETTEL,
        msisdn = "0912345678",
        isDormant = true,
        hsdConfirmedDate = d("2027-02-01"),
        hsdConfirmedAt = d("2026-08-15"),
        identityVerified = TriState.NO,
        retentionPackage = "VTVANG",
    )

    private val items = listOf(
        TrackedItem(
            id = "hsd", name = "Hạn số", groupId = "sim1", kind = Kind.PREPAID_SIM,
            expiresOn = d("2027-02-01"), actByOffsetDays = 7, anchorDate = d("2027-02-01"),
            dateSource = DateSource.USER_CONFIRMED, lastVerifiedAt = d("2026-08-15"),
        ),
        TrackedItem(
            id = "netflix", name = "Netflix", kind = Kind.RECURRING,
            expiresOn = d("2026-09-01"), anchorDate = d("2026-01-01"), cycle = Cycle.MONTHLY,
            amountMinor = 231_000, currency = "VND",
            actionUrl = "https://netflix.com/cancelplan", actionLabel = "Hủy Netflix",
            note = "Hủy phải vào web, trong app không hủy được",
        ),
        TrackedItem(
            id = "claude", name = "Claude", kind = Kind.RECURRING,
            expiresOn = d("2026-09-05"), anchorDate = d("2026-02-05"), cycle = Cycle.MONTHLY,
            amountMinor = 2000, currency = "USD",
        ),
    )

    private val history = listOf(
        HandledEvent(
            id = "e1", itemId = "claude", handledAtEpochSeconds = 1_755_000_000,
            forDueDate = d("2026-08-05"),
            amountMinor = 2000, currency = "USD",
            fxRateScaled = 260_460_000, fxRateScale = 4,
            fxRateDate = d("2026-08-04"), fxSource = "bundled",
            baseAmountMinor = 520_920, actualChargedMinor = 532_745,
        ),
    )

    private fun sampleFile() = Backup.build("2026-08-15T10:00:00Z", items, listOf(group), listOf(sim), history)

    // A backup that cannot be restored is not a backup. This is the whole point
    // of the file.
    @Test
    fun `a full round trip restores every record`() = runTest {
        val encoded = Backup.encode(sampleFile())
        val decoded = Backup.decode(encoded).getOrThrow()

        val target = repo()
        val report = BackupRestore(target).restore(decoded, nowEpochSeconds = 1_755_000_100)

        assertTrue(report.isClean, "skipped: ${report.skipped}")
        assertEquals(3, report.items)
        assertEquals(1, report.groups)
        assertEquals(1, report.sims)
        assertEquals(1, report.events)

        assertEquals(3, target.observeAll().first().size)
    }

    @Test
    fun `restored items keep every field that matters`() = runTest {
        val target = repo()
        BackupRestore(target).restore(Backup.decode(Backup.encode(sampleFile())).getOrThrow(), 1)

        val netflix = target.observeById("netflix").first()!!
        assertEquals("Netflix", netflix.name)
        assertEquals(Cycle.MONTHLY, netflix.cycle)
        assertEquals(231_000, netflix.amountMinor)
        assertEquals("VND", netflix.currency)
        assertEquals("https://netflix.com/cancelplan", netflix.actionUrl)
        assertEquals("Hủy phải vào web, trong app không hủy được", netflix.note)
        assertEquals(d("2026-01-01"), netflix.anchorDate)
    }

    // Provenance must survive: a date the user confirmed with their carrier and
    // one typed from memory cannot come back looking alike.
    @Test
    fun `date provenance survives the round trip`() = runTest {
        val target = repo()
        BackupRestore(target).restore(Backup.decode(Backup.encode(sampleFile())).getOrThrow(), 1)

        val hsd = target.observeById("hsd").first()!!
        assertEquals(DateSource.USER_CONFIRMED, hsd.dateSource)
        assertEquals(d("2026-08-15"), hsd.lastVerifiedAt)
        assertEquals(7, hsd.actByOffsetDays)
    }

    @Test
    fun `the FX snapshot survives so history stays frozen`() = runTest {
        val target = repo()
        BackupRestore(target).restore(Backup.decode(Backup.encode(sampleFile())).getOrThrow(), 1)

        val event = target.observeHistory("claude").first().single()
        assertEquals(520_920, event.baseAmountMinor)
        assertEquals("bundled", event.fxSource)
        assertEquals(d("2026-08-04"), event.fxRateDate)
        assertEquals(532_745, event.actualChargedMinor)
    }

    @Test
    fun `SIM state including the three clocks survives`() = runTest {
        val target = repo()
        BackupRestore(target).restore(Backup.decode(Backup.encode(sampleFile())).getOrThrow(), 1)

        val restored = target.observeSims().first().single()
        assertEquals(Carrier.VIETTEL, restored.carrier)
        assertTrue(restored.isDormant)
        assertEquals(d("2027-02-01"), restored.hsdConfirmedDate)
        assertEquals(d("2026-08-15"), restored.hsdConfirmedAt)
        assertEquals(TriState.NO, restored.identityVerified)
        assertEquals("VTVANG", restored.retentionPackage)
    }

    @Test
    fun `an unrecognised identity value restores as unknown, never as verified`() = runTest {
        val file = sampleFile().let { it.copy(sims = it.sims.map { s -> s.copy(identityVerified = "MAYBE") }) }
        val target = repo()
        BackupRestore(target).restore(file, 1)

        assertEquals(TriState.UNKNOWN, target.observeSims().first().single().identityVerified)
    }

    @Test
    fun `a corrupt file fails rather than restoring garbage`() {
        assertTrue(Backup.decode("not json at all").isFailure)
        assertTrue(Backup.decode("{}").isFailure)
    }

    @Test
    fun `a file from a newer app version is refused with an explanation`() {
        val future = Backup.encode(sampleFile()).replace("\"schemaVersion\": 1", "\"schemaVersion\": 99")
        val result = Backup.decode(future)

        assertTrue(result.isFailure)
        assertContains(result.exceptionOrNull()?.message.orEmpty(), "phiên bản mới hơn")
    }

    @Test
    fun `unknown fields are ignored so a newer file still restores`() {
        val withExtra = Backup.encode(sampleFile()).replaceFirst("{", """{"futureField": "whatever",""")
        assertTrue(Backup.decode(withExtra).isSuccess)
    }

    @Test
    fun `a partial file restores what it can and reports the rest`() = runTest {
        val broken = sampleFile().let {
            it.copy(items = it.items + it.items.first().copy(id = "bad", expiresOn = "not-a-date"))
        }
        val target = repo()
        val report = BackupRestore(target).restore(broken, 1)

        assertEquals(3, report.items, "the good rows still land")
        assertTrue(report.skipped.isNotEmpty(), "the bad row must be reported, not swallowed")
        assertTrue(!report.isClean)
    }

    // ---- CSV ----

    @Test
    fun `CSV has a header and one row per item`() {
        val lines = Backup.toCsv(items).lines()
        assertEquals(4, lines.size)
        assertTrue(lines.first().startsWith("id,name,group_id"))
    }

    // A spreadsheet would read "231.000" as a decimal and silently divide a
    // Vietnamese amount by a thousand, so amounts stay in minor units.
    @Test
    fun `CSV writes raw minor units with the currency in its own column`() {
        val netflixRow = Backup.toCsv(items).lines().first { it.startsWith("netflix") }
        assertContains(netflixRow, "231000")
        assertContains(netflixRow, "VND")
        assertTrue(!netflixRow.contains("231.000"), "must not be pre-formatted")
    }

    @Test
    fun `CSV escapes commas and quotes`() {
        val tricky = listOf(
            items[1].copy(id = "x", name = """Netflix, "Premium" plan"""),
        )
        val row = Backup.toCsv(tricky).lines().last()
        assertContains(row, """"Netflix, ""Premium"" plan"""")
    }

    @Test
    fun `an empty export is still valid`() {
        val empty = Backup.build("2026-08-15T10:00:00Z", emptyList(), emptyList(), emptyList(), emptyList())
        assertTrue(Backup.decode(Backup.encode(empty)).isSuccess)
        assertEquals(1, Backup.toCsv(emptyList()).lines().size, "header only")
    }
}
