package space.denhan.domain

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.plus

/** One notification the app intends to have pending with iOS. */
data class PlannedAlert(
    val itemId: String,
    val itemName: String,
    val stake: Stake,
    val date: LocalDate,
    val time: LocalTime,
    val leadDays: Int,
    val reason: AlertReason,
    val timeSensitive: Boolean,
) {
    /**
     * Stable across re-planning runs so iOS de-duplicates rather than stacking.
     * The planner cancels everything and re-adds on each run, but a stable id
     * still makes logs and tests readable.
     */
    val identifier: String get() = "$itemId|${reason.name}|$date|$leadDays"
}

enum class AlertReason {
    /** Scheduled ahead of the act-by date. */
    LEAD,

    /** Repeat after the act-by date passed with no "done". */
    NAG,

    /** Periodic prompt to re-check the date against its real source. */
    VERIFY,
}

/** What the planner produced, including what it had to leave out. */
data class NotificationPlan(
    val alerts: List<PlannedAlert>,
    /** Alerts that did not fit the budget. Never drop these silently. */
    val dropped: List<PlannedAlert>,
) {
    val isTruncated: Boolean get() = dropped.isNotEmpty()
}

/**
 * Turns the item list into the set of notifications to have pending with iOS.
 *
 * This is an allocator against a hard resource budget, not a per-item "schedule
 * a reminder" call. iOS keeps at most 64 pending local notifications per app and
 * silently evicts the furthest-out ones past that. For a document ladder of
 * 180/90/60/30 days, the ones evicted are exactly the earliest warnings on the
 * highest-stake items. See product-spec.md section 7.3.
 *
 * Pure function so the ranking and truncation rules are testable without a
 * device.
 */
object NotificationPlanner {

    /** iOS keeps 64; leave headroom so nothing we schedule evicts anything else. */
    const val BUDGET = 50

    /** Alerts further out than this are not scheduled; a later re-plan picks them up. */
    const val HORIZON_DAYS = 60

    fun plan(
        items: List<TrackedItem>,
        today: LocalDate,
        budget: Int = BUDGET,
        horizonDays: Int = HORIZON_DAYS,
    ): NotificationPlan {
        val horizon = today.plus(horizonDays, DateTimeUnit.DAY)

        val candidates = items
            .filter { it.state == ItemState.ACTIVE }
            .flatMap { alertsFor(it, today, horizon) }
            .sortedWith(ranking)

        return NotificationPlan(
            alerts = candidates.take(budget),
            dropped = candidates.drop(budget),
        )
    }

    /**
     * Highest stake first, then soonest.
     *
     * The stake-first ordering is the whole point: an unrecoverable item gets its
     * entire ladder before a money item gets its second alert.
     */
    private val ranking = compareBy<PlannedAlert>({ it.stake.ordinal }, { it.date }, { it.leadDays })

    private fun alertsFor(item: TrackedItem, today: LocalDate, horizon: LocalDate): List<PlannedAlert> {
        val out = mutableListOf<PlannedAlert>()
        val actBy = item.actBy

        for (lead in item.leadDays) {
            val fireOn = actBy.plus(-lead, DateTimeUnit.DAY)
            if (fireOn in today..horizon) out += item.alert(fireOn, lead, AlertReason.LEAD)
        }

        out += nagAlerts(item, actBy, today, horizon)
        verifyAlert(item, today, horizon)?.let { out += it }
        return out
    }

    /**
     * Repeats after the deadline for items the user must not be allowed to
     * silently ignore. Swiping a notification away is not the same as handling
     * it, so these keep coming back until an occurrence is marked done.
     *
     * Enumerated as individual alerts rather than an iOS repeating trigger,
     * because a repeating trigger cannot vary its text per firing and cannot be
     * cancelled for one occurrence only.
     */
    private fun nagAlerts(
        item: TrackedItem,
        actBy: LocalDate,
        today: LocalDate,
        horizon: LocalDate,
    ): List<PlannedAlert> {
        val stepDays = when (item.nagAfterDue) {
            NagPolicy.NONE -> return emptyList()
            NagPolicy.DAILY -> 1
            NagPolicy.WEEKLY -> 7
        }

        val out = mutableListOf<PlannedAlert>()
        var at = maxOf(actBy.plus(stepDays, DateTimeUnit.DAY), today)
        while (at <= horizon) {
            out += item.alert(at, 0, AlertReason.NAG)
            at = at.plus(stepDays, DateTimeUnit.DAY)
        }
        return out
    }

    /**
     * Prompt to re-check a date against its real source. Independent of the due
     * date: a SIM's validity moves every time the user tops up, and the app has
     * no way to notice. See spec section 7.5.
     */
    private fun verifyAlert(item: TrackedItem, today: LocalDate, horizon: LocalDate): PlannedAlert? {
        val every = item.verifyEveryDays ?: return null
        val since = item.lastVerifiedAt ?: item.anchorDate
        val due = since.plus(every, DateTimeUnit.DAY)
        val fireOn = maxOf(due, today)
        return if (fireOn <= horizon) item.alert(fireOn, 0, AlertReason.VERIFY) else null
    }

    private fun TrackedItem.alert(date: LocalDate, lead: Int, reason: AlertReason) = PlannedAlert(
        itemId = id,
        itemName = name,
        stake = stake,
        date = date,
        time = remindAt,
        leadDays = lead,
        reason = reason,
        timeSensitive = Reminders.isTimeSensitive(stake),
    )
}
