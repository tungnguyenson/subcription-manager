package space.denhan.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime

/**
 * What is lost by missing a date. This is the app's organizing axis: it drives
 * lead times, whether reminders nag, notification interruption level, and who
 * wins when the 64-slot notification budget runs out.
 *
 * Ordinal order matters. ASSET must sort first. See spec section 3.
 */
enum class Stake { ASSET, MONEY, INFO }

/** What kind of thing this is. Drives defaults, not behaviour. */
enum class Kind {
    /** A free period that converts to a charge unless cancelled. */
    TRIAL,

    /** Renews itself on a cycle until stopped. */
    RECURRING,

    /** Runs out unless topped up: prepaid mobile, prepaid utilities. */
    PREPAID,

    /** A one-off amount owed by a date. */
    BILL,

    /** Expires and must be renewed; never counted as spend. */
    DOCUMENT,
}

enum class ItemState {
    ACTIVE,

    /** Cancelled but still usable until the period ends. Not the same as deleted. */
    CANCELLED_STILL_ACTIVE,
    ARCHIVED,
}

enum class NagPolicy { NONE, DAILY, WEEKLY }

/**
 * Where the due date came from. The app only knows what the user typed; it
 * cannot read the provider's records. A date shown with more confidence than
 * its source deserves is the failure this enum exists to prevent.
 */
enum class DateSource {
    /** User checked with the provider and typed what they were told. */
    USER_CONFIRMED,

    /** User typed it from memory. */
    USER_ESTIMATED,

    /** The app computed it from a cycle. */
    COMPUTED,

    /** Read out of an image and not yet confirmed against the source. */
    EXTRACTED,
}

enum class GroupKind { SIM, VEHICLE, PERSON, OTHER }

data class TrackedItem(
    val id: String,
    val name: String,
    val groupId: String? = null,
    val kind: Kind,
    val stake: Stake = Stakes.inferFrom(kind),
    val categoryId: String? = null,

    /** The date the thing actually expires. */
    val expiresOn: LocalDate,

    /** How many days before expiry the user must have acted. See spec 5.3. */
    val actByOffsetDays: Int = 0,

    /** The original date, never mutated. Cycle maths anchors here. See spec 5.2. */
    val anchorDate: LocalDate,
    val cycle: Cycle? = null,

    val amountMinor: Long? = null,
    val currency: String? = null,

    val actionUrl: String? = null,
    val actionLabel: String? = null,
    val note: String? = null,

    val leadDays: List<Int> = Reminders.defaultLeadDays(kind),
    val remindAt: LocalTime = Reminders.DEFAULT_REMIND_AT,
    val nagAfterDue: NagPolicy = Reminders.defaultNagPolicy(kind),

    val verifyEveryDays: Int? = Reminders.defaultVerifyEveryDays(kind),
    val lastVerifiedAt: LocalDate? = null,
    val dateSource: DateSource = DateSource.USER_ESTIMATED,

    val state: ItemState = ItemState.ACTIVE,
) {
    val money: Money?
        get() = if (amountMinor != null && currency != null) Money(amountMinor, currency) else null

    /** The date reminders anchor on. Earlier than expiry whenever acting takes lead time. */
    val actBy: LocalDate get() = Recurrence.actBy(expiresOn, actByOffsetDays)

    /** Documents and other non-recurring obligations must not land in spend totals. */
    val countsTowardSpend: Boolean
        get() = money != null && kind != Kind.DOCUMENT
}

data class ItemGroup(
    val id: String,
    val name: String,
    val kind: GroupKind,
)

/** One completed occurrence. Append-only; never edited once written. */
data class HandledEvent(
    val id: String,
    val itemId: String,
    val handledAtEpochSeconds: Long,
    val forDueDate: LocalDate,

    // Money is snapshotted here and never recomputed. See spec section 6.3.
    val amountMinor: Long? = null,
    val currency: String? = null,
    val fxRateScaled: Long? = null,
    val fxRateScale: Int? = null,
    val fxRateDate: LocalDate? = null,
    val fxSource: String? = null,
    val baseAmountMinor: Long? = null,

    /** Typed off a bank statement. Overrides every computed figure when present. */
    val actualChargedMinor: Long? = null,
)

object Stakes {
    /**
     * The form has no stake picker. Nothing in 1,744 competitor reviews suggests
     * users will classify an item by consequence at entry time, so the app infers
     * it and lets the user correct it later. See spec section 4.4.
     */
    fun inferFrom(kind: Kind): Stake = when (kind) {
        // Letting one of these lapse can cost something money cannot buy back.
        Kind.PREPAID, Kind.DOCUMENT -> Stake.ASSET
        Kind.TRIAL, Kind.BILL -> Stake.MONEY
        Kind.RECURRING -> Stake.INFO
    }
}
