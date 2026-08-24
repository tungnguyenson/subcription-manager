import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/ui/reminders_presenter.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item({
    String expiresOn = '2026-08-17',
    int actByOffsetDays = 0,
    List<int> leadDays = const [14, 7, 3, 1, 0],
  }) => TrackedItem(
    id: 'claude',
    name: 'Claude Pro',
    category: Category.subscription,
    expiresOn: d(expiresOn),
    actByOffsetDays: actByOffsetDays,
    anchorDate: d(expiresOn),
    leadDays: leadDays,
  );

  test('the ladder runs from the longest lead to the day itself', () {
    final ladder = RemindersPresenter.ladder(item(), today);
    expect(ladder.map((r) => r.leadDays), [14, 7, 3, 1, 0]);
    expect(ladder.first.fireOn, d('2026-08-03'));
    expect(ladder.last.fireOn, d('2026-08-17'));
  });

  test('rungs already behind today are marked as sent', () {
    final ladder = RemindersPresenter.ladder(item(), today);
    final past = ladder.where((r) => r.status == ReminderStatus.past);
    expect(past.map((r) => r.leadDays), [14, 7, 3]);
  });

  // The soonest rung still ahead is the one the user actually cares about, so
  // it is the only one highlighted.
  test('exactly one rung is the next one', () {
    final ladder = RemindersPresenter.ladder(item(), today);
    final next = ladder.where((r) => r.status == ReminderStatus.next).toList();
    expect(next.length, 1);
    expect(next.single.leadDays, 1);
    expect(next.single.fireOn, d('2026-08-16'));
  });

  // A ladder with a rung missing looks like a bug. "You added this too late
  // for a 30-day warning" is a fact the user should be told.
  test('a rung that never had a chance to fire is shown, not hidden', () {
    final ladder = RemindersPresenter.ladder(
      item(leadDays: [30, 7, 1]),
      today,
      createdOn: d('2026-08-10'),
    );

    expect(ladder.length, 3);
    expect(ladder.first.status, ReminderStatus.missed);
    expect(
      RemindersPresenter.detail(ladder.first, const LocalTime(8, 30)),
      contains('already past when added'),
    );
  });

  test('the ladder anchors on act-by, not on expiry', () {
    final ladder = RemindersPresenter.ladder(
      item(expiresOn: '2026-09-14', actByOffsetDays: 7, leadDays: [0]),
      today,
    );
    expect(ladder.single.fireOn, d('2026-09-07'));
  });

  test('an empty ladder is empty rather than a placeholder rung', () {
    expect(RemindersPresenter.ladder(item(leadDays: []), today), isEmpty);
  });

  group('wording', () {
    test('each status reads differently', () {
      final ladder = RemindersPresenter.ladder(item(), today);
      const at = LocalTime(8, 30);

      final details = ladder
          .map((r) => RemindersPresenter.detail(r, at))
          .toList();
      expect(details[0], '03/08 · sent');
      expect(details[3], '16/08 at 08:30 · next');
      expect(details[4], '17/08 at 08:30');
    });

    // "3 days before" is meaningless without saying before what.
    test('the anchor line says what the ladder counts from', () {
      expect(
        RemindersPresenter.anchorLine(item()),
        'counted back from 17/08, the expiry date',
      );
      expect(
        RemindersPresenter.anchorLine(item(actByOffsetDays: 7)),
        contains('the act-by date, 7 days before it expires'),
      );
    });

    // The platform evicts pending notifications past its cap silently, so this
    // is a real shared resource and the screen says so out loud.
    test('the budget line names the cost to other items', () {
      expect(
        RemindersPresenter.budgetLine(4, 0),
        'Holds 4 of the ${NotificationPlanner.budget} reminder slots '
        'this app schedules.',
      );
      expect(
        RemindersPresenter.budgetLine(4, 2),
        contains('2 reminders on other items had to be dropped'),
      );
    });

    // The same string is shown on iOS and on Android. Naming one of them makes
    // it a lie on the other, which is the kind of small false note this app
    // cannot afford on the screen that says what will be delivered.
    test('the budget line names no platform', () {
      final line = RemindersPresenter.budgetLine(4, 2);
      expect(line, isNot(contains('iOS')));
      expect(line, isNot(contains('Android')));
    });
  });
}
