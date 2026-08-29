import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/platform/notification_scheduler.dart';

/// Measures the real pending-notification ceiling, on a real device.
///
/// `NotificationPlanner.budget` is 50, and the number it leaves room under,
/// 64, is not something Apple documents anywhere today. It predates
/// `UNUserNotificationCenter`, the page that carried it has been taken down,
/// and the only current writing that states it is this plugin's own README. An
/// app whose whole subject is telling the user what will and will not be
/// delivered should not size its one hard resource off folklore.
///
/// So this asks the device. It is a measurement, not an assertion: it prints a
/// table and fails only on answers that are unambiguously broken, because the
/// number is allowed to differ per OS version and per manufacturer and finding
/// out what it is here is the whole point.
///
/// ```bash
/// flutter test integration_test/notification_ceiling_test.dart -d <ios-device>
/// flutter test integration_test/notification_ceiling_test.dart -d <android-device>
/// ```
///
/// Everything is dated a month or more out and cancelled at the end, so
/// nothing fires at whoever is holding the phone.
///
/// ## The two platforms are not measured the same way, and cannot be
///
/// This is the part to understand before reading any number it prints.
///
/// On **iOS** `pendingNotificationRequests` calls
/// `getPendingNotificationRequestsWithCompletionHandler` on
/// `UNUserNotificationCenter`. That is the system's own list, so asking for
/// more than it keeps shows up directly as a smaller count. The reading is
/// authoritative.
///
/// On **Android** the same call reads a `SharedPreferences` blob the plugin
/// writes itself (`loadScheduledNotifications`), not `AlarmManager`. It
/// reports back whatever the plugin believes it scheduled, so **a count on
/// Android cannot detect an OS ceiling at all** and a run that prints
/// `asked=100 kept=100` there says nothing about the platform. What is
/// observable on Android is the throw: the plugin's README reports Samsung
/// capping `AlarmManager` at 500 with an exception past it, and an exception
/// is a thing this test can catch. Hence the separate Android-only case below.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  final scheduler = NotificationScheduler(plugin);
  final today = LocalDate.today();
  final onIos = Platform.isIOS;

  /// Alert number [i], dated far enough out that none of this fires today.
  ///
  /// One per day and ascending, so the read-back can say whether the survivors
  /// are the ones added first or the ones added last.
  PlannedAlert probe(int i) => PlannedAlert(
    itemId: 'ceiling-probe-$i',
    itemName: 'probe $i',
    date: today.plusDays(30 + i),
    time: const LocalTime(9, 0),
    leadDays: 0,
    reason: AlertReason.lead,
    timeSensitive: false,
  );

  Future<void> ask(int n) => scheduler.apply(
    NotificationPlan(
      alerts: [for (var i = 0; i < n; i++) probe(i)],
      dropped: const [],
    ),
  );

  setUpAll(() async {
    await scheduler.initialise();
    final granted = await scheduler.requestPermission();
    // ignore: avoid_print
    print(
      'SETUP platform=${Platform.operatingSystem} '
      'version=${Platform.operatingSystemVersion} '
      'granted=$granted exact=${await scheduler.hasExactTiming()}',
    );
    expect(
      granted,
      isTrue,
      reason:
          'Allow notifications when the prompt appears, then run again. '
          'Without permission the counts below measure nothing.',
    );
  });

  tearDownAll(() async => scheduler.cancelAll());

  // Straddles the reported 64 on both sides and goes well past it. A device
  // that keeps 100 has no ceiling worth planning around; one that keeps 32
  // would mean the budget of 50 has been overspending all along.
  testWidgets('how many pending notifications the device keeps', (_) async {
    const ladder = [40, 50, 60, 63, 64, 65, 70, 80, 100, 128];

    var highest = 0;
    for (final n in ladder) {
      await ask(n);
      final kept = await scheduler.pendingCount();
      if (kept > highest) highest = kept;
      // ignore: avoid_print
      print('CEILING asked=$n kept=$kept');
    }

    // ignore: avoid_print
    print(
      onIos
          ? 'CEILING highest kept = $highest (asked UNUserNotificationCenter)'
          : 'CEILING highest kept = $highest '
                '(plugin bookkeeping only, NOT an Android ceiling)',
    );

    expect(
      highest,
      greaterThanOrEqualTo(40),
      reason:
          'a device that cannot '
          'hold 40 breaks the app outright',
    );
    expect(
      highest,
      greaterThanOrEqualTo(NotificationPlanner.budget),
      reason: 'the budget the planner spends does not fit on this device',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));

  // The question a count cannot answer, and the one that matters more.
  //
  //   survivors 0..63  -> the soonest are kept, overflow costs the furthest out
  //   survivors 36..99 -> the last added are kept, overflow costs the nearest
  //
  // `apply` adds `plan.alerts` in order and `_ordered` puts round zero first,
  // so the head of that list is every item's nearest alert. If the second
  // shape comes back, the headroom under the cap is not spare room for stray
  // notifications as this repo's comments claim: it is the only thing between
  // an over-long list and silently losing its most urgent reminders.
  //
  // iOS only. On Android the read-back is the plugin's own record of what it
  // was told, so it can only ever hand back all of them in the order given.
  testWidgets('which ones iOS keeps when asked for too many', (_) async {
    if (!onIos) {
      // ignore: avoid_print
      print('ORDER skipped: only UNUserNotificationCenter can answer this');
      return;
    }

    const asked = 100;
    await ask(asked);

    final byId = {for (var i = 0; i < asked; i++) probe(i).numericId: i};
    final survivors = [
      for (final p in await plugin.pendingNotificationRequests()) ?byId[p.id],
    ]..sort();

    // ignore: avoid_print
    print(
      'ORDER asked=$asked kept=${survivors.length} '
      'lowest=${survivors.take(5).toList()} '
      'highest=${survivors.sublist(survivors.length - 5).toList()}',
    );
    // ignore: avoid_print
    print(
      survivors.length == asked
          ? 'ORDER verdict: no ceiling at $asked, raise it and run again'
          : survivors.first == 0
          ? 'ORDER verdict: SOONEST kept, overflow costs the furthest-out'
          : 'ORDER verdict: LAST-ADDED kept, overflow costs the nearest',
    );

    expect(survivors, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 6)));

  // Android's ceiling, if it has one, announces itself by throwing rather than
  // by a shrinking count. The README reports Samsung capping AlarmManager at
  // 500; nothing is published for stock Android. A clean run here is a real
  // result: it says this device took the number without complaint.
  testWidgets('where Android starts refusing alarms', (_) async {
    if (onIos) return;

    const ladder = [100, 200, 400, 499, 500, 501, 600];
    for (final n in ladder) {
      try {
        await ask(n);
        // ignore: avoid_print
        print('ANDROID asked=$n ok');
      } catch (error) {
        // ignore: avoid_print
        print('ANDROID asked=$n THREW ${error.runtimeType}: $error');
        break;
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
