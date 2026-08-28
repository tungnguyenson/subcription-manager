import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/item_actions.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/reminders.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/reminder_timeline.dart';

/// Driven through the real planner rather than a hand-built alert list.
///
/// The bug this block exists to prevent is a disagreement between what the app
/// schedules and what it says it scheduled, so a test that invents its own
/// alerts cannot see it.
void main() {
  final today = LocalDate.parse('2026-08-26');
  final now = LocalDateTime(today, const LocalTime(0, 0));
  LocalDate d(String iso) => LocalDate.parse(iso);

  final streaming = CategoryBook.shipped['STREAMING'];

  TrackedItem item({
    required String expiresOn,
    Category? category,
    List<int> leadDays = const [3, 1],
    NagPolicy nag = NagPolicy.none,
    int actByOffsetDays = 0,
    int? verifyEveryDays,
    bool paused = false,
    ItemState state = ItemState.active,
    LocalDate? snoozedUntil,
    int? amountMinor,
    String currency = 'VND',
    bool inTrial = false,
  }) {
    final shelf = category ?? streaming;
    return TrackedItem(
      id: 'i1',
      name: 'Netflix',
      categoryId: shelf.id,
      expiresOn: d(expiresOn),
      anchorDate: d(expiresOn),
      actByOffsetDays: actByOffsetDays,
      leadDays: leadDays,
      nagAfterDue: nag,
      verifyEveryDays: verifyEveryDays,
      remindAt: Reminders.defaultRemindAt,
      paused: paused,
      state: state,
      snoozedUntil: snoozedUntil,
      amountMinor: amountMinor,
      currency: amountMinor == null ? null : currency,
      inTrial: inTrial,
    );
  }

  ReminderTimeline build(TrackedItem it, {Category? category}) {
    final plan = NotificationPlanner.plan([it], CategoryBook.shipped, now);
    return ReminderTimelinePresenter.of(
      item: it,
      category: category ?? streaming,
      alerts: plan.alerts,
      dropped: plan.dropped,
      today: today,
    );
  }

  // The whole reason this widget replaced a one-line "next reminder". Snoozing
  // adds an alert; it does not move the ladder, and a user who cannot see the
  // rungs still standing has no way to learn that.
  test('a snooze is added beside the lead rungs, not instead of them', () {
    final before = item(expiresOn: '2026-08-28');
    final after = ItemActions.snoozed(before, d('2026-08-29'));

    final plain = build(before);
    final snoozed = build(after);

    expect(
      plain.stops
          .where((s) => s.kind == TimelineKind.lead)
          .map((s) => s.date)
          .toList(),
      [d('2026-08-27')],
    );

    // The 1-day rung is still there afterwards, at the same date.
    expect(
      snoozed.stops
          .where((s) => s.kind == TimelineKind.lead)
          .map((s) => s.date)
          .toList(),
      [d('2026-08-27')],
    );
    expect(
      snoozed.stops.where((s) => s.kind == TimelineKind.snoozed).single.date,
      d('2026-08-29'),
    );
  });

  // The other half of the same story, and the part no wording on a single line
  // could ever carry: three days from now is after the money goes.
  test('a snooze past the deadline is drawn after the deadline', () {
    final it = ItemActions.snoozed(
      item(expiresOn: '2026-08-28'),
      d('2026-08-29'),
    );

    final kinds = build(it).stops.map((s) => s.kind).toList();

    expect(kinds, [
      TimelineKind.lead, // 27/08
      TimelineKind.deadline, // 28/08
      TimelineKind.snoozed, // 29/08
    ]);
  });

  test('the deadline marker follows an alert that fires on its own day', () {
    final it = item(expiresOn: '2026-08-28', leadDays: [0]);

    final stops = build(it).stops;

    expect(stops.map((s) => s.date).toList(), [
      d('2026-08-28'),
      d('2026-08-28'),
    ]);
    expect(stops.first.kind, TimelineKind.lead);
    expect(stops.last.kind, TimelineKind.deadline);
  });

  // A daily nag enumerates one alert per day to the 60-day horizon. Drawn
  // literally it would bury every row worth reading.
  test('a nag run collapses to one row that states its cadence', () {
    final it = item(
      expiresOn: '2026-08-28',
      leadDays: const [],
      nag: NagPolicy.daily,
    );

    final nags = build(it).stops.where((s) => s.kind == TimelineKind.nag);

    expect(nags.length, 1);
    expect(nags.single.date, d('2026-08-29'));
    expect(nags.single.label, 'Then every day until you mark it as paid');
  });

  test('a weekly nag says weekly', () {
    final it = item(
      expiresOn: '2026-08-28',
      leadDays: const [],
      nag: NagPolicy.weekly,
    );

    expect(
      build(it).stops.where((s) => s.kind == TimelineKind.nag).single.label,
      'Then every 7 days until you mark it as paid',
    );
  });

  test(
    'the soonest notification is marked next, and the deadline never is',
    () {
      final it = item(expiresOn: '2026-08-28', leadDays: [3, 1]);

      final stops = build(it).stops;

      expect(stops.where((s) => s.isNext).length, 1);
      expect(stops.firstWhere((s) => s.isNext).kind, TimelineKind.lead);
      expect(
        stops
            .where((s) => s.kind == TimelineKind.deadline)
            .every((s) => !s.isNext),
        isTrue,
      );
    },
  );

  // A deadline already behind us still belongs on the timeline: the nags that
  // follow it make no sense without it.
  test('an overdue deadline stays on the timeline, marked past', () {
    final it = item(
      expiresOn: '2026-08-20',
      leadDays: const [],
      nag: NagPolicy.daily,
    );

    final stops = build(it).stops;
    final marker = stops.firstWhere((s) => s.kind == TimelineKind.deadline);

    expect(marker.date, d('2026-08-20'));
    expect(marker.isPast, isTrue);
    expect(stops.last.kind, TimelineKind.nag);
  });

  test('an act-by date earlier than expiry gets its own marker', () {
    final it = item(
      expiresOn: '2026-09-10',
      actByOffsetDays: 5,
      leadDays: const [],
    );

    final markers = build(it).stops
        .where((s) => s.kind == TimelineKind.deadline);

    expect(markers.map((s) => s.date).toList(), [
      d('2026-09-05'),
      d('2026-09-10'),
    ]);
    expect(markers.first.label, 'Act by this day');
  });

  test('the marker is worded by the shelf, not by the item', () {
    final expiring = CategoryBook.shipped['PHONE'];
    final it = item(
      expiresOn: '2026-09-10',
      category: expiring,
      leadDays: const [],
      nag: NagPolicy.none,
    );

    expect(
      build(
        it,
        category: expiring,
      ).stops.firstWhere((s) => s.kind == TimelineKind.deadline).label,
      'Expires',
    );
    expect(
      build(item(expiresOn: '2026-09-10', leadDays: const [])).stops
          .firstWhere((s) => s.kind == TimelineKind.deadline)
          .label,
      'Payment due',
    );
  });

  test('a verify prompt appears as its own stop', () {
    final it = item(
      expiresOn: '2026-09-30',
      leadDays: const [],
      verifyEveryDays: 10,
    );

    expect(
      build(it).stops.where((s) => s.kind == TimelineKind.verify).single.label,
      'Check the date is still right',
    );
  });

  group('nothing scheduled', () {
    // The deadline row survives even with every reminder gone. It is the one
    // fact on this block the user is still held to.
    test('an item with reminders switched off keeps its deadline row', () {
      final timeline = build(
        item(expiresOn: '2026-09-30', paused: true, leadDays: const []),
      );

      expect(timeline.stops.single.kind, TimelineKind.deadline);
      expect(timeline.silence, contains('Reminders are off'));
      expect(timeline.note, contains('Reminders are off'));
    });

    test('a closed item says so', () {
      final timeline = build(
        item(
          expiresOn: '2026-09-30',
          state: ItemState.inactive,
          leadDays: const [],
        ),
      );

      expect(timeline.silence, contains('closed'));
    });

    test('a live item whose ladder has run out says that instead', () {
      final timeline = build(
        item(expiresOn: '2026-08-27', leadDays: const [30]),
      );

      expect(timeline.silence, contains('already passed'));
    });

    test('nothing is said while any reminder is still coming', () {
      expect(build(item(expiresOn: '2026-08-28')).silence, isNull);
    });
  });

  // Which day sends a notification and which day takes money. Without the
  // amount every row here is a date and a sentence, and the user is left
  // telling a deadline from a reminder by the shape of a 4px ring.
  group('which day costs what', () {
    test('the due row carries the amount that moves', () {
      final it = item(
        expiresOn: '2026-08-28',
        leadDays: const [],
        amountMinor: 231000,
      );

      expect(
        build(it).stops.single.detail,
        '${MoneyFormat.full(it.money!)} charged',
      );
    });

    // Nobody debits a prepaid SIM on the day it dies. The price is what
    // renewing costs, so the number is stated and the verb is not.
    test('an expiring shelf states the price without claiming a charge', () {
      final expiring = CategoryBook.shipped['PHONE'];
      final it = item(
        expiresOn: '2026-08-28',
        category: expiring,
        leadDays: const [],
        nag: NagPolicy.none,
        amountMinor: 9900000,
      );

      final marker = build(
        it,
        category: expiring,
      ).stops.firstWhere((s) => s.kind == TimelineKind.deadline);

      expect(marker.detail, MoneyFormat.full(it.money!));
    });

    test('an item with no price says nothing rather than a dash', () {
      expect(
        build(item(expiresOn: '2026-08-28', leadDays: const []))
            .stops
            .single
            .detail,
        isNull,
      );
    });

    // Overdue is exactly when the amount matters most, so it stays. The verb
    // goes: the app has no idea whether the charge went through.
    test('a passed deadline keeps its amount and drops the verb', () {
      final it = item(
        expiresOn: '2026-08-20',
        leadDays: const [],
        amountMinor: 231000,
      );

      final marker = build(it).stops
          .firstWhere((s) => s.kind == TimelineKind.deadline);

      expect(marker.detail, '${MoneyFormat.full(it.money!)} · already passed');
    });
  });

  // The trial card used to sit above this block saying the charge date, the
  // amount and the reminder over again in a second voice. Those are rows here
  // now; what moved across is the one thing they cannot say.
  group('a free trial', () {
    TrackedItem trialItem() => item(
      expiresOn: '2026-09-23',
      leadDays: const [3],
      amountMinor: 231000,
      inTrial: true,
    );

    test('today is the first row, and it counts the free days left', () {
      final stops = build(trialItem()).stops;

      expect(stops.first.kind, TimelineKind.trial);
      expect(stops.first.date, today);
      expect(stops.first.label, 'Free for 28 more days');
      expect(stops.first.detail, 'nothing charged yet');
    });

    test('the day the trial ends is named as the first payment', () {
      final marker = build(trialItem()).stops
          .firstWhere((s) => s.kind == TimelineKind.deadline);

      expect(marker.date, d('2026-09-23'));
      expect(marker.label, 'First payment');
      expect(marker.detail, '231,000 ₫ charged');
    });

    // `isTrialOn` is `today < expiresOn`, so the trial is already off on the
    // morning of the charge: the money goes that day whether or not the user
    // opens the app. The row is gone by then and the deadline is worded plainly.
    test('the charge day itself has no trial row', () {
      final it = item(
        expiresOn: '2026-08-26',
        leadDays: const [],
        amountMinor: 231000,
        inTrial: true,
      );

      final stops = build(it).stops;

      expect(stops.where((s) => s.kind == TimelineKind.trial), isEmpty);
      expect(stops.single.label, 'Payment due');
    });

    test('one day left is not pluralised', () {
      final it = item(
        expiresOn: '2026-08-27',
        leadDays: const [],
        amountMinor: 231000,
        inTrial: true,
      );

      expect(build(it).stops.first.label, 'Free for 1 more day');
    });

    // The accent dot means "the next thing the app will send". The trial row
    // is a state, not a send, and taking the mark would leave the reminder it
    // belongs to unmarked.
    test('the trial row is never the next notification', () {
      final stops = build(trialItem()).stops;

      expect(stops.first.isNext, isFalse);
      expect(stops.firstWhere((s) => s.isNext).kind, TimelineKind.lead);
    });

    test('no trial row on an item that is not in one', () {
      expect(
        build(item(expiresOn: '2026-09-23', amountMinor: 231000)).stops
            .where((s) => s.kind == TimelineKind.trial),
        isEmpty,
      );
    });

    // The flag stays on after the first charge -- it records that the months
    // before it were free -- but the row is about today. See trap 14.
    test('no trial row once the first charge is behind us', () {
      final charged = item(
        expiresOn: '2026-08-20',
        leadDays: const [],
        amountMinor: 231000,
        inTrial: true,
      );

      expect(
        build(charged).stops.where((s) => s.kind == TimelineKind.trial),
        isEmpty,
      );
      expect(
        build(charged).stops
            .firstWhere((s) => s.kind == TimelineKind.deadline)
            .label,
        'Payment due',
      );
    });
  });

  group('dates', () {
    test('this year is day and month only', () {
      expect(
        ReminderTimelinePresenter.dateLabel(d('2026-08-27'), today),
        '27/08',
      );
    });

    // A passport can be five years out, and `27/08` on such a row reads as
    // this coming Thursday.
    test('another year carries the year', () {
      expect(
        ReminderTimelinePresenter.dateLabel(d('2031-08-27'), today),
        '27/08/2031',
      );
    });
  });
}
