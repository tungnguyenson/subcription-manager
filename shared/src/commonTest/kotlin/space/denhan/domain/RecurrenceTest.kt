package space.denhan.domain

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class RecurrenceTest {

    private fun d(iso: String) = LocalDate.parse(iso)

    // The bug this whole file exists for. Adding a month at a time from 31 Jan
    // permanently loses the 31st; anchoring does not.
    @Test
    fun `monthly from the 31st returns to the 31st instead of drifting`() {
        val anchor = d("2026-01-31")

        assertEquals(d("2026-02-28"), Recurrence.occurrenceAfter(anchor, Cycle.MONTHLY, 1))
        assertEquals(d("2026-03-31"), Recurrence.occurrenceAfter(anchor, Cycle.MONTHLY, 2))
        assertEquals(d("2026-04-30"), Recurrence.occurrenceAfter(anchor, Cycle.MONTHLY, 3))
        assertEquals(d("2026-05-31"), Recurrence.occurrenceAfter(anchor, Cycle.MONTHLY, 4))
    }

    @Test
    fun `accumulating one month at a time is what we must not do`() {
        // Documents the wrong approach so the difference stays visible.
        var drifting = d("2026-01-31")
        repeat(4) { drifting = drifting.plus(1, DateTimeUnit.MONTH) }

        assertEquals(d("2026-05-28"), drifting, "accumulation loses the 31st")
        assertEquals(
            d("2026-05-31"),
            Recurrence.occurrenceAfter(d("2026-01-31"), Cycle.MONTHLY, 4),
            "anchoring keeps it",
        )
    }

    @Test
    fun `29 February resolves in a leap year and clamps otherwise`() {
        assertEquals(d("2028-02-29"), Recurrence.occurrenceAfter(d("2024-02-29"), Cycle.YEARLY, 4))
        assertEquals(d("2025-02-28"), Recurrence.occurrenceAfter(d("2024-02-29"), Cycle.YEARLY, 1))
    }

    @Test
    fun `occurrence zero is the anchor itself`() {
        val anchor = d("2026-08-15")
        assertEquals(anchor, Recurrence.occurrenceAfter(anchor, Cycle.MONTHLY, 0))
    }

    @Test
    fun `weekly steps seven days`() {
        assertEquals(d("2026-08-29"), Recurrence.occurrenceAfter(d("2026-08-15"), Cycle.WEEKLY, 2))
    }

    @Test
    fun `quarterly and yearly step the right number of months`() {
        val anchor = d("2026-01-15")
        assertEquals(d("2026-04-15"), Recurrence.occurrenceAfter(anchor, Cycle.QUARTERLY, 1))
        assertEquals(d("2026-07-15"), Recurrence.occurrenceAfter(anchor, Cycle.SEMIANNUAL, 1))
        assertEquals(d("2027-01-15"), Recurrence.occurrenceAfter(anchor, Cycle.YEARLY, 1))
    }

    @Test
    fun `cyclesElapsed counts whole cycles only`() {
        val anchor = d("2026-01-15")
        assertEquals(0, Recurrence.cyclesElapsed(anchor, Cycle.MONTHLY, d("2026-01-15")))
        assertEquals(0, Recurrence.cyclesElapsed(anchor, Cycle.MONTHLY, d("2026-02-14")))
        assertEquals(1, Recurrence.cyclesElapsed(anchor, Cycle.MONTHLY, d("2026-02-15")))
        assertEquals(7, Recurrence.cyclesElapsed(anchor, Cycle.MONTHLY, d("2026-08-15")))
    }

    @Test
    fun `cyclesElapsed is zero before the anchor`() {
        assertEquals(0, Recurrence.cyclesElapsed(d("2026-08-15"), Cycle.MONTHLY, d("2025-01-01")))
    }

    @Test
    fun `nextDue returns the anchor while it is still ahead`() {
        assertEquals(
            d("2026-09-01"),
            Recurrence.nextDue(d("2026-09-01"), Cycle.MONTHLY, d("2026-08-15")),
        )
    }

    @Test
    fun `nextDue steps past today for a running cycle`() {
        assertEquals(
            d("2026-09-15"),
            Recurrence.nextDue(d("2026-01-15"), Cycle.MONTHLY, d("2026-08-15")),
        )
    }

    @Test
    fun `nextDue on the due date itself moves to the following cycle`() {
        assertEquals(
            d("2026-09-15"),
            Recurrence.nextDue(d("2026-01-15"), Cycle.MONTHLY, d("2026-08-15")),
        )
    }

    @Test
    fun `nextDue for a one-off is null once it has passed`() {
        assertNull(Recurrence.nextDue(d("2026-01-01"), null, d("2026-08-15")))
        assertEquals(d("2026-12-01"), Recurrence.nextDue(d("2026-12-01"), null, d("2026-08-15")))
    }

    @Test
    fun `actBy subtracts the lead so the deadline is actionable`() {
        assertEquals(d("2026-08-08"), Recurrence.actBy(d("2026-08-15"), 7))
        assertEquals(d("2026-08-15"), Recurrence.actBy(d("2026-08-15"), 0))
    }

    @Test
    fun `actBy crosses a month boundary correctly`() {
        assertEquals(d("2026-07-31"), Recurrence.actBy(d("2026-08-01"), 1))
    }
}
