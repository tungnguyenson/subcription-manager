package space.denhan.platform

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.suspendCancellableCoroutine
import platform.Foundation.NSCalendarUnitDay
import platform.Foundation.NSCalendarUnitHour
import platform.Foundation.NSCalendarUnitMinute
import platform.Foundation.NSCalendarUnitMonth
import platform.Foundation.NSCalendarUnitYear
import platform.Foundation.NSDateComponents
import platform.UIKit.UIApplication
import platform.UserNotifications.UNAuthorizationOptionAlert
import platform.UserNotifications.UNAuthorizationOptionBadge
import platform.UserNotifications.UNAuthorizationOptionSound
import platform.UserNotifications.UNAuthorizationStatusAuthorized
import platform.UserNotifications.UNAuthorizationStatusDenied
import platform.UserNotifications.UNAuthorizationStatusNotDetermined
import platform.UserNotifications.UNAuthorizationStatusProvisional
import platform.UserNotifications.UNCalendarNotificationTrigger
import platform.UserNotifications.UNNotificationAction
import platform.UserNotifications.UNNotificationActionOptionForeground
import platform.UserNotifications.UNNotificationActionOptionNone
import platform.UserNotifications.UNNotificationCategory
import platform.UserNotifications.UNNotificationCategoryOptionNone
import platform.UserNotifications.UNNotificationInterruptionLevel
import platform.UserNotifications.UNNotificationRequest
import platform.UserNotifications.UNNotificationSound
import platform.UserNotifications.UNMutableNotificationContent
import platform.UserNotifications.UNUserNotificationCenter
import space.denhan.domain.AlertReason
import space.denhan.domain.NotificationPlan
import space.denhan.domain.PlannedAlert
import kotlin.coroutines.resume

/**
 * iOS local notification scheduling, called straight from Kotlin.
 *
 * The whole UserNotifications surface is reachable from iosMain, so none of this
 * needs Swift. The one thing that does is assigning the delegate, which Apple
 * requires before the app finishes launching and therefore has to happen in
 * AppDelegate.
 *
 * Three failure modes this file is written to avoid, all silent:
 *  - checking `error == null` instead of the `granted` flag, so a denial reads
 *    as success and the app looks like it is working;
 *  - referencing a notification category before registering it, which drops the
 *    action buttons with no warning;
 *  - iOS repeating triggers, which cannot vary their text per firing and cannot
 *    be cancelled for a single occurrence.
 */
