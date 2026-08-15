package space.denhan.domain

import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.plus

/** How often an item comes round again. `null` cycle means it happens once. */
enum class Cycle(val unit: DateTimeUnit.DateBased, val step: Int) {
    WEEKLY(DateTimeUnit.DAY, 7),
    MONTHLY(DateTimeUnit.MONTH, 1),
    QUARTERLY(DateTimeUnit.MONTH, 3),
    SEMIANNUAL(DateTimeUnit.MONTH, 6),
    YEARLY(DateTimeUnit.MONTH, 12),
}

/**
 * Cycle arithmetic anchored to the original date.
 *
 * The bug this guards against: kotlinx-datetime's plus(1, MONTH) clamps to the
 * end of the month, which is correct on its own but lossy when accumulated.
 * Adding one month at a time from 31 Jan gives
 *
 *     31 Jan -> 28 Feb -> 28 Mar -> 28 Apr ...
 *
 * and the 31st is gone for good. Computing the Nth occurrence from the anchor
 * instead gives 31 Jan + 2 months = 31 Mar, which is what a subscription
 * actually does. See product-spec.md section 5.2.
 *
 * Every function here takes the anchor. None of them takes "the previous due
 * date", because that is the shape of the bug.
 */
object Recurrence {

    /** The [n]th occurrence after [anchor]. n = 0 is the anchor itself. */
    fun occurrenceAfter(anchor: LocalDate, cycle: Cycle, n: Int): LocalDate {
        require(n >= 0) { "n must not be negative, got $n" }
        return anchor.plus(cycle.step * n, cycle.unit)
    }

    /**
     * How many whole cycles have elapsed from [anchor] up to and including [today].
     *
     * Counts forward rather than doing calendar division, because month-length
     * clamping makes the division non-exact. Cheap at realistic cycle counts.
     */
    fun cyclesElapsed(anchor: LocalDate, cycle: Cycle, today: LocalDate): Int {
        if (today <= anchor) return 0
        var n = 0
        while (occurrenceAfter(anchor, cycle, n + 1) <= today) n++
        return n
    }

    /**
     * The first occurrence strictly after [today], or the anchor if it is still
     * ahead. Returns null for one-off items that have already passed.
     */
    fun nextDue(anchor: LocalDate, cycle: Cycle?, today: LocalDate): LocalDate? {
        if (cycle == null) return anchor.takeIf { it > today }
        if (anchor > today) return anchor
        return occurrenceAfter(anchor, cycle, cyclesElapsed(anchor, cycle, today) + 1)
    }

    /**
     * The date the user must act by, which is earlier than the expiry for almost
     * everything that matters: cancel a trial before it converts, top up before
     * the line is barred, renew a passport months ahead. See spec section 5.3.
     */
    fun actBy(expiresOn: LocalDate, actByOffsetDays: Int): LocalDate {
        require(actByOffsetDays >= 0) { "offset must not be negative, got $actByOffsetDays" }
        return expiresOn.plus(-actByOffsetDays, DateTimeUnit.DAY)
    }
}
