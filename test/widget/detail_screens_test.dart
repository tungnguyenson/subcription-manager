import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/catalog/bundled_data.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/extract/extraction_review.dart';
import 'package:subdock/extract/extraction_schema.dart';
import 'package:subdock/ui/screens/add/plan_grid.dart';
import 'package:subdock/ui/screens/add_item_screen.dart';
import 'package:subdock/ui/screens/history_screen.dart';
import 'package:subdock/ui/screens/item_detail_screen.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/domain/currency_picks.dart';
import 'package:subdock/ui/screens/onboarding/onboarding_screen.dart';
import 'package:subdock/ui/screens/reminder_rules_screen.dart';
import 'package:subdock/ui/screens/reminders_screen.dart';
import 'package:subdock/ui/screens/review_extraction_screen.dart';
import 'package:subdock/ui/manage_presenter.dart';
import 'package:subdock/ui/reminder_timeline.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/source_mark.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  // A tall surface so the whole scrolling screen is built. A default 800px
  // viewport leaves the delete row and the paid history below the fold, and
  // a finder cannot see a ListView child that was never constructed.
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1170, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSubdockTheme(),
        home: Scaffold(backgroundColor: SubdockColors.canvas, body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  final claude = TrackedItem(
    id: 'claude',
    name: 'Claude Pro',
    categoryId: 'STREAMING',
    expiresOn: d('2026-08-17'),
    actByOffsetDays: 1,
    anchorDate: d('2026-08-17'),
    cycle: Cycle.monthly,
    amountMinor: 2000,
    currency: 'USD',
    actionUrl: 'https://claude.ai/settings/billing',
    note: 'Card ending 4417.',
    leadDays: const [14, 7, 3, 1, 0],
  );

  /// A course paid in six monthly instalments, currently on the fourth.
  final course = TrackedItem(
    id: 'course',
    name: 'Course instalment',
    categoryId: 'UTILITIES',
    expiresOn: d('2026-08-21'),
    anchorDate: d('2026-05-21'),
    cycle: Cycle.monthly,
    repeatCount: 6,
    amountMinor: 1200000,
    currency: 'VND',
  );

  group('Item detail', () {
    testWidgets('leads with how soon, exactly when, and how much', (
      tester,
    ) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
          scheduledCount: 4,
        ),
      );

      expect(find.text('Claude Pro'), findsOneWidget);
      expect(find.text(r'Due in 2 days · 17/08 · $20.00'), findsOneWidget);
    });

    // The editor returns here, so a mark this screen redetected from the name
    // would read as an icon change that never saved.
    testWidgets('draws the mark the user picked, not the detected one', (
      tester,
    ) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude.copyWith(iconName: () => 'spotify'),
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
        ),
      );

      final tile = tester.widget<ServiceTile>(find.byType(ServiceTile).first);
      expect(tile.iconName, 'spotify');
    });

    // The row is prose, so it wraps under its label instead of taking the
    // right-aligned single line every other row on this card takes. On that
    // shape a written sentence comes out as four words and an ellipsis.
    testWidgets('shows the note in full', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude.copyWith(
            note: () =>
                'Card ending 4417. Ask about the education discount before '
                'the next renewal.',
          ),
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
        ),
      );

      expect(
        find.text(
          'Card ending 4417. Ask about the education discount before the next '
          'renewal.',
        ),
        findsOneWidget,
      );
    });

    // The row used to print an em dash on every item in the app, because
    // until the form grew a note box nothing could put anything there.
    testWidgets('says nothing at all when there is no note', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude.copyWith(note: () => null),
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
        ),
      );

      expect(find.text('Note'), findsNothing);
    });

    // The app only knows what the user typed. This row is what stops a
    // remembered date from looking like a confirmed one.
    testWidgets('shows where the date came from', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
        ),
      );
      expect(find.text('from memory'), findsOneWidget);
    });

    // The block that replaced a one-line "Next reminder 18/08 at 08:30". The
    // line could name only the soonest alert, so pressing "Remind me again in
    // 3 days" -- which adds an alert and moves nothing -- looked exactly like
    // a reschedule. See trap 29 in CLAUDE.md.
    group('what happens next', () {
      ReminderTimeline timelineFor(TrackedItem item) {
        final plan = NotificationPlanner.plan(
          [item],
          CategoryBook.shipped,
          LocalDateTime(today, const LocalTime(0, 0)),
        );
        return ReminderTimelinePresenter.of(
          item: item,
          category: CategoryBook.shipped[item.categoryId],
          alerts: plan.alerts,
          dropped: plan.dropped,
          today: today,
        );
      }

      testWidgets('a snoozed item still shows the rung it did not move', (
        tester,
      ) async {
        // Act-by is 16/08, so the 1-day rung lands on 15/08 -- today, before
        // the 08:30 send time. Snoozing puts one more alert on 18/08.
        final snoozed = claude.copyWith(snoozedUntil: () => d('2026-08-18'));

        await show(
          tester,
          ItemDetailScreen(
            item: snoozed,
            category: CategoryBook.shipped[snoozed.categoryId],
            today: today,
            timeline: timelineFor(snoozed),
          ),
        );

        expect(find.text('1 day before'), findsOneWidget);
        expect(find.text('You asked to be reminded'), findsOneWidget);
        expect(find.text('18/08'), findsOneWidget);
      });

      // The reason the deadline shares the column with the reminders rather
      // than sitting in a header above them.
      testWidgets('the deadline is a row like any other', (tester) async {
        await show(
          tester,
          ItemDetailScreen(
            item: claude,
            category: CategoryBook.shipped[claude.categoryId],
            today: today,
            timeline: timelineFor(claude),
          ),
        );

        expect(find.text('Act by this day'), findsOneWidget);
        expect(find.text('Payment due'), findsOneWidget);
      });

      // A screen with no plan behind it -- every other test in this file --
      // must not sprout an empty section header.
      testWidgets('no block at all without a timeline', (tester) async {
        await show(
          tester,
          ItemDetailScreen(
            item: claude,
            category: CategoryBook.shipped[claude.categoryId],
            today: today,
          ),
        );

        expect(find.text('WHAT HAPPENS NEXT'), findsNothing);
        expect(find.text('Edit reminders'), findsOneWidget);
      });

      // Which row sends a notification and which one takes money. The block
      // is a column of dates and sentences otherwise, and the only thing
      // separating a reminder from a charge was the shape of a 4px ring.
      testWidgets('a reminder names itself, and the due day names the sum', (
        tester,
      ) async {
        await show(
          tester,
          ItemDetailScreen(
            item: claude,
            category: CategoryBook.shipped[claude.categoryId],
            today: today,
            timeline: timelineFor(claude),
          ),
        );

        expect(find.textContaining('Reminder at 08:30'), findsWidgets);
        expect(find.text(r'$20.00 charged'), findsOneWidget);
      });

      // The trial used to be an accented card above this block, repeating the
      // charge date, the amount and the reminder that are rows here already.
      // Only the part a column of future dates cannot carry moved across.
      testWidgets('a trial is a row of this block, not a card above it', (
        tester,
      ) async {
        final trial = claude.copyWith(inTrial: true);

        await show(
          tester,
          ItemDetailScreen(
            item: trial,
            category: CategoryBook.shipped[trial.categoryId],
            today: today,
            timeline: timelineFor(trial),
          ),
        );

        expect(find.text('Free for 2 more days'), findsOneWidget);
        expect(find.text('nothing charged yet'), findsOneWidget);
        expect(find.text('First payment'), findsOneWidget);
        expect(find.text(r'$20.00 charged'), findsOneWidget);
        // The old card's own sentence, gone with it.
        expect(find.textContaining('The first charge lands'), findsNothing);
      });

      testWidgets('an item with reminders off says so under the block', (
        tester,
      ) async {
        final off = claude.copyWith(paused: true);

        await show(
          tester,
          ItemDetailScreen(
            item: off,
            category: CategoryBook.shipped[off.categoryId],
            today: today,
            timeline: timelineFor(off),
          ),
        );

        expect(
          find.textContaining('Reminders are off for this item'),
          findsOneWidget,
        );
        expect(find.text('Payment due'), findsOneWidget);
      });
    });

    // Deleting also removes pending reminders the user cannot see.
    testWidgets('the delete action states both consequences', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
          scheduledCount: 4,
        ),
      );

      expect(find.text('Delete this item'), findsOneWidget);
      expect(
        find.textContaining('Removes 4 pending reminders'),
        findsOneWidget,
      );
    });

    testWidgets('a subscription can be cancelled without being deleted', (
      tester,
    ) async {
      var stopped = false;
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
          onStop: () => stopped = true,
        ),
      );

      await tester.tap(find.text('Cancel this subscription'));
      expect(stopped, isTrue);
    });

    testWidgets('paid history lists what was actually charged', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
          history: [
            HandledEvent(
              id: 'e1',
              itemId: 'claude',
              handledAtEpochSeconds: 1,
              forDueDate: d('2026-07-17'),
              currency: 'VND',
              baseAmountMinor: 520240,
              actualChargedMinor: 545000,
            ),
          ],
        ),
      );

      expect(find.text('HISTORY'), findsOneWidget);
      expect(find.text('17/07'), findsOneWidget);
      expect(find.text('545,000 ₫'), findsOneWidget);
    });

    group('a limited series', () {
      testWidgets('says which payment is due and what is left', (tester) async {
        await show(
          tester,
          ItemDetailScreen(
            item: course,
            category: CategoryBook.shipped[course.categoryId],
            today: today,
          ),
        );

        expect(find.text('4 of 6'), findsOneWidget);
        expect(find.text('3 paid · this one due · 2 left'), findsOneWidget);
        expect(find.text('Monthly · 6 times'), findsOneWidget);
        // Six monthly payments from 21/05/2026 land the last one in October.
        expect(find.text('21/10/2026'), findsOneWidget);
        // Two payments after this one, not three: the one due now is not
        // money the user still has to find later.
        expect(find.text('2,400,000 ₫'), findsOneWidget);
      });

      testWidgets('the primary action names the payment by number', (
        tester,
      ) async {
        var paid = false;
        await show(
          tester,
          ItemDetailScreen(
            item: course,
            category: CategoryBook.shipped[course.categoryId],
            today: today,
            onMarkPaid: () => paid = true,
          ),
        );

        await tester.tap(find.text('Mark payment 4 as paid'));
        expect(paid, isTrue);
      });

      testWidgets('ending it is phrased in the plan own terms', (tester) async {
        await show(
          tester,
          ItemDetailScreen(
            item: course,
            category: CategoryBook.shipped[course.categoryId],
            today: today,
          ),
        );

        expect(find.text('Stop after this payment'), findsOneWidget);
        expect(find.text('Cancel this subscription'), findsNothing);
      });

      testWidgets('an open-ended item shows no instalment strip', (
        tester,
      ) async {
        await show(
          tester,
          ItemDetailScreen(
            item: course.copyWith(repeatCount: () => null),
            category: CategoryBook.shipped['STREAMING'],
            today: today,
          ),
        );

        expect(find.text('Payment'), findsNothing);
        expect(find.text('Mark as paid'), findsOneWidget);
      });
    });

    // Reaching the form should not mean hunting for a pencil: the row that
    // states the fact the user came to fix is the row that opens the editor.
    testWidgets('the link and the rows the form owns all reach the editor', (
      tester,
    ) async {
      var opened = 0;
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
          onEdit: () => opened++,
        ),
      );

      await tester.tap(find.text('Edit'));
      await tester.tap(find.text(r'$20.00 / mo'));
      await tester.tap(find.text('Streaming'));
      await tester.pumpAndSettle();

      expect(opened, 3);
    });

    // A dash on a row that leads somewhere reads as "nothing to see here".
    testWidgets('an item with no cost is invited to have one', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude.copyWith(amountMinor: () => null),
          category: CategoryBook.shipped['STREAMING'],
          today: today,
          onEdit: () {},
        ),
      );

      expect(find.text('Add a cost'), findsOneWidget);
    });

    testWidgets('with no editor wired there is no Edit link', (tester) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claude,
          category: CategoryBook.shipped[claude.categoryId],
          today: today,
        ),
      );

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Add a cost'), findsNothing);
    });
  });

  group('Reminders for one item', () {
    testWidgets('every rung is switchable, and the next one is named', (
      tester,
    ) async {
      await show(
        tester,
        RemindersScreen(item: claude, today: today, heldSlots: 4),
      );

      expect(find.text('14 days before'), findsOneWidget);
      expect(find.text('On the day'), findsOneWidget);
      expect(find.textContaining('· next'), findsOneWidget);
    });

    // A ladder the user can only remove from is a ladder they cannot repair.
    testWidgets('a rung the item does not use is still offered', (
      tester,
    ) async {
      await show(
        tester,
        RemindersScreen(
          item: claude.copyWith(leadDays: const [3]),
          today: today,
        ),
      );

      expect(find.text('30 days before'), findsOneWidget);
      expect(find.text('7 days before'), findsOneWidget);
    });

    testWidgets('the subtitle says what the ladder counts back from', (
      tester,
    ) async {
      await show(tester, RemindersScreen(item: claude, today: today));
      expect(find.textContaining('the act-by date'), findsOneWidget);
    });

    // iOS keeps 64 pending notifications and evicts the rest silently.
    testWidgets('the notification budget is stated on screen', (tester) async {
      await show(
        tester,
        RemindersScreen(
          item: claude,
          today: today,
          heldSlots: 4,
          droppedElsewhere: 2,
        ),
      );

      expect(
        find.textContaining('Holds 4 of the ${NotificationPlanner.budget}'),
        findsOneWidget,
      );
      expect(
        find.textContaining('2 reminders on other items had to be dropped'),
        findsOneWidget,
      );
    });
  });

  group('Reminder defaults', () {
    testWidgets('the schedule switches reflect the stored setting', (
      tester,
    ) async {
      final toggled = <(int, bool)>[];
      await show(
        tester,
        ReminderRulesScreen(
          settings: const AppSettings(defaultLeadDays: [3, 0]),
          pushGranted: true,
          onToggleLead: (lead, on) => toggled.add((lead, on)),
        ),
      );

      expect(find.text('7 days before'), findsOneWidget);
      expect(find.text('08:30'), findsOneWidget);

      await tester.tap(find.text('7 days before'));
      await tester.pumpAndSettle();
      expect(toggled, isEmpty, reason: 'the label is not the control');
    });

    // A switch that says "on" while the system permission is off is a lie the
    // user cannot see through.
    testWidgets('push reports the system permission rather than a preference', (
      tester,
    ) async {
      await show(
        tester,
        const ReminderRulesScreen(settings: AppSettings(), pushGranted: false),
      );

      expect(find.textContaining('Notifications are off'), findsOneWidget);
    });

    // The hand-off is explicit that a screen states facts and does not explain
    // itself. How the defaults propagate is documentation; that notifications
    // are off is state the user cannot see anywhere else.
    testWidgets('with notifications on it explains nothing', (tester) async {
      await show(
        tester,
        const ReminderRulesScreen(settings: AppSettings(), pushGranted: true),
      );

      expect(find.byType(Footnote), findsNothing);
    });

    // Android grants notifications and exact alarms separately. With only the
    // first, a reminder set for 08:30 still arrives -- whenever the system
    // next wakes. The screen shows a time, so it has to say when that time is
    // not being honoured.
    testWidgets('a device that will not fire on time says so', (tester) async {
      await show(
        tester,
        const ReminderRulesScreen(
          settings: AppSettings(),
          pushGranted: true,
          exactTiming: false,
        ),
      );

      expect(find.textContaining('not allowing alarms'), findsOneWidget);
    });

    testWidgets('exact timing granted adds no footnote', (tester) async {
      await show(
        tester,
        const ReminderRulesScreen(
          settings: AppSettings(),
          pushGranted: true,
          exactTiming: true,
        ),
      );

      expect(find.byType(Footnote), findsNothing);
    });

    // Every other claim on this screen is untestable by the user: a reminder
    // that never arrives looks exactly like one that is still coming.
    testWidgets('the delivery path can be tried on demand', (tester) async {
      var sent = 0;
      await show(
        tester,
        ReminderRulesScreen(
          settings: const AppSettings(),
          pushGranted: true,
          onSendTest: () => sent++,
        ),
      );

      await tester.tap(find.text('Send a test reminder'));
      await tester.pumpAndSettle();
      expect(sent, 1);
    });

    // A button that fails on purpose teaches nothing the footnote does not
    // already say.
    testWidgets('no test button while nothing can be delivered', (
      tester,
    ) async {
      await show(
        tester,
        ReminderRulesScreen(
          settings: const AppSettings(),
          pushGranted: false,
          onSendTest: () {},
        ),
      );

      expect(find.text('Send a test reminder'), findsNothing);
    });

    // Notifications off is the bigger fact and the only one shown; stacking a
    // second footnote about timing under it explains a delivery that is not
    // happening at all.
    testWidgets('timing is not mentioned while push is off', (tester) async {
      await show(
        tester,
        const ReminderRulesScreen(
          settings: AppSettings(),
          pushGranted: false,
          exactTiming: false,
        ),
      );

      expect(find.byType(Footnote), findsOneWidget);
      expect(find.textContaining('Notifications are off'), findsOneWidget);
    });
  });

  group('History', () {
    testWidgets('groups by month, newest first', (tester) async {
      await show(
        tester,
        HistoryScreen(
          currentYear: 2026,
          done: [
            HistoryEntry(
              itemName: 'Spotify Family',
              on: d('2026-08-08'),
              what: 'renewed',
              amount: '169,000 ₫',
            ),
            HistoryEntry(
              itemName: 'Adobe',
              on: d('2026-07-04'),
              what: 'cancelled',
            ),
          ],
        ),
      );

      expect(find.text('AUGUST'), findsOneWidget);
      expect(find.text('JULY'), findsOneWidget);
    });

    testWidgets('the filter narrows the list to one outcome', (tester) async {
      await show(
        tester,
        HistoryScreen(
          currentYear: 2026,
          done: [
            HistoryEntry(
              itemName: 'Spotify Family',
              on: d('2026-08-08'),
              what: 'renewed',
            ),
            HistoryEntry(
              itemName: 'Electricity bill',
              on: d('2026-07-20'),
              what: 'missed',
              missed: true,
            ),
          ],
        ),
      );

      expect(find.text('Spotify Family'), findsOneWidget);
      expect(find.text('Electricity bill'), findsOneWidget);

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();
      expect(find.text('Spotify Family'), findsNothing);
      expect(find.text('Electricity bill'), findsOneWidget);

      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();
      expect(find.text('Spotify Family'), findsOneWidget);
      expect(find.text('Electricity bill'), findsNothing);
    });

    // "The record of what did not happen" said over a list with a miss in it
    // is the screen contradicting its own rows.
    testWidgets('the lead line stops claiming a clean record once one is not', (
      tester,
    ) async {
      await show(
        tester,
        HistoryScreen(
          currentYear: 2026,
          done: [
            HistoryEntry(
              itemName: 'Spotify Family',
              on: d('2026-08-08'),
              what: 'renewed',
            ),
            HistoryEntry(
              itemName: 'Electricity bill',
              on: d('2026-07-20'),
              what: 'missed',
              missed: true,
            ),
          ],
        ),
      );

      expect(
        find.text('2 closed · 1 after the date had passed.'),
        findsOneWidget,
      );
      expect(find.textContaining('what did not happen'), findsNothing);
    });

    // An empty Missed list is the one result on this screen that is good news,
    // so it says what it means rather than "nothing here".
    testWidgets('an empty Missed list says what it means', (tester) async {
      await show(
        tester,
        HistoryScreen(
          currentYear: 2026,
          done: [
            HistoryEntry(
              itemName: 'Spotify Family',
              on: d('2026-08-08'),
              what: 'renewed',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nothing has gone past its date unhandled.'),
        findsOneWidget,
      );
    });

    // A month from another year gets its year spelled out; a bare month name
    // on a two-year-old row reads as this year's.
    testWidgets('an older year is labelled with its year', (tester) async {
      await show(
        tester,
        HistoryScreen(
          currentYear: 2026,
          done: [
            HistoryEntry(
              itemName: 'Adobe',
              on: d('2025-07-04'),
              what: 'cancelled',
            ),
          ],
        ),
      );

      expect(find.text('JULY 2025'), findsOneWidget);
    });

    testWidgets('an empty log explains what would go here', (tester) async {
      await show(tester, const HistoryScreen(currentYear: 2026));
      expect(find.textContaining('Nothing closed yet'), findsOneWidget);
    });
  });

  group('Onboarding', () {
    /// Onboarding is the one screen with animations that never stop, so it
    /// cannot be pumped to a standstill. Reduce Motion is a real code path --
    /// the marquee and the arriving notifications both honour it -- so the
    /// tests take that path and get a still frame with every element in it.
    /// A fresh [key] on every call: `pumpWidget` puts a widget of the same
    /// type in the same seat and Flutter keeps the old `State` with it, so a
    /// second call without one would arrive on whichever page the first one
    /// was left on. Same trap the add form has with its save latch.
    var shown = 0;

    Future<void> showOnboarding(
      WidgetTester tester, {
      CurrencyPicks? picks,
      String currency = 'VND',
      AppLocale locale = AppLocale.en,
      ValueChanged<CurrencyPicks>? onCurrency,
      ValueChanged<AppLocale>? onLocale,
      VoidCallback? onStart,
    }) async {
      final chosen = picks ?? CurrencyPicks.one(currency);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SubdockTheme(
          palette: SubdockPalette.light,
          locale: locale,
          currency: chosen.base,
          currencies: chosen.codes,
          child: MaterialApp(
            theme: buildSubdockTheme(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: OnboardingScreen(
                  key: ValueKey(shown++),
                  picks: chosen,
                  locale: locale,
                  onCurrency: onCurrency ?? (_) {},
                  onLocale: onLocale ?? (_) {},
                  onStart: onStart,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the first page shows the app rather than describing it', (
      tester,
    ) async {
      await showOnboarding(tester);

      expect(find.text('Never miss a due date again.'), findsOneWidget);
      expect(find.text('Everything with a date, in one list'), findsOneWidget);
      expect(find.text('Know before the money leaves'), findsOneWidget);
      expect(find.text('See what it adds up to'), findsOneWidget);

      // The marquee draws the real list rows, and the lock screen the real
      // notification. A card that only made the claim in words would be a
      // slide.
      expect(find.text('Netflix'), findsWidgets);
      expect(find.textContaining('Mobile SIM expires in 3 days'), findsOne);
    });

    testWidgets('the sample figures follow the currency in force', (
      tester,
    ) async {
      await showOnboarding(tester, currency: 'VND');
      expect(find.text('14,208,000 ₫'), findsOneWidget);

      await showOnboarding(tester, currency: 'USD');
      // Not the dong figure converted: a made-up total should look made up,
      // and 545.31 reads as a real number someone might go looking for.
      expect(find.text(r'$592.00'), findsOneWidget);
    });

    testWidgets('the currency question comes after the three cards', (
      tester,
    ) async {
      await showOnboarding(tester);

      expect(find.text('Language and currency'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Language and currency'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Get started'), findsOneWidget);
    });

    // Both answers take effect as they are tapped rather than at the end, so
    // that the rest of the screen is already in the language and the sample
    // figures already in the currency.
    testWidgets('both answers are handed back as they are tapped', (
      tester,
    ) async {
      final currencies = <CurrencyPicks>[];
      final locales = <AppLocale>[];
      var started = 0;

      await showOnboarding(
        tester,
        onCurrency: currencies.add,
        onLocale: locales.add,
        onStart: () => started++,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(locales, [AppLocale.vi]);
      // Appended, and the base left where it was. Adding a currency says "I
      // am billed in this too", not "state my totals in this".
      expect(currencies.single.codes, ['VND', 'USD']);
      expect(currencies.single.base, 'VND');
      expect(started, 1);
    });

    // The sheet has to be readable by the one person it is for: someone who
    // cannot read the language currently on screen.
    testWidgets('each language is written in its own language', (tester) async {
      await showOnboarding(tester, locale: AppLocale.vi);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Việt'), findsWidgets);
      expect(find.text('English'), findsOneWidget);
    });

    // The app carries one exchange rate. Picking a third currency is allowed
    // and everything still adds up per currency, but the single combined
    // figure goes away -- and the screen has to say so before the tap, not
    // leave it to be discovered on the Money screen.
    testWidgets('a currency with no bundled rate says what it costs', (
      tester,
    ) async {
      await showOnboarding(tester, currency: 'VND');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no single combined total'), findsNothing);

      await showOnboarding(tester, currency: 'EUR');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no single combined total'), findsOneWidget);
    });

    // Two currencies the app cannot relate is a working list with no combined
    // figure on the Money screen, and the warning is keyed off the declared
    // set rather than off the base alone -- the base here is perfectly
    // convertible on its own.
    testWidgets('a second currency with no rate to the base says so too', (
      tester,
    ) async {
      await showOnboarding(tester, picks: CurrencyPicks.one('VND'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no single combined total'), findsNothing);

      await showOnboarding(
        tester,
        picks: CurrencyPicks(['VND', 'EUR'], base: 'VND'),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no single combined total'), findsOneWidget);
    });

    // A card is a bill in that currency rather than the currency's name and
    // symbol. The question is not which glyph the user likes, it is what
    // their bills look like.
    testWidgets('each declared currency is drawn as a bill in it', (
      tester,
    ) async {
      await showOnboarding(
        tester,
        picks: CurrencyPicks(['VND', 'USD'], base: 'VND'),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('231,000 ₫'), findsOneWidget);
      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text(r'$12.99'), findsOneWidget);
    });

    // The table only covers the currencies people are commonly billed in.
    // A currency outside it is not a gap in the screen: the card falls back
    // to the currency's own mark and name, which is what the picker showed
    // for every currency before the table existed.
    testWidgets('a currency with no sample bill still fills its card', (
      tester,
    ) async {
      await showOnboarding(tester, currency: 'CHF');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Swiss franc'), findsOneWidget);
    });

    // The chips only mean anything once there are two currencies to choose
    // between, and the row of them is what the second card buys.
    testWidgets('which currency the totals speak is asked only once it is a '
        'question', (tester) async {
      await showOnboarding(tester, picks: CurrencyPicks.one('VND'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('DEFAULT CURRENCY'), findsNothing);

      final picks = <CurrencyPicks>[];
      await showOnboarding(
        tester,
        picks: CurrencyPicks(['VND', 'USD'], base: 'VND'),
        onCurrency: picks.add,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('DEFAULT CURRENCY'), findsOneWidget);

      await tester.tap(find.text(r'$ USD'));
      await tester.pumpAndSettle();
      expect(picks.single.base, 'USD');
      // Only the base moved. The other currency is a separate answer.
      expect(picks.single.codes, ['VND', 'USD']);
    });

    // Adding is offered only while there is room, and the design caps it at
    // two. Without the cap the chip row on the amount field grows without
    // limit on a form used every day.
    testWidgets('a full list stops offering to add another', (tester) async {
      await showOnboarding(
        tester,
        picks: CurrencyPicks(['VND', 'USD'], base: 'VND'),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Add a currency'), findsNothing);
    });
  });

  group('Add item', () {
    /// Puts the form on screen past step one.
    ///
    /// Adding a new item now opens on the service picker, so a test about the
    /// *form* has to say which way it got there. "Enter manually" is the path
    /// for a service the catalogue does not have, which is the case most of
    /// these tests are describing; the ones that are about the catalogue tap a
    /// row in the picker instead and land on the same form.
    Future<void> showForm(WidgetTester tester, Widget screen) async {
      await show(tester, screen);
      final manual = find.text('Enter manually');
      if (manual.evaluate().isNotEmpty) {
        await tester.ensureVisible(manual);
        await tester.pumpAndSettle();
        await tester.tap(manual);
        await tester.pumpAndSettle();
      }
    }

    /// The note box, picked out by its hint: the form holds half a dozen
    /// `TextField`s and index order across them is not something to lean on.
    final noteBox = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Anything you want to remember',
    );

    /// Every field on the form except that one.
    ///
    /// The note sits at the foot of the form, so `find.byType(TextField).last`
    /// -- how the tests below reach the small number box and the new-source
    /// name -- started landing on it the day the box was added.
    final otherBoxes = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText != 'Anything you want to remember',
    );

    final catalog = ServiceCatalog([
      const CatalogEntry(
        id: 'netflix',
        name: 'Netflix Premium',
        aliases: ['netflix'],
        categoryId: 'STREAMING',
        defaultCycle: Cycle.monthly,
        typicalAmountMinor: 260000,
        currency: 'VND',
        manageUrl: 'https://netflix.com/account',
      ),
      // No manage URL, which is the commoner case: most catalogue rows carry
      // no account page at all.
      const CatalogEntry(
        id: 'vinaphone',
        name: 'VinaPhone plan',
        aliases: ['vinaphone'],
        categoryId: 'PHONE',
        defaultCycle: Cycle.monthly,
      ),
    ]);

    // The one thing the trial switch has to do: be enough on its own. It asks
    // for no dates -- the day the free period ends is the day the charge lands,
    // which is the form's own date field -- so a tap on it and a date is a
    // complete item.
    testWidgets('the trial switch is enough on its own to save', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('In a free trial now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In a free trial now'));
      await tester.pumpAndSettle();

      // The date field does not go away when the trial comes on: for a trial
      // that date *is* the first charge, and the summary at the foot of the
      // form goes on reading it back.
      expect(find.textContaining('Free until Saturday'), findsOneWidget);

      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.inTrial, isTrue);
      expect(saved!.expiresOn, today);
    });

    // The box the note column waited on. Everything below it -- the SQLite
    // column, the backup codec, the CSV cell, the detail row -- has been there
    // all along; the form was the only thing missing, so the row on the detail
    // screen read an em dash on every item in the app.
    testWidgets('a typed note reaches the draft', (tester) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(noteBox);
      await tester.pumpAndSettle();
      await tester.enterText(noteBox, 'Shared with Minh, he pays half.');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.note, 'Shared with Minh, he pays half.');
    });

    // A box holding spaces is a box somebody cleared. It has to come back as
    // null, because null is what the detail screen reads to decide whether the
    // row is drawn at all -- whitespace would draw an empty one.
    testWidgets('an emptied note saves as nothing, not as blanks', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(claude, CategoryBook.shipped),
          onSave: (draft) => saved = draft,
        ),
      );

      // The edit form opens holding what the item already says.
      expect(find.text('Card ending 4417.'), findsOneWidget);

      await tester.ensureVisible(noteBox);
      await tester.pumpAndSettle();
      await tester.enterText(noteBox, '   ');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.note, isNull);
    });

    // The caller writes to SQLite before it pops this route, so the form and
    // its enabled button stay on screen for the length of that write. A second
    // tap in that window used to write a second row with a second id: two
    // identical items, and the caller popped twice, which took the notification
    // sheet the first save had just opened down with it -- so the app never
    // asked for the permission its whole job depends on, and then went quiet
    // for two more saves because the dismissed sheet read as a decline.
    testWidgets('a second tap on Save does not save a second item', (
      tester,
    ) async {
      var saves = 0;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (_) => saves++,
        ),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();

      // Twice without settling between: the real second tap lands while the
      // write from the first is still in flight and nothing has popped yet.
      await tester.tap(find.text('Save item'));
      await tester.pump();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saves, 1);
    });

    // The form is a pushed route, built once with whatever source list the app
    // held at the time. Nothing rebuilds it when the database gains a row, so a
    // source created from inside the form has to appear from the field's own
    // state -- otherwise the write goes through, the card closes, and
    // `Add source` reads as a button that does nothing.
    testWidgets('a source created here becomes a chip here', (tester) async {
      DraftItem? saved;
      var created = 0;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
          // The caller writes it and hands back an id. It does *not* hand back
          // a new list, which is the whole point of this test.
          onCreateSource: (name, glyph) async => 'src${++created}',
        ),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      await tester.enterText(otherBoxes.last, 'VCB 4412');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add source'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add source'));
      await tester.pumpAndSettle();

      expect(created, 1);
      // The chip is on screen, and it is the one now selected.
      expect(find.text('VCB 4412'), findsOneWidget);

      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.paymentSourceId, 'src1');
    });

    // The preset chips scroll under the keyboard once the field has focus, so
    // the glyph in front of the name is the only thing left saying which kind
    // of money is armed -- and it is the glyph the saved chip will carry.
    testWidgets('the name field wears the glyph of the preset picked', (
      tester,
    ) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (_) {},
          onCreateSource: (name, glyph) async => 'src1',
        ),
      );

      await tester.ensureVisible(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      // The field opens on the default before any preset is touched.
      expect(
        tester.widget<SourceMark>(find.byType(SourceMark)).glyph,
        SourceGlyph.card,
      );

      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SourceMark>(find.byType(SourceMark)).glyph,
        SourceGlyph.cash,
      );
    });

    // A preset fills the field for the user, so the most likely next thing
    // they want is that word gone -- one tap rather than one backspace per
    // character of a name they never typed.
    testWidgets('the clear button empties the name field', (tester) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (_) {},
          onCreateSource: (name, glyph) async => 'src1',
        ),
      );

      await tester.ensureVisible(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      // Nothing to clear yet, so nothing offers to.
      expect(find.bySemanticsLabel('Clear name'), findsNothing);

      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Wallet'), findsNWidgets(2)); // the chip and the field

      await tester.tap(find.bySemanticsLabel('Clear name'));
      await tester.pumpAndSettle();

      // Only the chip is left, and `Add source` went back to being dead.
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.bySemanticsLabel('Clear name'), findsNothing);
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Add source'),
            )
            .onPressed,
        isNull,
      );
    });

    // What someone typed into the picker's search box is an answer, not a
    // failed query. The catalogue holding 223 rows out of a world that has
    // more means a miss says nothing about the name -- so the name has to
    // survive the trip to step two, by either exit out of the picker.
    group('a name the catalogue does not have', () {
      testWidgets('the submit key carries the typed name into the form', (
        tester,
      ) async {
        DraftItem? saved;
        await show(
          tester,
          AddItemScreen(
            catalog: catalog,
            categories: CategoryBook.shipped,
            today: today,
            onSave: (draft) => saved = draft,
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'Gym Hoang Cau');
        await tester.pumpAndSettle();
        expect(find.textContaining('Nothing matches'), findsOneWidget);

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // Step two, with the name already written.
        expect(find.text('Save item'), findsOneWidget);
        expect(find.text('Gym Hoang Cau'), findsWidgets);

        await tester.ensureVisible(find.text('+30'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+30'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save item'));
        await tester.pumpAndSettle();
        expect(saved?.name, 'Gym Hoang Cau');
      });

      testWidgets('so does the manual button', (tester) async {
        await show(
          tester,
          AddItemScreen(
            catalog: catalog,
            categories: CategoryBook.shipped,
            today: today,
          ),
        );

        await tester.enterText(find.byType(TextField).first, 'Bao Tuoi Tre');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Enter manually'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter manually'));
        await tester.pumpAndSettle();

        expect(find.text('Bao Tuoi Tre'), findsWidgets);
      });

      // The submit key on an empty box is a stray tap on the keyboard, not a
      // request to name an item nothing. Leaving the picker there would take
      // the browser away from someone who had not asked for that.
      testWidgets('an empty box stays on the picker', (tester) async {
        await show(
          tester,
          AddItemScreen(
            catalog: catalog,
            categories: CategoryBook.shipped,
            today: today,
          ),
        );

        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(find.text('Step 1 of 2 · pick a service'), findsOneWidget);
      });
    });

    // The date is the only thing that gates the button. A missing name is not
    // a reason to refuse a save -- it becomes `Untitled item`, which the user
    // fixes in one tap, where refusing would lose the date they just set.
    //
    // Two forms rather than three taps on one: the Save button latches after
    // the first tap that goes through, so a form only ever saves once. A tap
    // while the date is still missing does not latch it -- the button is
    // disabled then, and a disabled button has nothing to spend.
    testWidgets('save waits for a date, not for a name', (tester) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(saved, isNull, reason: 'no date yet');

      // The date chips are one row that runs off the edge of the phone, so
      // the last of them has to be scrolled to before it can be tapped.
      await tester.ensureVisible(find.text('+30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+30'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Untitled item');
      expect(saved?.expiresOn, d('2026-09-14'));

      saved = null;
      // A key, because `pumpWidget` over a screen of the same type at the same
      // spot keeps the old State -- and the old State is the one that has
      // already spent its save.
      await showForm(
        tester,
        AddItemScreen(
          key: const ValueKey('second form'),
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.ensureVisible(find.text('+30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+30'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Spotify');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Spotify');
    });

    // The catalogue's plan grid. Its whole claim is "this is the listed price
    // of that tier", so the lit tile and the number in the cost field have to
    // agree — and `_pickPlan` writes into the very field whose listener clears
    // the selection, which is a latch that is easy to break and invisible in
    // an analyzer run.
    testWidgets('picking a plan lights the tile and fills the cost', (
      tester,
    ) async {
      final priced = ServiceCatalog([
        CatalogEntry(
          id: 'netflix',
          name: 'Netflix Premium',
          aliases: const ['netflix'],
          categoryId: 'STREAMING',
          defaultCycle: Cycle.monthly,
          defaultPlan: 'premium',
          plans: const [
            CatalogPlan(
              tier: 'standard',
              name: 'Standard',
              region: 'VN',
              currency: 'VND',
              cycle: Cycle.monthly,
              amountMinor: 220000,
              source: 'https://netflix.com/vn/plans',
              checkedAt: '2026-07-30',
            ),
            CatalogPlan(
              tier: 'premium',
              name: 'Premium',
              region: 'VN',
              currency: 'VND',
              cycle: Cycle.monthly,
              amountMinor: 260000,
              source: 'https://netflix.com/vn/plans',
              checkedAt: '2026-07-30',
            ),
          ],
        ),
      ]);

      await show(
        tester,
        AddItemScreen(
          catalog: priced,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.tap(find.text('Netflix Premium'));
      await tester.pumpAndSettle();

      // The vendor's own default tier arrives already lit.
      expect(
        tester.widget<PlanGrid>(find.byType(PlanGrid)).selected,
        'premium·month1',
      );

      // The cost field is folded away behind the grid until the user says
      // their price differs, so the amount is only readable once it is open.
      expect(find.text('260,000'), findsNothing);
      await tester.tap(find.text('Other amount'));
      await tester.pumpAndSettle();
      expect(find.text('260,000'), findsOneWidget);

      // The tile is labelled with the plan's name, not its slug.
      expect(find.text('standard'), findsNothing);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PlanGrid>(find.byType(PlanGrid)).selected,
        'standard·month1',
        reason: 'the tap must survive its own write to the cost field',
      );
      expect(find.text('220,000'), findsOneWidget);
    });

    // The grid shows what the vendor sells, not what the tray happens to be
    // set to -- and the yearly figure is the one worth seeing before
    // committing. Which means a tile can disagree with the tray, and the tile
    // wins: a yearly price saved against a monthly cycle is twelve times the
    // money, with nothing on screen contradicting it.
    testWidgets('a yearly tile sets the yearly cycle', (tester) async {
      final priced = ServiceCatalog([
        CatalogEntry(
          id: 'adobe',
          name: 'Adobe Photography',
          aliases: const ['adobe'],
          categoryId: 'STREAMING',
          defaultCycle: Cycle.monthly,
          defaultPlan: 'plan',
          plans: const [
            CatalogPlan(
              tier: 'plan',
              name: 'Photography',
              region: 'VN',
              currency: 'VND',
              cycle: Cycle.monthly,
              amountMinor: 250000,
              source: 'https://adobe.com/vn/plans',
              checkedAt: '2026-07-30',
            ),
            CatalogPlan(
              // The same slug as the monthly one, the way Disney+ ships it:
              // one plan sold two ways.
              tier: 'plan',
              name: 'Photography, a year',
              region: 'VN',
              currency: 'VND',
              cycle: Cycle.yearly,
              amountMinor: 2500000,
              source: 'https://adobe.com/vn/plans',
              checkedAt: '2026-07-30',
            ),
          ],
        ),
      ]);

      DraftItem? saved;
      await show(
        tester,
        AddItemScreen(
          catalog: priced,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Adobe Photography'));
      await tester.pumpAndSettle();

      // Both cycles on the grid at once, told apart by the unit under the
      // price rather than by a control the user has not touched yet.
      expect(find.textContaining('/ mo'), findsOneWidget);
      expect(find.textContaining('/ yr'), findsOneWidget);

      // One slug, two prices: a tile lit by its slug alone would light both,
      // which reads as the user having chosen two amounts at once.
      await tester.tap(find.text('Photography, a year'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlanGrid>(find.byType(PlanGrid)).selected,
        'plan·month12',
      );

      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.cycle, Cycle.yearly);
      expect(saved?.amountMinor, 2500000);
    });

    // Nobody picked a shelf, so the row says so -- and the save still lands on
    // one, because there is nowhere else for an item to go.
    testWidgets('an untouched category still saves onto the fallback shelf', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      expect(find.text('Pick a category'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Gym');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.category.id, CategoryBook.shipped.fallback.id);
    });

    // The heading is the only thing on the add form whose job is to say what
    // is being added, so it follows the name as it is typed.
    testWidgets('the heading follows the name being typed', (tester) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      expect(find.text('New item'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Gym');
      await tester.pumpAndSettle();

      // Once in the heading, once in the field it was typed into.
      expect(find.text('Gym'), findsNWidgets(2));
      expect(find.text('New item'), findsNothing);
    });

    // Typing over the price does unlatch it: the grid would otherwise claim a
    // listed price the user has just contradicted.
    testWidgets('typing a different amount unlatches the tile', (tester) async {
      final priced = ServiceCatalog([
        CatalogEntry(
          id: 'netflix',
          name: 'Netflix Premium',
          aliases: const ['netflix'],
          categoryId: 'STREAMING',
          defaultCycle: Cycle.monthly,
          defaultPlan: 'premium',
          plans: const [
            CatalogPlan(
              tier: 'premium',
              name: 'Premium',
              region: 'VN',
              currency: 'VND',
              cycle: Cycle.monthly,
              amountMinor: 260000,
              source: 'https://netflix.com/vn/plans',
              checkedAt: '2026-07-30',
            ),
          ],
        ),
      ]);

      await show(
        tester,
        AddItemScreen(
          catalog: priced,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );
      await tester.tap(find.text('Netflix Premium'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlanGrid>(find.byType(PlanGrid)).selected,
        'premium·month1',
      );

      await tester.tap(find.text('Other amount'));
      await tester.pumpAndSettle();
      await tester.enterText(find.text('260,000'), '190000');
      await tester.pumpAndSettle();

      expect(tester.widget<PlanGrid>(find.byType(PlanGrid)).selected, isNull);
    });

    // Tapping a known service fills the category, the cycle and the price in
    // one go. It is the biggest single reduction in entry friction here.
    testWidgets('a catalog match fills the rest of the form', (tester) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      expect(find.text('Netflix Premium'), findsOneWidget);

      await tester.tap(find.text('Netflix Premium'));
      await tester.pumpAndSettle();

      // The chip the catalog picked is now the selected one.
      expect(find.text('Streaming'), findsOneWidget);
      // In major units, grouped, the way the catalog row itself showed it —
      // not the 260000 that minor units would put in a dong field.
      expect(find.text('260,000'), findsOneWidget);
    });

    // The form is waiting for a renewal date and an amount, and someone adding
    // a service they have never looked up knows neither. This is the one place
    // in the app that can send them to where both are written down.
    testWidgets('a picked service offers its own account page', (tester) async {
      String? opened;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onOpenLink: (url) => opened = url,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix Premium').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open subscription page'));
      await tester.pumpAndSettle();

      expect(opened, 'https://netflix.com/account');
    });

    // A link to a page the app guessed at is worse than no link.
    testWidgets('and no link at all when the catalogue has none', (
      tester,
    ) async {
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onOpenLink: (_) {},
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'vina');
      await tester.pumpAndSettle();
      await tester.tap(find.text('VinaPhone plan').last);
      await tester.pumpAndSettle();

      expect(find.text('Open subscription page'), findsNothing);
    });

    // An edit never goes through the picker, so the entry has to be found from
    // the name the item already carries.
    testWidgets('the edit form finds the page from the name', (tester) async {
      String? opened;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(
            claude.copyWith(name: 'Netflix Premium'),
            CategoryBook.shipped,
          ),
          onOpenLink: (url) => opened = url,
        ),
      );

      await tester.tap(find.text('Open subscription page'));
      await tester.pumpAndSettle();

      expect(opened, 'https://netflix.com/account');
    });

    // Twenty-two chips scrolling sideways under an answer the catalogue
    // already gave is a question being asked after it was answered.
    testWidgets('a picked service turns the shelf rail into one row', (
      tester,
    ) async {
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix Premium').last);
      await tester.pumpAndSettle();

      // The rail would have every shelf on it; the row has only the one.
      expect(find.text('Insurance'), findsNothing);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Streaming'), findsOneWidget);
    });

    testWidgets('and the row opens a sheet that changes it', (tester) async {
      DraftItem? saved;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix Premium').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Streaming'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bills and utilities').last);
      await tester.pumpAndSettle();

      expect(find.text('Bills and utilities'), findsOneWidget);

      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.category.id, 'UTILITIES');
    });

    // Nobody has answered for someone entering a service by hand either, and
    // the row says so rather than lighting a shelf they never picked.
    testWidgets('a hand-typed service gets the same row, unanswered', (
      tester,
    ) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      // No rail: the shelves live in the sheet behind the row.
      expect(find.text('Insurance'), findsNothing);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Pick a category'), findsOneWidget);
    });

    // The keyboard covers half the screen, and everything the user actually
    // came to fill in -- the date, the cost, the cycle -- is under it. A name
    // that arrived filled in is not the question the form is asking.
    testWidgets('picking a service does not open the keyboard on the name', (
      tester,
    ) async {
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix Premium').last);
      await tester.pumpAndSettle();

      final name = tester.widget<TextField>(find.byType(TextField).first);
      expect(name.controller?.text, 'Netflix Premium');
      expect(name.focusNode?.hasFocus, isFalse);
    });

    // And the other way round: a form with nothing in the name field *is*
    // asking for one, so it opens with the keyboard up.
    testWidgets('an empty name still opens the keyboard', (tester) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      final name = tester.widget<TextField>(find.byType(TextField).first);
      expect(name.controller?.text, isEmpty);
      expect(name.focusNode?.hasFocus, isTrue);
    });

    // A relative shortcut the user cannot verify is a date they will have to
    // re-check against their provider anyway.
    testWidgets('the picked date is echoed back as a real date', (
      tester,
    ) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.tap(find.text('+7'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday, 22/08/2026'), findsOneWidget);
    });

    // The picker used to be the last chip on a rail the user had to scroll
    // sideways through, and it is the control most items need.
    testWidgets('the calendar is a row of its own, not the last chip', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
          onPickDate: (from) async => d('2027-03-09'),
        ),
      );

      expect(find.text('Next payment date'), findsOneWidget);
      expect(find.text('Tap to open the calendar'), findsOneWidget);
      await tester.tap(find.text('Next payment date'));
      await tester.pumpAndSettle();

      // The row now carries the date it was used to pick, rather than sending
      // the reader to a separate line to find out what was chosen. The second
      // line stays -- the card is the same height either way -- and turns from
      // an instruction into how far off the date is.
      expect(find.text('Next payment date'), findsNothing);
      expect(find.text('Tap to open the calendar'), findsNothing);
      expect(find.text('Tuesday, 09/03/2027'), findsOneWidget);
      expect(find.text('In 206 days'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Passport');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.expiresOn, d('2027-03-09'));
    });

    // "My plan runs 5 months" cannot be answered with "then make it a one-off
    // and re-date it by hand five times a year".
    // Monthly and yearly cover nearly everything a person pays for, and both
    // used to cost a sheet: open it, read seven options, tap one, close it.
    testWidgets('the two common cycles are one tap, the rest are behind one', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // No sheet in between.
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(find.text('Every…'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Adobe');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.cycle, Cycle.yearly);
    });

    // A tray reading `Other` on a quarterly plan hides the answer on the one
    // control whose job is to show it.
    testWidgets('the third segment names what it is holding', (tester) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedRow),
          matching: find.text('Other'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarterly').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SegmentedRow),
          matching: find.text('Quarterly'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SegmentedRow),
          matching: find.text('Other'),
        ),
        findsNothing,
      );
    });

    testWidgets('an interval the app has no name for can still be typed', (
      tester,
    ) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Language course');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // The third segment, which is where everything that is not monthly or
      // yearly lives.
      await tester.tap(
        find.descendant(
          // `Other` is a shelf name too, and the rail is on screen.
          of: find.byType(SegmentedRow),
          matching: find.text('Other'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every…'));
      await tester.pumpAndSettle();

      // No second modal: the row is now on the form, under the tray, and the
      // third segment reads back what it holds instead of saying `Other`.
      expect(find.text('Every 2 months'), findsOneWidget);
      expect(find.text('Every'), findsOneWidget);

      await tester.enterText(otherBoxes.last, '5');
      await tester.pumpAndSettle();
      expect(find.text('Every 5 months'), findsOneWidget);

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.cycle, Cycle.every(5, CycleField.month));
    });

    // A prepaid SIM's validity is sold in days, and that is the one item in
    // this app whose lapse cannot be undone.
    testWidgets('a custom interval can be counted in days', (tester) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Viettel SIM');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          // `Other` is a shelf name too, and the rail is on screen.
          of: find.byType(SegmentedRow),
          matching: find.text('Other'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every…'));
      await tester.pumpAndSettle();

      await tester.enterText(otherBoxes.last, '45');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Days'));
      await tester.pumpAndSettle();
      expect(find.text('Every 45 days'), findsOneWidget);

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.cycle, Cycle.every(45, CycleField.day));
    });

    // Two currency chips on one field means the amount can be typed under the
    // wrong one, and the digits alone do not show it.
    testWidgets('the cost is echoed in the other currency', (tester) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Claude');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '111');
      await tester.tap(find.text(r'$'));
      await tester.pumpAndSettle();

      expect(find.textContaining('≈ 2,891,106 ₫'), findsOneWidget);

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      // $111, not the $1.11 that reading the field as cents would have saved.
      expect(saved?.amountMinor, 11100);
      expect(saved?.currency, 'USD');
    });

    // A subscription runs until it is stopped, so `Forever` is the answer
    // until the user says otherwise, and the count control does not exist
    // until they do.
    testWidgets('the count control appears only once Repeats forever is off', (
      tester,
    ) async {
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
        ),
      );

      expect(find.text('Stops after'), findsNothing);

      await tester.tap(find.text('Repeats forever'));
      await tester.pumpAndSettle();
      expect(find.text('Stops after'), findsOneWidget);
      expect(find.text('After a number of payments'), findsOneWidget);
      expect(find.text('On a date'), findsOneWidget);
      // Twelve, the build file's own default. A count control that opens on
      // nothing makes the user answer a question they were not asked.
      expect(find.text('12 payments'), findsOneWidget);

      await tester.tap(find.text('Repeats forever'));
      await tester.pumpAndSettle();
      expect(find.text('Stops after'), findsNothing);
    });

    testWidgets('a limited repeat count reaches the draft', (tester) async {
      DraftItem? saved;
      await showForm(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Course');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('+30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+30'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repeats forever'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('6 payments'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 payments'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save item'));
      await tester.pumpAndSettle();

      expect(saved?.repeatCount, 6);
      expect(saved?.cycle, Cycle.monthly);
    });
  });

  group('Edit item', () {
    final catalog = ServiceCatalog([
      const CatalogEntry(
        id: 'netflix',
        name: 'Netflix Premium',
        aliases: ['netflix'],
        categoryId: 'STREAMING',
        defaultCycle: Cycle.monthly,
      ),
    ]);

    Future<DraftItem?> edit(
      WidgetTester tester,
      TrackedItem item, {
      Future<void> Function(WidgetTester tester)? change,
    }) async {
      DraftItem? saved;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(item, CategoryBook.shipped),
          onSave: (draft) => saved = draft,
        ),
      );
      await change?.call(tester);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      return saved;
    }

    testWidgets('opens on the item rather than on a blank form', (
      tester,
    ) async {
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(claude, CategoryBook.shipped),
        ),
      );

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.text('Claude Pro'), findsOneWidget);
      // \$20.00, offered as `20` rather than as its 2000 cents.
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Monday, 17/08/2026'), findsOneWidget);
    });

    // The complaint this screen was added for: there was no way to correct a
    // price once the item existed.
    testWidgets('the cost can be changed', (tester) async {
      final saved = await edit(
        tester,
        claude,
        change: (tester) async {
          await tester.enterText(find.byType(TextField).at(1), '25');
          await tester.pumpAndSettle();
        },
      );

      // 25 dollars, not 25 cents: the field is in major units both ways.
      expect(saved?.amountMinor, 2500);
      expect(saved?.currency, 'USD');
    });

    // An item can hold several leads and the rail holds one, so the form does
    // not show it. What it does not show, it must not flatten.
    testWidgets('the reminder ladder survives an edit', (tester) async {
      expect(find.text('REMIND ME'), findsNothing);

      final saved = await edit(tester, claude);

      expect(saved?.leadDays, [14, 7, 3, 1, 0]);
    });

    // Opening the editor must never quietly rewrite a value it did not ask
    // about, and the three quick segments cannot say "quarterly".
    testWidgets('a cycle the form does not offer keeps its own segment', (
      tester,
    ) async {
      final quarterly = TrackedItem(
        id: 'domain',
        name: 'Domain name',
        categoryId: 'STREAMING',
        expiresOn: d('2026-09-01'),
        anchorDate: d('2026-09-01'),
        cycle: Cycle.quarterly,
      );

      final saved = await edit(tester, quarterly);

      // On the segment, and on the chip under it that put it there -- the row
      // opens with the item because the segment is the only thing naming the
      // cycle, and a reader has to be able to see what else was on offer.
      expect(
        find.descendant(
          of: find.byType(SegmentedRow),
          matching: find.text('Quarterly'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Currently quarterly'), findsOneWidget);
      expect(saved?.cycle, Cycle.quarterly);
    });

    // The suggestion list would be offering to replace a name the user has
    // already settled on.
    testWidgets('a name that is already right is not re-matched', (
      tester,
    ) async {
      final netflix = TrackedItem(
        id: 'netflix',
        name: 'Netflix Premium',
        categoryId: 'STREAMING',
        expiresOn: d('2026-09-01'),
        anchorDate: d('2026-09-01'),
      );

      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(netflix, CategoryBook.shipped),
        ),
      );

      // One Netflix Premium on screen: the name field. Not a second one in a
      // suggestion card underneath it.
      expect(find.text('Netflix Premium'), findsOneWidget);
    });

    testWidgets('the name can be emptied in one tap', (tester) async {
      final netflix = TrackedItem(
        id: 'netflix',
        name: 'Netflix Premium',
        categoryId: 'STREAMING',
        expiresOn: d('2026-09-01'),
        anchorDate: d('2026-09-01'),
      );

      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          categories: CategoryBook.shipped,
          today: today,
          initial: DraftItem.of(netflix, CategoryBook.shipped),
        ),
      );

      expect(find.widgetWithText(TextField, 'Netflix Premium'), findsOneWidget);

      // The name field is the only thing on the form carrying a clear button:
      // the form has no search box of its own.
      final clear = find.byIcon(Icons.close_rounded);
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('Netflix Premium'), findsNothing);
      // And it takes itself away once there is nothing left to clear.
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('Scan a bill', () {
    ExtractedFields fields({
      String? dueDateIso = '2026-09-01',
      String? dueDateRaw = '01/09/2026',
      DateFormatKind format = DateFormatKind.dmy,
    }) => ExtractedFields(
      sourceType: SourceType.billingEmail,
      serviceName: 'Netflix',
      serviceNameRaw: 'Netflix Premium',
      amountMinor: 231000,
      amountRaw: '231.000đ',
      currencyCode: 'VND',
      currencySymbolRaw: 'đ',
      dueDateIso: dueDateIso,
      dueDateRaw: dueDateRaw,
      dateFormat: format,
      confidence: Confidence.high,
    );

    testWidgets('every value is shown beside the text it came from', (
      tester,
    ) async {
      await show(
        tester,
        ReviewExtractionScreen(result: ExtractionReview.review(fields())),
      );

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('Netflix Premium'), findsOneWidget);
      expect(find.text('231.000đ'), findsOneWidget);
    });

    // The information that would disambiguate 03/04 is genuinely absent from
    // the text, so the app offers both readings and pre-selects neither.
    testWidgets('an ambiguous date blocks saving until one reading is picked', (
      tester,
    ) async {
      ExtractedFields? confirmed;
      await show(
        tester,
        ReviewExtractionScreen(
          result: ExtractionReview.review(
            fields(
              dueDateIso: null,
              dueDateRaw: '03/04/2026',
              format: DateFormatKind.ambiguous,
            ),
          ),
          onConfirm: (f) => confirmed = f,
        ),
      );

      // Named months, not two arrangements of the same two digits.
      expect(find.text('3 April'), findsOneWidget);
      expect(find.text('4 March'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(confirmed, isNull, reason: 'no reading picked yet');

      await tester.tap(find.text('3 April'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(confirmed, isNotNull);
    });

    testWidgets('a clean read can be confirmed straight away', (tester) async {
      ExtractedFields? confirmed;
      await show(
        tester,
        ReviewExtractionScreen(
          result: ExtractionReview.review(fields()),
          onConfirm: (f) => confirmed = f,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(confirmed, isNotNull);
    });

    testWidgets('the provenance line is always on screen', (tester) async {
      await show(
        tester,
        ReviewExtractionScreen(result: ExtractionReview.review(fields())),
      );

      expect(
        find.textContaining('Nothing here is confirmed until you save it'),
        findsOneWidget,
      );
    });
  });

  // Driven by the catalogue the app actually ships rather than a fixture, so a
  // data change that emptied Claude's plans fails here instead of shipping a
  // screen with a blank space where the comparison used to be.
  group('what the catalogue puts on the item screen', () {
    final shipped = ServiceCatalog(
      BundledData.parseCatalog(File('assets/services.json').readAsStringSync())
          .entries,
    );
    final checked = LocalDate.parse('2026-08-24');

    TrackedItem claudeItem({
      PurchaseChannel channel = PurchaseChannel.unknown,
    }) => TrackedItem(
      id: 'claude',
      name: 'Claude',
      categoryId: 'STREAMING',
      expiresOn: d('2026-09-17'),
      anchorDate: d('2026-09-17'),
      cycle: Cycle.monthly,
      amountMinor: 2000,
      currency: 'USD',
      purchaseChannel: channel,
    );

    Widget screen({
      TrackedItem? item,
      bool matched = true,
      void Function(ManageAction)? onOpenManage,
    }) {
      final subject = item ?? claudeItem();
      return ItemDetailScreen(
        item: subject,
        category: CategoryBook.shipped[subject.categoryId],
        today: checked,
        catalogEntry: matched ? shipped.matchByName(subject.name) : null,
        onOpenManage: onOpenManage ?? (_) {},
      );
    }

    testWidgets('the yearly comparison, with its sum spelled out', (
      tester,
    ) async {
      await show(tester, screen());

      expect(find.text('YEARLY PLAN'), findsOneWidget);
      expect(find.textContaining('Save', findRichText: true), findsWidgets);
      expect(find.text(r'$20.00 × 12 = $240.00'), findsOneWidget);
      expect(find.text(r'$200.00'), findsOneWidget);
      expect(find.text('Listed price, checked 23 Aug 2026'), findsOneWidget);
    });

    testWidgets('nothing at all when the name matches no catalog row', (
      tester,
    ) async {
      await show(tester, screen(matched: false));

      expect(find.text('YEARLY PLAN'), findsNothing);
      expect(find.text('Open Claude account'), findsNothing);
      // Still offered the store: something that renews every month is worth a
      // link to Apple's list even when the app has never heard of it.
      expect(find.text('Manage in the App Store'), findsOneWidget);
    });

    testWidgets('the vendor page, with the store offered underneath', (
      tester,
    ) async {
      await show(tester, screen());

      expect(find.text('Open Claude account'), findsOneWidget);
      expect(find.text('Bought through the App Store?'), findsOneWidget);
    });

    testWidgets('either tap tells the app where it was bought', (tester) async {
      final taps = <ManageAction>[];
      await show(tester, screen(onOpenManage: taps.add));

      await tester.tap(find.text('Open Claude account'));
      await tester.tap(find.text('Bought through the App Store?'));
      await tester.pump();

      expect(taps.map((a) => a.records), [
        PurchaseChannel.web,
        PurchaseChannel.appStore,
      ]);
      expect(taps.first.url, 'https://claude.ai/settings/billing');
    });

    testWidgets('the question is gone once it has been answered', (
      tester,
    ) async {
      await show(
        tester,
        screen(item: claudeItem(channel: PurchaseChannel.appStore)),
      );

      expect(find.text('Bought through the App Store?'), findsNothing);
      expect(find.text('Manage in the App Store'), findsOneWidget);
    });

    // A screen with no handler cannot open anything, so it must not draw a
    // button that does nothing when tapped.
    testWidgets('no button on a screen that cannot open a link', (
      tester,
    ) async {
      await show(
        tester,
        ItemDetailScreen(
          item: claudeItem(),
          category: CategoryBook.shipped['STREAMING'],
          today: checked,
          catalogEntry: shipped.matchByName('Claude'),
        ),
      );

      expect(find.text('Open Claude account'), findsNothing);
      expect(find.text('YEARLY PLAN'), findsOneWidget);
    });
  });
}
