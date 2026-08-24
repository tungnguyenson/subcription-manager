import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/ui/money_format.dart';

enum ReminderStatus {
  /// Already fired, or would have.
  past,

  /// The next one that will fire.
  next,

  /// Scheduled, but not the soonest.
  upcoming,

  /// The lead time was already behind the item when it was added, so this rung
  /// never had a chance to fire. Shown rather than hidden: a ladder with a
  /// missing rung looks like a bug, and "you added this too late for a 30-day
  /// warning" is a fact the user should know.
  missed,
}

/// One rung of the reminder ladder, as the screen shows it.
class ReminderRung {
  final int leadDays;
  final LocalDate fireOn;
  final ReminderStatus status;

  const ReminderRung({
    required this.leadDays,
    required this.fireOn,
    required this.status,
  });

  String get label => leadDays == 0
      ? 'On the day'
      : '$leadDays ${leadDays == 1 ? "day" : "days"} before';
}

abstract final class RemindersPresenter {
  /// Builds the ladder for [item] as of [today].
  ///
  /// [createdOn] is when the item was added; a rung whose date fell before that
  /// is [ReminderStatus.missed] rather than [ReminderStatus.past], because it
  /// never existed rather than having come and gone.
  static List<ReminderRung> ladder(
    TrackedItem item,
    LocalDate today, {
    LocalDate? createdOn,
  }) {
    final actBy = item.actBy;
    final leads = [...item.leadDays]..sort((a, b) => b.compareTo(a));

    final fireDates = {for (final lead in leads) lead: actBy.minusDays(lead)};

    // The soonest rung still ahead is the one the user actually cares about.
    LocalDate? nextDate;
    for (final lead in leads) {
      final date = fireDates[lead]!;
      if (date >= today && (nextDate == null || date < nextDate)) {
        nextDate = date;
      }
    }

    return [
      for (final lead in leads)
        ReminderRung(
          leadDays: lead,
          fireOn: fireDates[lead]!,
          status: _statusOf(fireDates[lead]!, today, nextDate, createdOn),
        ),
    ];
  }

  static ReminderStatus _statusOf(
    LocalDate fireOn,
    LocalDate today,
    LocalDate? nextDate,
    LocalDate? createdOn,
  ) {
    if (createdOn != null && fireOn < createdOn) return ReminderStatus.missed;
    if (fireOn < today) return ReminderStatus.past;
    return fireOn == nextDate ? ReminderStatus.next : ReminderStatus.upcoming;
  }

  /// The line under a rung: the date, plus what it means.
  static String detail(ReminderRung rung, LocalTime at) {
    final date = MoneyFormat.shortDate(rung.fireOn);
    return switch (rung.status) {
      ReminderStatus.missed =>
        'would have been $date — already past when added',
      ReminderStatus.past => '$date · sent',
      ReminderStatus.next => '$date at $at · next',
      ReminderStatus.upcoming => '$date at $at',
    };
  }

  /// The clause under the screen title. States what the ladder counts back
  /// from, because "3 days before" is meaningless without it.
  static String anchorLine(TrackedItem item) {
    final actBy = item.actBy;
    final from = 'counted back from ${MoneyFormat.shortDate(actBy)}';

    final reason = actBy == item.expiresOn
        ? 'the expiry date'
        : 'the act-by date, ${item.actByOffsetDays} days before it expires';

    return '$from, $reason';
  }

  /// How much of the device's notification budget this item holds.
  ///
  /// The budget is a real shared resource, so the screen says so out loud. It
  /// is stated as the app's own limit rather than the platform's: the number
  /// comes from iOS keeping only 64 pending notifications per app, and the
  /// same allocation runs on Android because the app has no verified figure
  /// for that platform and will not print one it cannot stand behind.
  static String budgetLine(int held, int droppedElsewhere) {
    final base =
        'Holds $held of the '
        '${NotificationPlanner.budget} reminder slots this app schedules.';
    return droppedElsewhere == 0
        ? base
        : '$base $droppedElsewhere reminders on other items had to be dropped.';
  }
}
