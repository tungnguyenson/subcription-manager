import 'package:meta/meta.dart';

import 'category_book.dart';
import 'local_date.dart';
import 'model.dart';

enum AlertReason {
  /// Scheduled ahead of the act-by date.
  lead,

  /// Repeat after the act-by date passed with no "done".
  nag,

  /// Periodic prompt to re-check the date against its real source.
  verify,

  /// The one the user asked for by postponing.
  snoozed,
}

/// One notification the app intends to have pending with iOS.
@immutable
class PlannedAlert {
  final String itemId;
  final String itemName;
  final LocalDate date;
  final LocalTime time;
  final int leadDays;
  final AlertReason reason;
  final bool timeSensitive;

  /// A clause appended to the notification body, or null.
  ///
  /// Deliberately a rider on an existing alert rather than an alert of its own.
  /// The user asking to be reminded that a plan is cheaper yearly wants to hear
  /// it *when the renewal comes up*, which is a notification they were already
  /// getting — and the budget in this class is 50 slots for the whole app, so
  /// spending a second one to say one more sentence is the wrong trade.
  final String? note;

  const PlannedAlert({
    required this.itemId,
    required this.itemName,
    required this.date,
    required this.time,
    required this.leadDays,
    required this.reason,
    required this.timeSensitive,
    this.note,
  });

  /// What the notification says under its title.
  String get body => note == null ? itemName : '$itemName · $note';

  /// Stable across re-planning runs so iOS de-duplicates rather than stacking.
  /// The planner cancels everything and re-adds on each run, but a stable id
  /// still makes logs and tests readable.
  String get identifier => '$itemId|${reason.name}|$date|$leadDays';

