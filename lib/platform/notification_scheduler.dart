import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:meta/meta.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:subdock/i18n.dart';

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

/// What [NotificationScheduler.sendTest] set up.
///
/// Reported back rather than swallowed because the screen has to say what it
/// did. "A test was sent" is not checkable: the user stares at a phone for a
/// while and learns nothing from silence. A time and a zone they can hold
/// against their own clock is.
@immutable
class TestDelivery {
  /// When it should land, on the device's wall clock.
  final LocalTime at;

  /// The zone that time was computed in, e.g. `Asia/Ho_Chi_Minh`.
  ///
  /// Named on screen because a wrong zone is the failure this app has already
  /// had: without a loaded timezone database an 08:30 reminder arrives at
  /// 15:30 in Vietnam, and the only visible symptom is a time that looks
  /// almost right.
  final String zone;

  /// Whether it was scheduled to the minute. Null off Android -- see
  /// [NotificationScheduler.hasExactTiming].
  final bool? exact;

  const TestDelivery({required this.at, required this.zone, this.exact});
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
              S.t.actionMarkAsPaid,
            ),
            DarwinNotificationAction.plain(
              NotificationAction.snoozeOneDay,
              S.t.actionRemindTomorrow,
            ),
            DarwinNotificationAction.plain(
              NotificationAction.openItem,
              S.t.actionOpen,
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          NotificationCategory.informational,
          actions: [
            DarwinNotificationAction.plain(
              NotificationAction.done,
              S.t.actionGotIt,
            ),
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
      AndroidNotificationChannel(
        NotificationCategory.actionable,
        S.t.channelDeadlines,
        description: S.t.channelDeadlinesBody,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        NotificationCategory.informational,
        S.t.channelReminders,
        description: S.t.channelRemindersBody,
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

  /// Whether a reminder will arrive at the minute it was set for.
  ///
  /// Null where the question does not arise -- iOS schedules a local
  /// notification to the minute and offers nothing to turn that off. Android
  /// makes it a second permission on top of notifications, not pre-granted on
  /// a fresh install, and a user who granted one and not the other has no way
  /// to tell from the app that their 08:30 reminder now arrives whenever the
  /// system next wakes.
  Future<bool?> hasExactTiming() async {
    final android = _android;
    if (android == null) return null;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Exact alarms are a permission of their own on Android 12+, and not
  /// pre-granted on a fresh install for an app targeting API 33 or higher.
  /// Scheduling an exact alarm without it does not
  /// degrade -- `zonedSchedule` throws, and one throw aborts the whole
  /// `apply` loop, leaving the user with no reminders at all. So ask first
  /// and drop to inexact, which costs a delivery window of some minutes.
  Future<AndroidScheduleMode> _scheduleMode() async =>
      _modeFor(await hasExactTiming());

  /// Split from [_scheduleMode] so a caller that already asked the question
  /// does not pay for a second platform channel round trip to ask it again.
  AndroidScheduleMode _modeFor(bool? exact) {
    if (exact == null) return AndroidScheduleMode.exactAllowWhileIdle;

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

    // Least important first, so the most important is the last thing handed
    // over. That is backwards from how it reads, and it is deliberate.
    //
    // Measured on an iPhone running iOS 26.5, by
    // `integration_test/notification_ceiling_test.dart`: hand iOS one hundred
    // requests numbered nought to ninety-nine in date order, and the sixty-four
    // it keeps are numbers thirty-six to ninety-nine. It keeps the ones added
    // **last**, not the ones that fire soonest. The rule stated all over this
    // repo, that the furthest-out are dropped, is the pre-iOS-10 behaviour and
    // has not been true for years.
    //
    // `plan.alerts` arrives most important first, because `_ordered` puts
    // round zero -- every item's nearest alert -- at the head. Added in that
    // order, an overflow would throw away exactly those and keep a year's
    // worth of distant ones. Reversed, an overflow costs the tail, which is
    // what the planner already decided it could most afford to lose.
    //
    // The budget is 50 against a ceiling of 64, so nothing overflows today.
    // This is the guard rail for the day someone raises it.
    for (final alert in plan.alerts.reversed) {
      await _schedule(alert, mode);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// How far out [sendTest] puts its notification.
  ///
  /// Long enough to background the app and watch it land, short enough that
  /// nobody gives up waiting.
  static const Duration testDelay = Duration(seconds: 10);

  /// The id [sendTest] uses.
  ///
  /// A fixed number rather than a hash, so a second test replaces the first
  /// instead of stacking. It shares a namespace with [PlannedAlert.numericId],
  /// and a collision is possible but harmless: the worst case is that one
  /// pending alert is overwritten, and the next [apply] puts it back.
  static const int testId = 1;

  /// Schedules one notification a few seconds out, attached to nothing.
  ///
  /// Goes through [zonedSchedule] rather than the plugin's `show`, and takes
  /// the same timezone conversion, schedule mode and channel a real reminder
  /// takes. That is the whole point of it. An instant `show` proves only that
  /// permission is granted, while every way this app has actually failed to
  /// deliver -- an unloaded timezone database, exact alarms denied, the
  /// manufacturer's battery saver dropping the alarm -- lives on the
  /// scheduling path. A test that skips that path passes on a phone that never
  /// delivers a single reminder.
  ///
  /// Sent on the loud channel deliberately. The reminders worth testing are
  /// the ones for a deadline the user cannot undo, and if that channel has
  /// been muted then the test failing to make a sound is the correct answer,
  /// not a flaw in the test.
  ///
  /// Not protected from [apply], which cancels everything pending including
  /// this. In practice the two do not collide: the plan only re-applies when
  /// it differs, and nothing about backgrounding the app to watch the test
  /// land changes it.
  Future<TestDelivery> sendTest() async {
    await _ensureTimezone();

    final exact = await hasExactTiming();
    final when = tz.TZDateTime.now(tz.local).add(testDelay);

    await _plugin.zonedSchedule(
      id: testId,
      title: S.t.testReminderTitle,
      body: S.t.testReminderBody,
      scheduledDate: when,
      androidScheduleMode: _modeFor(exact),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationCategory.actionable,
          S.t.channelDeadlines,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: NotificationCategory.actionable,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      // No payload: tapping it must not try to open an item that does not
      // exist.
    );

    return TestDelivery(
      at: LocalTime(when.hour, when.minute),
      zone: tz.local.name,
      exact: exact,
    );
  }

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
      body: alert.body,
      scheduledDate: when,
      androidScheduleMode: mode,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          alert.timeSensitive
              ? NotificationCategory.actionable
              : NotificationCategory.informational,
          alert.timeSensitive ? S.t.channelDeadlines : S.t.channelReminders,
          // Set here too because the channel carries it only from the moment
          // the channel is created; these decide how the post is drawn on
          // Android 7 and below, which has no channels at all.
          importance: alert.timeSensitive ? Importance.high : Importance.low,
          priority: alert.timeSensitive ? Priority.high : Priority.low,
          // Same ids as the iOS actions, so one handler serves both.
          actions: <AndroidNotificationAction>[
            if (alert.timeSensitive) ...[
              AndroidNotificationAction(
                NotificationAction.done,
                S.t.actionMarkAsPaid,
              ),
              AndroidNotificationAction(
                NotificationAction.snoozeOneDay,
                S.t.actionRemindTomorrow,
              ),
              AndroidNotificationAction(
                NotificationAction.openItem,
                S.t.actionOpen,
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ] else
              AndroidNotificationAction(
                NotificationAction.done,
                S.t.actionGotIt,
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
      0 => S.t.notifDueToday,
      1 => S.t.notifDueTomorrow,
      final days => S.t.notifDueInDays(days),
    },
    AlertReason.nag => S.t.notifOverdue,
    AlertReason.verify => S.t.notifVerify,
    AlertReason.snoozed => S.t.notifSnoozed,
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
