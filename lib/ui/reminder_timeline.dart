import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/ui/item_presenter.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/i18n.dart';

/// What kind of thing a row on the timeline is.
///
/// Two of these are not notifications. [deadline] is the reason the timeline
/// exists: a reminder dated after it is a reminder that arrives once the money
/// is already gone, and no amount of wording on a single "next reminder" line
/// can show that. [trial] is the state the item is in today, and it is here so
/// that "free now" and "charged on the 23rd" are read as one run of time
/// rather than as two cards that happen to sit on the same screen.
enum TimelineKind { trial, lead, deadline, snoozed, nag, verify }

/// One row of "what happens next" for a single item.
class TimelineStop {
  final LocalDate date;

  /// The send time, or null for the [TimelineKind.deadline] marker. A deadline
  /// is a day, not a minute; printing a time against it would invent one.
  final LocalTime? time;

  final TimelineKind kind;

  /// The row's own words: `1 day before`, `You asked to be reminded`.
  final String label;

  /// The second line, for the rows that are not notifications: the amount that
  /// moves on a deadline, how much of a trial is left. Worded here rather than
  /// in the widget because it is the answer to "which day takes how much", and
  /// that answer has to be testable without pumping a screen.
  ///
  /// A notification row leaves this null and gets its send time instead.
  final String? detail;

  /// The soonest notification still coming. The deadline marker never carries
  /// it, because it is not something the app will send.
  final bool isNext;

  /// Already behind us. Only a deadline can be: the planner never hands back
  /// an alert in the past.
  final bool isPast;

  const TimelineStop({
    required this.date,
    required this.kind,
    required this.label,
    this.detail,
    this.time,
    this.isNext = false,
    this.isPast = false,
  });
}

/// The whole block, deadline markers included.
///
/// The deadline is on it even when no reminder is: a date the user is going to
/// be held to does not stop existing because the ladder ran out, and a block
/// that vanished in that case would take the one row that still mattered with
/// it. So this is never empty for a real item, and the silence is explained in
/// [silence] instead.
class ReminderTimeline {
  final List<TimelineStop> stops;

  /// Why no notification is coming, when none is. Null while any is scheduled.
  ///
  /// A timeline of deadlines with no reminders on it and no explanation reads
  /// as a bug. It has three quite different causes and the user can only fix
  /// two of them.
  final String? silence;

  /// How many of this item's own dated alerts the budget pushed out, so the
  /// timeline never quietly shows a shorter future than the one it computed.
  ///
  /// Nags are not counted -- see [ReminderTimelinePresenter.of].
  final int droppedForItem;

  const ReminderTimeline({
    required this.stops,
    this.silence,
    this.droppedForItem = 0,
  });

  bool get isEmpty => stops.isEmpty;