  /// iOS and Android both key pending notifications by a 32-bit int, so the
  /// string identifier has to collapse to one.
  ///
  /// Hashed with FNV-1a rather than [String.hashCode]. Dart makes no promise
  /// that `hashCode` is the same in two different processes, and this number
  /// has to survive an app restart: the scheduler cancels by id, so an id that
  /// changes between launches would leave the old notification pending
  /// forever and stack a duplicate beside it.
  int get numericId {
    var hash = 0x811c9dc5;
    for (final unit in identifier.codeUnits) {
      hash = (hash ^ unit) & 0xffffffff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// What the planner produced, including what it had to leave out.
@immutable
class NotificationPlan {
  final List<PlannedAlert> alerts;

  /// Alerts that did not fit the budget. Never drop these silently.
  final List<PlannedAlert> dropped;

  const NotificationPlan({required this.alerts, required this.dropped});

  bool get isTruncated => dropped.isNotEmpty;
}

/// Turns the item list into the set of notifications to have pending.
///
/// This is an allocator against a hard resource budget, not a per-item
/// "schedule a reminder" call. iOS keeps at most 64 pending local notifications
/// per app and silently evicts the furthest-out ones past that, without telling
/// the app which ones. Deciding here, and reporting what did not fit, is the
/// only way the app can say anything true about what it will remind you of.
/// See product-spec.md section 7.3.
///
/// Android is not known to cap pending alarms the same way, and no figure for
/// it is published that this app could cite. So the iOS budget runs on both
/// rather than a guessed larger one: the cost is that a heavy Android list
/// truncates earlier than it strictly must, and the alternative is a number
/// the app cannot stand behind -- printed to the user, on a screen whose whole
/// job is telling them what will and will not be delivered.
///
/// Pure function, so the ranking and truncation rules are testable without a
/// device.
abstract final class NotificationPlanner {
  /// iOS keeps 64; leave headroom so nothing we schedule evicts anything else.
  /// Applied on Android too -- see the note on this class.
  static const int budget = 50;

  /// Alerts further out than this are not scheduled; a later re-plan picks
  /// them up.
  static const int horizonDays = 60;

  static NotificationPlan plan(
    List<TrackedItem> items,
    CategoryBook categories,
    LocalDate today, {
    int budget = NotificationPlanner.budget,
    int horizonDays = NotificationPlanner.horizonDays,
  }) {
    final horizon = today.plusDays(horizonDays);

    final candidates = <PlannedAlert>[
      for (final item in items)
        // `isLive` and not a bare state check: an item the user switched off
        // on the service list is still ACTIVE, and the whole promise of that
        // switch is that it stops sending reminders. One predicate for the
        // list and the planner, so they can never disagree about it.
        if (item.isLive && item.state == ItemState.active)
          ..._alertsFor(item, categories[item.categoryId], today, horizon),
    ]..sort(_ranking);

    return NotificationPlan(
      alerts: List.unmodifiable(candidates.take(budget)),
      dropped: List.unmodifiable(candidates.skip(budget)),
    );
  }

  /// Soonest first.
  ///
  /// There is no severity axis to rank by any more, so the budget is spent on
  /// what happens next. That is the honest allocation once every item is equal:
  /// the alerts that get dropped are the ones furthest out, and a later re-plan
  /// picks them up once they come inside the horizon.
  ///
  /// The identifier tiebreaker at the end is not cosmetic. Dart's [List.sort]
  /// is not guaranteed stable, so a comparator that returns 0 for two distinct
  /// alerts lets their order vary between runs. At the budget boundary that
  /// means a different alert is dropped each time the app re-plans, which is
  /// exactly the silent, irreproducible loss this class exists to prevent.
  static int _ranking(PlannedAlert a, PlannedAlert b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byLead = a.leadDays.compareTo(b.leadDays);
    if (byLead != 0) return byLead;
    return a.identifier.compareTo(b.identifier);
  }

  static List<PlannedAlert> _alertsFor(
    TrackedItem item,
    Category category,
    LocalDate today,
    LocalDate horizon,
  ) {
    final out = <PlannedAlert>[];
    final actBy = item.actBy;

    // The rider the user asked for on the Savings screen. It rides on the
    // lead reminders only: a nag fires *after* the money has gone, and telling
    // someone the yearly plan is cheaper at that point is worse than silence.
    final note = item.yearlyChoice == YearlyChoice.remind
        ? 'Yearly costs less'
        : null;

    for (final lead in item.leadDays) {
      final fireOn = actBy.minusDays(lead);
      if (fireOn.isBetween(today, horizon)) {
        out.add(
          _alert(item, category, fireOn, lead, AlertReason.lead, note: note),
        );
      }
    }

    // A snooze is what the user asked for by name, so it is scheduled even
    // when the ladder for this item is empty.
    final snoozed = item.snoozedUntil;
    if (snoozed != null && snoozed.isBetween(today, horizon)) {
      out.add(_alert(item, category, snoozed, 0, AlertReason.snoozed));
    }

    out.addAll(_nagAlerts(item, category, actBy, today, horizon));

    final verify = _verifyAlert(item, category, today, horizon);
    if (verify != null) out.add(verify);

    return out;
  }

  /// Repeats after the deadline for items the user must not be allowed to
  /// silently ignore. Swiping a notification away is not the same as handling
  /// it, so these keep coming back until an occurrence is marked done.
  ///
  /// Enumerated as individual alerts rather than an iOS repeating trigger,
  /// because a repeating trigger cannot vary its text per firing and cannot be
  /// cancelled for one occurrence only.
  static List<PlannedAlert> _nagAlerts(
    TrackedItem item,
    Category category,
    LocalDate actBy,
    LocalDate today,
    LocalDate horizon,
  ) {
    final stepDays = switch (item.nagAfterDue) {
      NagPolicy.none => null,
      NagPolicy.daily => 1,
      NagPolicy.weekly => 7,
    };
    if (stepDays == null) return const [];

    final out = <PlannedAlert>[];
    var at = LocalDate.max(actBy.plusDays(stepDays), today);
    while (at <= horizon) {
      out.add(_alert(item, category, at, 0, AlertReason.nag));
      at = at.plusDays(stepDays);
    }
    return out;
  }

  /// Prompt to re-check a date against its real source. Independent of the due
  /// date: a prepaid balance's validity moves every time the user tops up, and
  /// the app has no way to notice. See spec section 7.5.
  static PlannedAlert? _verifyAlert(
    TrackedItem item,
    Category category,
    LocalDate today,
    LocalDate horizon,
  ) {
    final every = item.verifyEveryDays;
    if (every == null) return null;

    final since = item.lastVerifiedAt ?? item.anchorDate;
    final due = since.plusDays(every);
    final fireOn = LocalDate.max(due, today);
    return fireOn <= horizon
        ? _alert(item, category, fireOn, 0, AlertReason.verify)
        : null;
  }

  static PlannedAlert _alert(
    TrackedItem item,
    Category category,
    LocalDate date,
    int lead,
    AlertReason reason, {
    String? note,
  }) => PlannedAlert(
    itemId: item.id,
    itemName: item.name,
    date: date,
    time: item.remindAt,
    leadDays: lead,
    reason: reason,
    timeSensitive: category.isTimeSensitive,
    note: note,
  );
}
