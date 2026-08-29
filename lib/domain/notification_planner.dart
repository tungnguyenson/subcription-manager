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
/// "schedule a reminder" call. Both platforms cap what one app may hold, and
/// deciding here, and reporting what did not fit, is the only way the app can
/// say anything true about what it will remind you of. See product-spec.md
/// section 7.3.
///
/// Both figures are measured rather than quoted, by
/// `integration_test/notification_ceiling_test.dart`.
///
/// **iOS keeps exactly 64**, on an iPhone running iOS 26.5: ask for 65 and it
/// holds 64, ask for 128 and it still holds 64. The number matches the one
/// everyone repeats, which was worth confirming, since no page of Apple's
/// states it any more.
///
/// **Which 64 is the part that was written down wrong here for a long time.**
/// Handed a hundred requests in date order, iOS keeps the *last sixty-four
/// added*, not the sixty-four firing soonest. Overflowing does not shed the
/// far future; it sheds whatever went in first. `NotificationScheduler.apply`
/// answers that by adding this list in reverse, so the head of it -- round
/// zero, every item's nearest alert -- is handed over last.
///
/// **Android throws instead of truncating.** The 501st alarm comes back as
/// `IllegalStateException: Maximum limit of concurrent alarms 500 reached for
/// uid`, measured on a Pixel 4 XL on Android 13, so this is AOSP and not the
/// Samsung quirk the plugin's README describes. A throw is worse than a
/// truncation here: one aborts the whole `apply` loop and leaves the user with
/// no reminders at all rather than fewer.
///
/// So the tighter iOS budget runs on both. The cost is that a heavy Android
/// list truncates at a tenth of what the platform would take; the benefit is
/// one number, measured, that the app can print to the user and stand behind.
///
/// Pure function, so the ranking and truncation rules are testable without a
/// device.
abstract final class NotificationPlanner {
  /// Fifty against a measured ceiling of 64, and the fourteen left over are
  /// not spare room for stray notifications the way this comment used to say.
  /// The app posts exactly one notification outside the plan, the test
  /// reminder, and it holds a slot for ten seconds.
  ///
  /// They are there because overflow is not a graceful degradation. iOS keeps
  /// the last 64 handed to it, so going over the line drops whatever went in
  /// first, and Android does not drop anything -- it throws, and one throw
  /// costs the user every reminder rather than the marginal one. Fourteen
  /// slots is the margin for a ceiling measured on one device and one OS
  /// version. Raise it against a wider set of measurements, not against this
  /// comment.
  ///
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

  /// How many nags one item may hold at once.
  ///
  /// Two weeks of a daily nag, fourteen weeks of a weekly one. The horizon
  /// above says a nag for a deadline that is still far off is not worth
  /// scheduling; this says the same thing about the fortieth repeat of one
  /// that is.
  ///
  /// It is a count and not a span because the budget is spent in counts. An
  /// overdue item on a daily shelf used to enumerate one alert per day to the
  /// horizon -- sixty-one of them, forty of which fitted -- so a single
  /// unhandled bill said the same sentence forty times while every other
  /// item's second rung was dropped for want of room.
  ///
  /// Refilled on the way back in: the planner runs again on every resume and
  /// hands the next fortnight back. Giving up after two weeks only bites a
  /// user who has not opened the app in two weeks, and for them the sixty-one
  /// were doing nothing either.
  static const int maxNagsPerItem = 14;

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
      ]..sort(_beforeTheDeadlineFirst);
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

  /// Inside one round: everything that arrives before the deadline, then the
  /// nags, and soonest first within each.
  ///
  /// The two are not worth the same slot. A lead rung is the app's whole
  /// purpose -- it lands while the thing can still be prevented. A nag lands
  /// after the fact, on a day when the provider is already sending its own
  /// message and the service is already being cut, so it repeats news the
  /// user is about to get anyway. Ordering the round by date alone gave the
  /// slot to whichever alert was nearest, and a nag is always nearest: it
  /// starts the day after a deadline that has already gone by, while the rung
  /// it displaces belongs to a deadline still weeks out and still avoidable.
  static int _beforeTheDeadlineFirst(PlannedAlert a, PlannedAlert b) {
    final aNag = a.reason == AlertReason.nag ? 1 : 0;
    final bNag = b.reason == AlertReason.nag ? 1 : 0;
    if (aNag != bNag) return aNag - bNag;
    return _ranking(a, b);
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
    while (at <= horizon && out.length < maxNagsPerItem) {
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