  /// The footnote under the block, or null when there is nothing to add.
  String? get note {
    final parts = [
      ?silence,
      if (droppedForItem > 0)
        S.t.timelineDropped(droppedForItem, NotificationPlanner.budget),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}

abstract final class ReminderTimelinePresenter {
  /// Builds the timeline from the plan rather than from [item.leadDays].
  ///
  /// The plan is what is actually pending on the device, which is the only
  /// thing worth drawing. A ladder rebuilt from the item's own lead days looks
  /// right and is wrong in every way that matters here: it cannot see a snooze,
  /// it cannot see a nag, it does not know today's 08:30 rung has already
  /// fired, and it does not know the budget dropped anything.
  static ReminderTimeline of({
    required TrackedItem item,
    required Category category,
    required List<PlannedAlert> alerts,
    required List<PlannedAlert> dropped,
    required LocalDate today,
  }) {
    final mine = alerts.where((a) => a.itemId == item.id).toList();

    // Dropped nags are not a loss worth reporting, and counting them was
    // alarming about nothing. A daily nag enumerates one alert per day to the
    // 60-day horizon, so a single overdue item overruns the budget on its own
    // and the footnote read "10 further reminders did not fit" directly under
    // a row promising the nag every day. Both are true: the planner re-runs as
    // the nearer alerts pass and hands the later nags back, so the cadence is
    // kept even though today's plan cannot hold all of it.
    //
    // A dropped lead, snooze or verify is the opposite. Each names one day the
    // user would otherwise expect to hear from the app on, and there is no
    // second chance to deliver it.
    final myDropped = dropped
        .where((a) => a.itemId == item.id && a.reason != AlertReason.nag)
        .length;

    final stops = <TimelineStop>[
      ..._trialStop(item, today),
      ..._markers(item, category, today),
      ..._alertStops(mine),
    ]..sort(_byDate);

    _markNext(stops);

    return ReminderTimeline(
      stops: stops,
      silence: _silence(item, mine),
      droppedForItem: myDropped,
    );
  }

  /// The dates the ladder counts back from.
  ///
  /// Two rows when the act-by date is not the expiry date, one when they are
  /// the same day. Collapsing them always would hide the gap the user
  /// deliberately asked for; splitting them always would print the same date
  /// twice under two names on the great majority of items.
  static List<TimelineStop> _markers(
    TrackedItem item,
    Category category,
    LocalDate today,
  ) {
    final expires = item.expiresOn;
    final actBy = item.actBy;
    final expiring = category.wording == CategoryWording.expires;
    final trial = item.isTrialOn(today);

    return [
      if (actBy != expires)
        TimelineStop(
          date: actBy,
          kind: TimelineKind.deadline,
          label: S.t.timelineActBy,
          detail: actBy < today ? S.t.timelineAlreadyPassed : null,
          isPast: actBy < today,
        ),
      TimelineStop(
        date: expires,
        kind: TimelineKind.deadline,
        // `First payment` while the trial is running, because on that item
        // this day is not one charge among many -- it is the one the whole
        // trial was counting down to.
        label: expiring
            ? S.t.timelineExpires
            : trial
            ? S.t.timelineFirstPayment
            : S.t.timelinePaymentDue,
        detail: _dueDetail(item, expiring: expiring, past: expires < today),
        isPast: expires < today,
      ),
    ];
  }

  /// How much moves on the deadline, and whether the day is behind us.
  ///
  /// The amount is what stops this row reading like the reminders above it. A
  /// column where every row carries a date and a sentence leaves the user
  /// counting rings to find the day the money actually goes.
  ///
  /// `charged` is only said on a shelf whose wording is *Due*, where somebody
  /// else takes the money on the day. On an expiring shelf -- a prepaid SIM, a
  /// licence -- the price is what renewing costs and no one debits it, so the
  /// number stands alone. Past dates drop the verb entirely: the app has no
  /// idea whether the charge went through, only that the day is gone.
  static String? _dueDetail(
    TrackedItem item, {
    required bool expiring,
    required bool past,
  }) {
    final money = item.money;
    final amount = money == null ? null : MoneyFormat.full(money);
    if (past) return [?amount, S.t.timelineAlreadyPassed].join(S.t.bullet);
    if (amount == null) return null;
    return expiring ? amount : S.t.timelineCharged(amount);
  }

  /// Today's row on an item in a free trial: the only fact in this block that
  /// is about now rather than about a date still coming.
  ///
  /// This used to be a card of its own above the block. Three of the four
  /// things it said -- the charge date, the amount, the reminder that is
  /// coming -- are rows of this column already, said there by the plan itself
  /// rather than by a second piece of wording that could drift from it. What
  /// only the card could say is this: today is free, and for how much longer.
  ///
  /// Dated today because a trial has no date of its own. The day it ends is
  /// `expiresOn`, which is the deadline row right below it. See trap 14.
  static List<TimelineStop> _trialStop(TrackedItem item, LocalDate today) {
    if (!item.isTrialOn(today)) return const [];

    final left = today.daysUntil(item.expiresOn);
    return [
      TimelineStop(
        date: today,
        kind: TimelineKind.trial,
        // The countdown as the headline, not the date. A date needs arithmetic
        // before it means anything; `28 more days` does not, and the date is
        // on the row below anyway.
        //
        // Never `0 more days`: `isTrialOn` is `today < expiresOn`, so this row
        // is already gone on the morning of the charge.
        label: S.t.timelineFreeForDays(left),
        detail: S.t.timelineNothingChargedYet,
      ),
    ];
  }

  /// The planned alerts, with the nag run collapsed to its first firing.
  ///
  /// A daily nag enumerates one alert per day out to the 60-day horizon. Drawn
  /// literally that is fifty-odd identical rows saying the same sentence, and
  /// they would bury the three rows the user came here to read. The repeat is
  /// a rule, so it is stated as one.
  static List<TimelineStop> _alertStops(List<PlannedAlert> mine) {
    final nags = mine.where((a) => a.reason == AlertReason.nag).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return [
      for (final alert in mine)
        if (alert.reason != AlertReason.nag)
          TimelineStop(
            date: alert.date,
            time: alert.time,
            kind: _kindOf(alert.reason),
            label: _labelOf(alert),
          ),
      if (nags.isNotEmpty)
        TimelineStop(
          date: nags.first.date,
          time: nags.first.time,
          kind: TimelineKind.nag,
          label: nags.length == 1 ? S.t.timelineNag : _nagLabel(nags),
        ),
    ];
  }

  /// `Then every day until you mark it as paid`, with the step read off the
  /// gap between the first two rather than from the policy enum, so the row
  /// can never claim a cadence the plan is not actually holding.
  static String _nagLabel(List<PlannedAlert> nags) =>
      S.t.timelineNagEvery(nags.first.date.daysUntil(nags[1].date));

  static TimelineKind _kindOf(AlertReason reason) => switch (reason) {
    AlertReason.lead => TimelineKind.lead,
    AlertReason.snoozed => TimelineKind.snoozed,
    AlertReason.verify => TimelineKind.verify,
    AlertReason.nag => TimelineKind.nag,
  };

  static String _labelOf(PlannedAlert alert) => switch (alert.reason) {
    AlertReason.lead => ItemPresenter.leadLabel(alert.leadDays),
    // The user's own words back at them. This row exists because they pressed
    // a button that said "remind me again", and the phrasing is the receipt.
    AlertReason.snoozed => S.t.timelineSnoozed,
    AlertReason.verify => S.t.timelineVerify,
    AlertReason.nag => S.t.timelineNag,
  };

  /// Alerts before the marker on a shared date: an 08:30 reminder on the due
  /// day genuinely does come before the day is over, and reading the marker
  /// first would say the opposite.
  static int _byDate(TimelineStop a, TimelineStop b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return _rank(a).compareTo(_rank(b));
  }

  /// Within one day: what is true already, then what the app will send, then
  /// the day's own deadline. The trial row is first because it describes the
  /// state the rest of that day is being read out of.
  static int _rank(TimelineStop stop) => switch (stop.kind) {
    TimelineKind.trial => 0,
    TimelineKind.deadline => 2,
    _ => 1,
  };

  /// Marks the first row that is an actual notification. Done by mutation over
  /// the sorted list rather than during construction, because "next" is a fact
  /// about the merged order and the markers are interleaved into it.
  static void _markNext(List<TimelineStop> stops) {
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      if (stop.kind == TimelineKind.deadline) continue;
      if (stop.kind == TimelineKind.trial) continue;
      stops[i] = TimelineStop(
        date: stop.date,
        time: stop.time,
        kind: stop.kind,
        label: stop.label,
        detail: stop.detail,
        isNext: true,
        isPast: stop.isPast,
      );
      return;
    }
  }

  /// Said out loud rather than left to an empty block.
  ///
  /// Three causes, and they are not the same problem: the switch on the
  /// service list is one tap to undo, an archived item is not coming back on
  /// its own, and an empty ladder is a trip to the Reminders screen.
  static String? _silence(TrackedItem item, List<PlannedAlert> mine) {
    if (mine.isNotEmpty) return null;
    if (item.paused) return S.t.timelineSilentPaused;
    if (item.state != ItemState.active) return S.t.timelineSilentClosed;
    return S.t.timelineSilentLadderDone;
  }

  /// `27/08`, or `27/08/2026` once the year stops being the obvious one.
  ///
  /// A yearly renewal thirteen months out reads as an urgent date without it,
  /// and a passport can be five years out.
  static String dateLabel(LocalDate date, LocalDate today) =>
      date.year == today.year
      ? MoneyFormat.shortDate(date)
      : MoneyFormat.date(date);
}
