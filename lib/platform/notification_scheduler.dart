import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Action ids the notification's buttons send back. Stable strings, because
/// iOS keeps registered categories across launches.
abstract final class NotificationAction {
  static const String done = 'done';
  static const String snoozeOneDay = 'snooze_1d';
  static const String openItem = 'open';
}

/// The category an alert is delivered under, which decides which buttons the
/// user gets on the lock screen without opening the app.
abstract final class NotificationCategory {
  static const String actionable = 'subdock.actionable';
  static const String informational = 'subdock.info';
}

/// Puts the planned alerts on the device.
///
/// The planner decides *what* should be pending; this only carries it out. The
/// split matters because the allocation rules are the part worth testing, and
/// they are untestable once tangled with the plugin.
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _timezoneReady = false;

  NotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Registers categories at launch.
  ///
  /// iOS binds a notification's buttons from the categories registered at
  /// registration time, not at delivery time. Register late and every alert
  /// already queued arrives with no buttons and no error.
  Future<void> initialise({
    void Function(String? payload, String? actionId)? onTap,
  }) async {
    await _ensureTimezone();

    // Not `const`: DarwinNotificationAction.plain is a factory.
    final darwin = DarwinInitializationSettings(
      // Permission is requested later, from a screen that has explained why.
      // Asking at first launch is how an app gets a permanent "no".
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          NotificationCategory.actionable,
          actions: [
            DarwinNotificationAction.plain(
              NotificationAction.done,
              'Mark as paid',
            ),
            DarwinNotificationAction.plain(
              NotificationAction.snoozeOneDay,
              'Remind tomorrow',
            ),
            DarwinNotificationAction.plain(
              NotificationAction.openItem,
              'Open',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          NotificationCategory.informational,
          actions: [
            DarwinNotificationAction.plain(NotificationAction.done, 'Got it'),
          ],
        ),
      ],
    );

    // Android refuses to initialise without its own settings block, and the
    // failure is a thrown ArgumentError inside `main` -- the app never reaches
    // `runApp` and the screen stays black. `@mipmap/ic_launcher` is the icon
    // `flutter create` puts in the Android project.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: InitializationSettings(iOS: darwin, android: android),
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload, response.actionId),
    );

    await _createAndroidChannels();
  }

  /// Android carries importance on the channel, not on the notification.
  ///
  /// The two channels mirror the two iOS categories, so a deadline the user
  /// cannot recover from can ring while a routine renewal stays quiet. Created
  /// up front rather than on first send: a channel's importance is fixed at
  /// creation and the user owns it afterwards, so it must exist before the
  /// first alert decides which one it belongs to.
  Future<void> _createAndroidChannels() async {
    final android = _android;
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationCategory.actionable,
        'Deadlines',
        description: 'Things you lose if the date passes.',
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationCategory.informational,
        'Reminders',
        description: 'Renewals and dates worth a glance.',
        importance: Importance.low,
      ),
    );
  }

  /// Null on every platform but Android, which is how this class tells them
  /// apart -- cheaper than a `dart:io` check and it works under test.
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for permission at the moment the user has been told what it buys.
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      // A second, separate grant, and it is the one that decides whether a
      // reminder lands at 08:30 or whenever the system next wakes. Asked for
      // here so the two prompts arrive together, on the screen that has just
      // explained them; a refusal is not fatal -- `_scheduleMode` falls back.
      await android.requestExactAlarmsPermission();
      return granted ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
      // Lets a deadline through Focus. Requires the Time Sensitive
      // Notifications capability on the target; without it iOS silently
      // downgrades to the default level rather than failing.
      critical: false,
    );
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final settings = await ios?.checkPermissions();
    return settings?.isEnabled ?? false;
  }

  /// Exact alarms are a permission of their own on Android 12+, denied by
  /// default from Android 13. Scheduling an exact alarm without it does not
  /// degrade -- `zonedSchedule` throws, and one throw aborts the whole
  /// `apply` loop, leaving the user with no reminders at all. So ask first
  /// and drop to inexact, which costs a delivery window of some minutes.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _android;
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;

    final exact = await android.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Replaces every pending notification with [plan].
  ///
  /// Cancel-all then re-add, rather than diffing. The pending set is small and
  /// bounded by the planner's budget, and a diff that drifts out of sync leaves
  /// an alert for an item the user already handled, which trains them to
  /// distrust the whole thing.
  Future<void> apply(NotificationPlan plan) async {
    await _ensureTimezone();
    await _plugin.cancelAll();

    // Resolved once per apply, not per alert: it is a platform channel round
    // trip and the answer cannot change midway through the loop.
    final mode = await _scheduleMode();

    for (final alert in plan.alerts) {
      await _schedule(alert, mode);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  Future<void> _schedule(PlannedAlert alert, AndroidScheduleMode mode) {
    final when = tz.TZDateTime(
      tz.local,
      alert.date.year,
      alert.date.month,
      alert.date.day,
      alert.time.hour,
      alert.time.minute,
    );

    return _plugin.zonedSchedule(
      id: alert.numericId,
      title: _title(alert),
      body: alert.itemName,
      scheduledDate: when,
      androidScheduleMode: mode,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          alert.timeSensitive
              ? NotificationCategory.actionable
              : NotificationCategory.informational,
          alert.timeSensitive ? 'Deadlines' : 'Reminders',
          // Set here too because the channel carries it only from the moment
          // the channel is created; these decide how the post is drawn on
          // Android 7 and below, which has no channels at all.
          importance: alert.timeSensitive ? Importance.high : Importance.low,
          priority: alert.timeSensitive ? Priority.high : Priority.low,
          // Same ids as the iOS actions, so one handler serves both.
          actions: <AndroidNotificationAction>[
            if (alert.timeSensitive) ...[
              const AndroidNotificationAction(
                NotificationAction.done,
                'Mark as paid',
              ),
              const AndroidNotificationAction(
                NotificationAction.snoozeOneDay,
                'Remind tomorrow',
              ),
              const AndroidNotificationAction(
                NotificationAction.openItem,
                'Open',
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ] else
              const AndroidNotificationAction(
                NotificationAction.done,
                'Got it',
              ),
          ],
          // Android's counterpart to threadIdentifier: three reminders for one
          // subscription collapse into one stack rather than three rows.
          groupKey: alert.itemId,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: alert.timeSensitive
              ? NotificationCategory.actionable
              : NotificationCategory.informational,
          interruptionLevel: alert.timeSensitive
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.passive,
          // Grouped per item so three reminders for one subscription stack
          // rather than filling the notification centre.
          threadIdentifier: alert.itemId,
        ),
      ),
      payload: alert.itemId,
      // No `matchDateTimeComponents`: every occurrence is enumerated by the
      // planner. A repeating trigger cannot vary its text per firing and
      // cannot be cancelled for one occurrence only.
    );
  }

  String _title(PlannedAlert alert) => switch (alert.reason) {
    AlertReason.lead => switch (alert.leadDays) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      final days => 'Due in $days days',
    },
    AlertReason.nag => 'Overdue',
    AlertReason.verify => 'Check this date is still right',
    AlertReason.snoozed => 'You asked to be reminded',
  };

  /// `zonedSchedule` needs a real timezone database; the plugin does not load
  /// one for you. Without this every scheduled time is computed in UTC, so a
  /// reminder set for 08:30 arrives at 15:30 in Vietnam.
  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    _timezoneReady = true;
  }
}
