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
    TRIAL,
    RECURRING,
    PREPAID_SIM,
    SIM_PLAN,
    KEEP_ALIVE,
    BILL,
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
 * cannot read a carrier's records. Showing a date with more confidence than its
 * source deserves is how a user loses a phone number. See spec section 4bis.3.
 */
enum class DateSource {
    /** User checked with the carrier or provider and typed what they were told. */
    USER_CONFIRMED,

    /** User typed it from memory. */
    USER_ESTIMATED,

    /** The app computed it from a cycle. */
    COMPUTED,

    /** Read out of an image and not yet confirmed against the source. */
    EXTRACTED,
}

enum class GroupKind { SIM, VEHICLE, PERSON, OTHER }

enum class Carrier { VIETTEL, VINAPHONE, MOBIFONE, VIETNAMOBILE, OTHER }

/** Three-valued because "we have not asked" is not the same as "no". */
enum class TriState { YES, NO, UNKNOWN }

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

/**
 * The extra state a SIM carries beyond "a name and a date", because three
 * independent clocks can each kill a number and topping up only defends
 * against the first. See spec section 4bis.1.
 */
data class SimProfile(
    val groupId: String,
    val carrier: Carrier,
    val msisdn: String,

    /** Kept only to not lose the number. Changes the advice the app gives. */
    val isDormant: Boolean = false,

    // Clock 1: validity. Store what the carrier said, plus when it said it.
    val hsdConfirmedDate: LocalDate? = null,
    val hsdConfirmedAt: LocalDate? = null,

    // Clock 2: identity re-authentication. The app cannot see this at all.
    val identityVerified: TriState = TriState.UNKNOWN,
    val identityCheckedAt: LocalDate? = null,

    // Clock 3: handset change.
    val lastDeviceChangeAt: LocalDate? = null,

    val retentionPackage: String? = null,
    val retentionExpiryDate: LocalDate? = null,
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
        Kind.PREPAID_SIM, Kind.KEEP_ALIVE, Kind.DOCUMENT -> Stake.ASSET
        Kind.TRIAL, Kind.BILL -> Stake.MONEY
        Kind.RECURRING, Kind.SIM_PLAN -> Stake.INFO
    }
}
