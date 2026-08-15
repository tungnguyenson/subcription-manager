package space.denhan.platform

import space.denhan.domain.NotificationPlan

/** Android is not a shipping target yet. See SecureStore.android.kt. */
actual class NotificationScheduler {
    actual suspend fun authorizationStatus(): NotificationAuthorization = TODO("Android target not implemented")
    actual suspend fun requestAuthorization(): NotificationAuthorization = TODO("Android target not implemented")
    actual fun registerCategories(): Unit = TODO("Android target not implemented")
    actual suspend fun apply(plan: NotificationPlan): Unit = TODO("Android target not implemented")
    actual suspend fun pendingCount(): Int = TODO("Android target not implemented")
    actual fun setBadge(count: Int): Unit = TODO("Android target not implemented")
}
