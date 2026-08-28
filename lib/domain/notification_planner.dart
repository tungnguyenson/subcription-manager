import 'package:meta/meta.dart';

import 'category_book.dart';
import 'local_date.dart';
import 'model.dart';

import 'package:subdock/i18n.dart';

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

  /// How far ahead a nag is enumerated, and nothing else.
  ///
  /// It used to bound every alert, and that was one job too many. A lead rung,
  /// a snooze and a verify are *countable*: an item has as many lead alerts as
  /// it has rungs, one snooze and one verify, so the whole list is bounded by
  /// the items themselves and the [budget] is the only rationing needed. A nag
  /// is not countable -- it is one alert per step for as long as the thing
  /// stays undone, forever -- so something has to say where to stop, and this
  /// is it.
  ///
  /// Bounding the countable ones too is what made a passport eighteen months
  /// out show `What happens next` with the deadline on it and no reminder,
  /// under a footnote saying every step of its ladder had already passed. Both
  /// halves were wrong: the ladder had not started, and the app was not going
  /// to be reminded of it by anything other than the user opening the app
  /// inside a sixty-day window five hundred days from now. Both iOS and
  /// Android take a trigger dated any distance ahead, and Android re-registers
  /// them after a reboot through `ScheduledNotificationBootReceiver`, so there
  /// was never a platform reason to hold one back.
  static const int horizonDays = 60;

  /// [now] is the clock, not just the calendar day.
  ///
  /// The time of day is an input to the plan and not decoration on it. An
  /// alert dated today at 08:30 stops being the next one at 08:31, and nothing
  /// in the database changes at that minute -- so a planner given only a date
  /// keeps offering an alert that has already been and gone. Handing that to
  /// the scheduler is worse than cosmetic: iOS never fires a trigger whose
  /// time is in the past, and Android fires it the instant it is set. Either
  /// way it spends one of the [budget] slots on nothing.
  static NotificationPlan plan(
    List<TrackedItem> items,
    CategoryBook categories,
    LocalDateTime now, {
    int budget = NotificationPlanner.budget,
    int horizonDays = NotificationPlanner.horizonDays,
  }) {
    final horizon = now.date.plusDays(horizonDays);

    // Grouped by item rather than poured into one list, because the budget is
    // shared out a round at a time -- see [_ordered].
    final byItem = <List<PlannedAlert>>[
      for (final item in items)
        // `isLive` and not a bare state check: an item the user switched off
        // on the service list is still ACTIVE, and the whole promise of that
        // switch is that it stops sending reminders. One predicate for the
        // list and the planner, so they can never disagree about it.
        if (item.isLive && item.state == ItemState.active)
          _alertsFor(item, categories[item.categoryId], now, horizon)
            ..sort(_ranking),
    ];

    final ordered = _ordered(byItem);

    return NotificationPlan(
      alerts: List.unmodifiable(ordered.take(budget)),
      dropped: List.unmodifiable(ordered.skip(budget)),
    );
  }

  /// Every item heard from once before any item is heard from twice.
  ///
  /// Round 0 is each item's soonest alert, round 1 each item's second, and so
  /// on; inside a round it is still soonest first. Sorting the whole pile by
  /// date instead -- which is what this did -- hands the budget to whichever
  /// item happens to generate the densest run of near dates, and one overdue
  /// item nagging daily generates sixty of them. It took all fifty slots and
  /// every other item on the list went silent, with nothing on any screen
  /// saying so.
  ///
  /// Round order is the order [items] came in, which is the caller's order and
  /// therefore stable across re-plans. That matters at the budget edge for the
  /// same reason the identifier tiebreaker in [_ranking] does.
  static List<PlannedAlert> _ordered(List<List<PlannedAlert>> byItem) {
    final out = <PlannedAlert>[];
    final deepest = byItem.fold(0, (n, l) => l.length > n ? l.length : n);

    for (var round = 0; round < deepest; round++) {
      final take = [
        for (final alerts in byItem)
          if (round < alerts.length) alerts[round],
      ]..sort(_ranking);
      out.addAll(take);
    }
    return out;
  }

  /// Soonest first, within one item and within one round of [_ordered].
  ///
  /// There is no severity ranking to apply any more, so what is left is what
  /// happens next. That is the honest allocation once every item is equal.
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
    LocalDateTime now,
    LocalDate horizon,
  ) {
    final out = <PlannedAlert>[];
    final actBy = item.actBy;

    // The first day this item still has a reminder left to give. Per item,
    // because the send time is per item: at 18:40 an item set to 08:30 is done
    // for the day while one set to 21:00 is not.
    //
    // Strictly earlier, not "at or earlier". [LocalTime] has no seconds, so an
    // alert whose minute is the current minute may already have fired forty
    // seconds ago; re-scheduling it would fire a second copy immediately.
    // Being one minute pessimistic costs nothing, being one minute optimistic
    // costs the user a duplicate.
    final earliest = now.time < item.remindAt ? now.date : now.date.plusDays(1);

    // The rider the user asked for on the Savings screen. It rides on the
    // lead reminders only: a nag fires *after* the money has gone, and telling
    // someone the yearly plan is cheaper at that point is worse than silence.
    final note = item.yearlyChoice == YearlyChoice.remind
        ? S.t.notifYearlyCostsLess
        : null;

    for (final lead in item.leadDays) {
      final fireOn = actBy.minusDays(lead);
      // Floor rather than a clamp: a lead rung names a specific day relative
      // to the deadline. Once today's has passed it is gone, and moving it to
      // tomorrow would tell the user "3 days before" on the day that is two
      // days before.
      //
      // No ceiling. A rung five hundred days out is scheduled five hundred
      // days out, because the alternative is a screen that promises a reminder
      // it has not asked the system for. See [horizonDays].
      if (fireOn >= earliest) {
        out.add(
          _alert(item, category, fireOn, lead, AlertReason.lead, note: note),
        );
      }
    }

    // A snooze is what the user asked for by name, so it is scheduled even
    // when the ladder for this item is empty.
    final snoozed = item.snoozedUntil;
    if (snoozed != null && snoozed >= earliest) {
      out.add(_alert(item, category, snoozed, 0, AlertReason.snoozed));
    }

    out.addAll(_nagAlerts(item, category, actBy, earliest, horizon));

    final verify = _verifyAlert(item, category, earliest);
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
    LocalDate earliest,
    LocalDate horizon,
  ) {
    final stepDays = switch (item.nagAfterDue) {
      NagPolicy.none => null,
      NagPolicy.daily => 1,
      NagPolicy.weekly => 7,
    };
    if (stepDays == null) return const [];

    final out = <PlannedAlert>[];
    // Clamped rather than range-checked, unlike a lead rung. A nag says "this
    // is still not done", which is as true tomorrow as it was at 08:30 today,
    // so the one that passed slides forward instead of being lost.
    var at = LocalDate.max(actBy.plusDays(stepDays), earliest);
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
    LocalDate earliest,
  ) {
    final every = item.verifyEveryDays;
    if (every == null) return null;

    final since = item.lastVerifiedAt ?? item.anchorDate;
    final due = since.plusDays(every);
    // Clamped for the same reason as a nag: a prompt to re-check a date keeps
    // being worth sending, so a missed one moves rather than disappears.
    final fireOn = LocalDate.max(due, earliest);
    return _alert(item, category, fireOn, 0, AlertReason.verify);
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
