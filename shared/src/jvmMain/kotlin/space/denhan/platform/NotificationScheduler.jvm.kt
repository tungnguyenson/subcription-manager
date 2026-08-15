package space.denhan.platform

import space.denhan.domain.NotificationPlan

/**
 * Recording stand-in for the JVM. Lets the re-arm logic be exercised in tests
 * without a device: it stores whatever plan was last applied so a test can
 * assert on it.
 */
actual class NotificationScheduler {
    var lastApplied: NotificationPlan? = null
        private set
    var badge: Int = 0
        private set
    var categoriesRegistered: Boolean = false
        private set

    actual suspend fun authorizationStatus() = NotificationAuthorization.GRANTED
    actual suspend fun requestAuthorization() = NotificationAuthorization.GRANTED
    actual fun registerCategories() { categoriesRegistered = true }
    actual suspend fun apply(plan: NotificationPlan) { lastApplied = plan }
    actual suspend fun pendingCount(): Int = lastApplied?.alerts?.size ?: 0
    actual fun setBadge(count: Int) { badge = count }
}
