package space.denhan.domain

import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class NotificationPlannerTest {

    private val today = LocalDate.parse("2026-08-15")
    private fun d(iso: String) = LocalDate.parse(iso)

    private fun item(
        id: String,
        kind: Kind,
        expiresOn: String,
        name: String = id,
        actByOffsetDays: Int = 0,
        leadDays: List<Int>? = null,
        nag: NagPolicy? = null,
        verifyEveryDays: Int? = null,
        lastVerifiedAt: String? = null,
        state: ItemState = ItemState.ACTIVE,
    ) = TrackedItem(
        id = id,
        name = name,
        kind = kind,
        expiresOn = d(expiresOn),
        actByOffsetDays = actByOffsetDays,
        anchorDate = d(expiresOn),
        leadDays = leadDays ?: Reminders.defaultLeadDays(kind),
        nagAfterDue = nag ?: Reminders.defaultNagPolicy(kind),
        verifyEveryDays = verifyEveryDays,
        lastVerifiedAt = lastVerifiedAt?.let { d(it) },
        state = state,
    )

    @Test
    fun `lead alerts land the right number of days before the act-by date`() {
        val plan = NotificationPlanner.plan(
            listOf(item("t", Kind.TRIAL, expiresOn = "2026-08-20", leadDays = listOf(3, 1, 0), nag = NagPolicy.NONE)),
            today,
        )
        assertEquals(
            listOf(d("2026-08-17"), d("2026-08-19"), d("2026-08-20")),
            plan.alerts.filter { it.reason == AlertReason.LEAD }.map { it.date }.sorted(),
        )
    }

    // The act-by offset is what makes a high-stake item actionable rather than
    // merely alarming: you must cancel before the charge, not on the day of it.
    @Test
    fun `lead alerts anchor on act-by, not on expiry`() {
        val plan = NotificationPlanner.plan(
            listOf(
                item(
                    "sim", Kind.PREPAID, expiresOn = "2026-09-14",
                    actByOffsetDays = 7, leadDays = listOf(0), nag = NagPolicy.NONE,
                ),
            ),
            today,
        )
        // act-by is 7 days before 14 Sep.
        assertEquals(listOf(d("2026-09-07")), plan.alerts.map { it.date })
    }

    @Test
    fun `alerts in the past are not scheduled`() {
        val plan = NotificationPlanner.plan(
            listOf(item("old", Kind.TRIAL, expiresOn = "2026-08-16", leadDays = listOf(30, 1), nag = NagPolicy.NONE)),
            today,
        )
        assertTrue(plan.alerts.none { it.date < today })
    }

    @Test
    fun `alerts past the horizon are not scheduled`() {
        val plan = NotificationPlanner.plan(
            listOf(item("far", Kind.DOCUMENT, expiresOn = "2027-06-01", verifyEveryDays = null)),
            today,
        )
        assertTrue(plan.alerts.isEmpty(), "nothing within 60 days")
    }

    @Test
    fun `archived items are skipped`() {
        val plan = NotificationPlanner.plan(
            listOf(item("gone", Kind.PREPAID, expiresOn = "2026-08-20", state = ItemState.ARCHIVED)),
            today,
        )
        assertTrue(plan.alerts.isEmpty())
    }

    @Test
    fun `daily nag repeats after the deadline`() {
        val plan = NotificationPlanner.plan(
            listOf(
                item(
                    "bill", Kind.BILL, expiresOn = "2026-08-18",
                    leadDays = emptyList(), nag = NagPolicy.DAILY,
                ),
            ),
            today,
            horizonDays = 5,
        )
        assertEquals(
            listOf(d("2026-08-19"), d("2026-08-20")),
            plan.alerts.filter { it.reason == AlertReason.NAG }.map { it.date }.sorted(),
        )
    }

    @Test
    fun `no nag when the policy says none`() {
        val plan = NotificationPlanner.plan(
            listOf(item("nf", Kind.RECURRING, expiresOn = "2026-08-18", nag = NagPolicy.NONE)),
            today,
        )
        assertTrue(plan.alerts.none { it.reason == AlertReason.NAG })
    }

    @Test
    fun `verify alert fires once the re-check interval has elapsed`() {
        val plan = NotificationPlanner.plan(
            listOf(
                item(
                    "sim", Kind.PREPAID, expiresOn = "2027-01-01",
                    leadDays = emptyList(), nag = NagPolicy.NONE,
                    verifyEveryDays = 60, lastVerifiedAt = "2026-07-01",
                ),
            ),
            today,
        )
        // 1 Jul + 60 days = 30 Aug.
        assertEquals(listOf(d("2026-08-30")), plan.alerts.filter { it.reason == AlertReason.VERIFY }.map { it.date })
    }

    @Test
    fun `an overdue verify alert fires today rather than in the past`() {
        val plan = NotificationPlanner.plan(
            listOf(
                item(
                    "sim", Kind.PREPAID, expiresOn = "2027-01-01",
                    leadDays = emptyList(), nag = NagPolicy.NONE,
                    verifyEveryDays = 60, lastVerifiedAt = "2026-01-01",
                ),
            ),
            today,
        )
        assertEquals(listOf(today), plan.alerts.filter { it.reason == AlertReason.VERIFY }.map { it.date })
    }

    // The core allocation rule. Under pressure, an unrecoverable item keeps its
    // whole ladder before a lower-stake item gets a second alert.
    @Test
    fun `stake outranks date when the budget is tight`() {
        val sim = item(
            "sim", Kind.PREPAID, expiresOn = "2026-09-10",
            leadDays = listOf(20, 15, 10), nag = NagPolicy.NONE,
        )
        val netflix = item(
            "netflix", Kind.RECURRING, expiresOn = "2026-08-16",
            leadDays = listOf(1), nag = NagPolicy.NONE,
        )

        val plan = NotificationPlanner.plan(listOf(netflix, sim), today, budget = 3)

        assertEquals(setOf("sim"), plan.alerts.map { it.itemId }.toSet())
        assertEquals(listOf("netflix"), plan.dropped.map { it.itemId })
    }

    @Test
    fun `within one stake the soonest wins`() {
        val a = item("a", Kind.PREPAID, expiresOn = "2026-09-01", leadDays = listOf(0), nag = NagPolicy.NONE)
        val b = item("b", Kind.PREPAID, expiresOn = "2026-08-20", leadDays = listOf(0), nag = NagPolicy.NONE)

        val plan = NotificationPlanner.plan(listOf(a, b), today, budget = 1)
        assertEquals(listOf("b"), plan.alerts.map { it.itemId })
    }

    @Test
    fun `the budget is never exceeded`() {
        val many = (1..40).map {
            item("i$it", Kind.PREPAID, expiresOn = "2026-09-01", nag = NagPolicy.DAILY)
        }
        val plan = NotificationPlanner.plan(many, today)
        assertTrue(plan.alerts.size <= NotificationPlanner.BUDGET)
    }

    // Truncation must be visible. Silently dropping the earliest warning on the
    // highest-stake item is the failure this planner exists to prevent.
    @Test
    fun `truncation is reported rather than hidden`() {
        val many = (1..40).map {
            item("i$it", Kind.PREPAID, expiresOn = "2026-09-01", nag = NagPolicy.DAILY)
        }
        val plan = NotificationPlanner.plan(many, today)
        assertTrue(plan.isTruncated)
        assertTrue(plan.dropped.isNotEmpty())
    }

    @Test
    fun `a small plan is not marked truncated`() {
        val plan = NotificationPlanner.plan(
            listOf(item("one", Kind.TRIAL, expiresOn = "2026-08-20", nag = NagPolicy.NONE)),
            today,
        )
        assertFalse(plan.isTruncated)
    }

    @Test
    fun `interruption level follows stake`() {
        val plan = NotificationPlanner.plan(
            listOf(
                item("sim", Kind.PREPAID, expiresOn = "2026-08-20", nag = NagPolicy.NONE),
                item("nf", Kind.RECURRING, expiresOn = "2026-08-20", nag = NagPolicy.NONE),
            ),
            today,
        )
        assertTrue(plan.alerts.filter { it.itemId == "sim" }.all { it.timeSensitive })
        assertTrue(plan.alerts.filter { it.itemId == "nf" }.none { it.timeSensitive })
    }

    @Test
    fun `identifiers are unique and stable across runs`() {
        val items = listOf(
            item("sim", Kind.PREPAID, expiresOn = "2026-09-01", verifyEveryDays = 60),
            item("bill", Kind.BILL, expiresOn = "2026-08-25"),
        )
        val first = NotificationPlanner.plan(items, today)
        val second = NotificationPlanner.plan(items, today)

        assertEquals(first.alerts.map { it.identifier }, second.alerts.map { it.identifier })
        assertEquals(
            first.alerts.size,
            first.alerts.map { it.identifier }.toSet().size,
            "identifiers must not collide",
        )
    }

    @Test
    fun `stake is inferred so the form never has to ask`() {
        assertEquals(Stake.ASSET, Stakes.inferFrom(Kind.PREPAID))
        assertEquals(Stake.ASSET, Stakes.inferFrom(Kind.DOCUMENT))
        assertEquals(Stake.MONEY, Stakes.inferFrom(Kind.TRIAL))
        assertEquals(Stake.MONEY, Stakes.inferFrom(Kind.BILL))
        assertEquals(Stake.INFO, Stakes.inferFrom(Kind.RECURRING))
    }

    @Test
    fun `documents stay out of spend totals even when they cost money`() {
        val passport = TrackedItem(
            id = "p", name = "Hộ chiếu", kind = Kind.DOCUMENT,
            expiresOn = d("2027-01-01"), anchorDate = d("2027-01-01"),
            amountMinor = 200_000, currency = "VND",
        )
        assertFalse(passport.countsTowardSpend)

        val netflix = TrackedItem(
            id = "n", name = "Netflix", kind = Kind.RECURRING,
            expiresOn = d("2026-09-01"), anchorDate = d("2026-09-01"),
            amountMinor = 260_000, currency = "VND",
        )
        assertTrue(netflix.countsTowardSpend)
    }
}