@OptIn(ExperimentalForeignApi::class)
actual class NotificationScheduler {

    private val center = UNUserNotificationCenter.currentNotificationCenter()

    actual suspend fun authorizationStatus(): NotificationAuthorization =
        suspendCancellableCoroutine { cont ->
            center.getNotificationSettingsWithCompletionHandler { settings ->
                cont.resume(
                    when (settings?.authorizationStatus) {
                        UNAuthorizationStatusAuthorized -> NotificationAuthorization.GRANTED
                        UNAuthorizationStatusProvisional -> NotificationAuthorization.PROVISIONAL
                        UNAuthorizationStatusDenied -> NotificationAuthorization.DENIED
                        UNAuthorizationStatusNotDetermined -> NotificationAuthorization.NOT_DETERMINED
                        else -> NotificationAuthorization.NOT_DETERMINED
                    },
                )
            }
        }

    actual suspend fun requestAuthorization(): NotificationAuthorization =
        suspendCancellableCoroutine { cont ->
            val options = UNAuthorizationOptionAlert or
                UNAuthorizationOptionSound or
                UNAuthorizationOptionBadge

            center.requestAuthorizationWithOptions(options) { granted, _ ->
                // Branch on `granted`, not on the error being null: a denial
                // reports no error at all.
                cont.resume(
                    if (granted) NotificationAuthorization.GRANTED
                    else NotificationAuthorization.DENIED,
                )
            }
        }

    actual fun registerCategories() {
        val done = UNNotificationAction.actionWithIdentifier(
            identifier = NotificationActions.DONE,
            title = NotificationActions.DONE_TITLE_VI,
            options = UNNotificationActionOptionNone,
        )
        val snooze = UNNotificationAction.actionWithIdentifier(
            identifier = NotificationActions.SNOOZE,
            title = NotificationActions.SNOOZE_TITLE_VI,
            options = UNNotificationActionOptionNone,
        )
        val skip = UNNotificationAction.actionWithIdentifier(
            identifier = NotificationActions.SKIP,
            title = NotificationActions.SKIP_TITLE_VI,
            options = UNNotificationActionOptionNone,
        )

        val standard = UNNotificationCategory.categoryWithIdentifier(
            identifier = NotificationActions.CATEGORY_STANDARD,
            actions = listOf(done, snooze, skip),
            intentIdentifiers = emptyList<String>(),
            options = UNNotificationCategoryOptionNone,
        )

        // The third button opens a URL, so it must bring the app forward.
        val openAction = UNNotificationAction.actionWithIdentifier(
            identifier = NotificationActions.OPEN_ACTION,
            title = "Mở",
            options = UNNotificationActionOptionForeground,
        )
        val withAction = UNNotificationCategory.categoryWithIdentifier(
            identifier = NotificationActions.CATEGORY_WITH_ACTION,
            actions = listOf(done, snooze, openAction),
            intentIdentifiers = emptyList<String>(),
            options = UNNotificationCategoryOptionNone,
        )

        center.setNotificationCategories(setOf(standard, withAction))
    }

    actual suspend fun apply(plan: NotificationPlan) {
        // Replace wholesale rather than adding: the pending set is a budget, and
        // stale entries from a previous plan would eat into it.
        center.removeAllPendingNotificationRequests()
        plan.alerts.forEach { schedule(it) }
    }

    actual suspend fun pendingCount(): Int = suspendCancellableCoroutine { cont ->
        center.getPendingNotificationRequestsWithCompletionHandler { requests ->
            cont.resume(requests?.size ?: 0)
        }
    }

    actual fun setBadge(count: Int) {
        UIApplication.sharedApplication.applicationIconBadgeNumber = count.toLong()
    }

    private fun schedule(alert: PlannedAlert) {
        val content = UNMutableNotificationContent().apply {
            setTitle(alert.itemName)
            setBody(bodyFor(alert))
            setSound(UNNotificationSound.defaultSound)
            setCategoryIdentifier(NotificationActions.CATEGORY_STANDARD)
            setThreadIdentifier(alert.itemId)

            // Time Sensitive gets past Focus and Do Not Disturb, and needs only a
            // capability in Xcode. Critical Alert would sound through silent mode
            // but requires Apple to approve the app individually, so it is out.
            if (alert.timeSensitive) {
                setInterruptionLevel(UNNotificationInterruptionLevel.UNNotificationInterruptionLevelTimeSensitive)
            }
        }

        val components = NSDateComponents().apply {
            year = alert.date.year.toLong()
            month = alert.date.monthNumber.toLong()
            day = alert.date.dayOfMonth.toLong()
            hour = alert.time.hour.toLong()
            minute = alert.time.minute.toLong()
        }

        val trigger = UNCalendarNotificationTrigger.triggerWithDateMatchingComponents(
            dateComponents = components,
            // Never repeating: a repeating trigger cannot change its text per
            // firing and cannot be cancelled for one occurrence.
            repeats = false,
        )

        center.addNotificationRequest(
            UNNotificationRequest.requestWithIdentifier(
                identifier = alert.identifier,
                content = content,
                trigger = trigger,
            ),
        ) { _ -> }
    }

    private fun bodyFor(alert: PlannedAlert): String = when (alert.reason) {
        AlertReason.LEAD -> when (alert.leadDays) {
            0 -> "Hôm nay là hạn cuối"
            1 -> "Còn 1 ngày"
            else -> "Còn ${alert.leadDays} ngày"
        }
        AlertReason.NAG -> "Đã quá hạn, chưa được xử lý"
        AlertReason.VERIFY -> "Đã lâu chưa kiểm tra lại. Xác nhận với nhà mạng?"
    }

    private companion object {
        // Silences the unused-import warning for calendar unit constants that
        // document which fields the trigger matches on.
        val MATCHED_UNITS = NSCalendarUnitYear or NSCalendarUnitMonth or
            NSCalendarUnitDay or NSCalendarUnitHour or NSCalendarUnitMinute
    }
}
