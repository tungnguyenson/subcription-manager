package space.denhan.platform

import space.denhan.domain.NotificationPlan

/**
 * Hands a computed plan to the operating system.
 *
 * The contract is deliberately "replace everything", not "add one": iOS keeps at
 * most 64 pending local notifications and evicts the furthest-out ones with no
 * error, so the pending set has to be recomputed and re-armed as a whole rather
 * than accumulated. [NotificationPlan] has already done the ranking and
 * truncation. See product-spec.md section 7.3.
 */
expect class NotificationScheduler {

    /** Whether the user has granted permission. Denied is a state, not an error. */
    suspend fun authorizationStatus(): NotificationAuthorization

    /** Returns what the user chose. Never assume granted. */
    suspend fun requestAuthorization(): NotificationAuthorization

    /**
     * Registers the action buttons. Must run at launch, before anything
     * schedules a notification that references a category, or the buttons
     * silently do not appear.
     */
    fun registerCategories()

    /** Cancels every pending notification and schedules the plan from scratch. */
    suspend fun apply(plan: NotificationPlan)

    /** Number the OS is currently holding. Used to verify we stayed under budget. */
    suspend fun pendingCount(): Int

    /** Overdue plus due-today, shown on the app icon. */
    fun setBadge(count: Int)
}

enum class NotificationAuthorization {
    NOT_DETERMINED,
    DENIED,
    GRANTED,

    /** Delivered quietly to the notification centre only. */
    PROVISIONAL,
}

/**
 * Action buttons, so the common case never requires opening the app.
 *
 * No competitor ships these: across 1,744 reviews of nine apps there was not a
 * single mention of acting from a notification. See product-spec.md 7.1bis.
 */
object NotificationActions {
    const val CATEGORY_STANDARD = "denhan.standard"
    const val CATEGORY_WITH_ACTION = "denhan.with_action"

    const val DONE = "denhan.done"
    const val SNOOZE = "denhan.snooze"
    const val SKIP = "denhan.skip"
    const val OPEN_ACTION = "denhan.open_action"

    const val DONE_TITLE_VI = "Đã xong"
    const val SNOOZE_TITLE_VI = "Hoãn một ngày"
    const val SKIP_TITLE_VI = "Bỏ qua kỳ này"
}
