package space.denhan.domain

import kotlinx.datetime.LocalTime

/**
 * Reminder defaults per kind. Every value here is a product decision from
 * product-spec.md section 7.2, not a guess.
 *
 * The user can override any of these per item, but the defaults have to be
 * right out of the box: an app that reminds at the wrong time trains the user
 * to swipe reminders away, and then the real one gets swiped away too.
 */
object Reminders {

    val DEFAULT_REMIND_AT = LocalTime(8, 30)

    /** Re-check cadence for items whose date can silently drift. See spec 7.5. */
    const val DEFAULT_VERIFY_EVERY_DAYS = 60

    fun defaultLeadDays(kind: Kind): List<Int> = when (kind) {
        // Running out can cost something unrecoverable, so warn from far out.
        Kind.PREPAID -> listOf(30, 14, 7, 3, 1, 0)
        // Renewing a document needs an appointment, not just a payment.
        Kind.DOCUMENT -> listOf(60, 30, 7)
        // Early enough to still cancel before the card is charged.
        Kind.TRIAL -> listOf(3, 1, 0)
        // Early enough to gather the money.
        Kind.BILL -> listOf(7, 1)
        Kind.RECURRING -> listOf(3)
    }

    fun defaultNagPolicy(kind: Kind): NagPolicy = when (kind) {
        Kind.PREPAID, Kind.BILL -> NagPolicy.DAILY
        Kind.DOCUMENT -> NagPolicy.WEEKLY
        // One nudge to check the card was not charged, then stop.
        Kind.TRIAL -> NagPolicy.NONE
        Kind.RECURRING -> NagPolicy.NONE
    }

    fun defaultVerifyEveryDays(kind: Kind): Int? = when (kind) {
        // Only things whose real date lives somewhere the app cannot read.
        Kind.PREPAID, Kind.DOCUMENT -> DEFAULT_VERIFY_EVERY_DAYS
        else -> null
    }

    /**
     * Whether a notification should use iOS's Time Sensitive interruption level,
     * which gets past Focus and Do Not Disturb.
     *
     * Deliberately not Critical Alert: that sounds through silent mode and needs
     * a per-app entitlement from Apple.
     */
    fun isTimeSensitive(stake: Stake): Boolean = stake != Stake.INFO
}
