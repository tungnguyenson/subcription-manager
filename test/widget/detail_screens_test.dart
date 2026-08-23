import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/extract/extraction_review.dart';
import 'package:subdock/extract/extraction_schema.dart';
import 'package:subdock/ui/screens/add_item_screen.dart';
import 'package:subdock/ui/screens/history_screen.dart';
import 'package:subdock/ui/screens/item_detail_screen.dart';
import 'package:subdock/ui/screens/onboarding_screen.dart';
import 'package:subdock/ui/screens/reminder_rules_screen.dart';
import 'package:subdock/ui/screens/reminders_screen.dart';
import 'package:subdock/ui/screens/review_extraction_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/primitives.dart';

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
    category: Category.subscription,
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
    category: Category.bill,
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
        ItemDetailScreen(item: claude, today: today, scheduledCount: 4),
      );

      expect(find.text('Claude Pro'), findsOneWidget);
      expect(find.text(r'Due in 2 days · 17/08 · $20.00'), findsOneWidget);
    });

    // The app only knows what the user typed. This row is what stops a
    // remembered date from looking like a confirmed one.
    testWidgets('shows where the date came from', (tester) async {
      await show(tester, ItemDetailScreen(item: claude, today: today));
      expect(find.text('from memory'), findsOneWidget);
    });

    // Deleting also removes pending reminders the user cannot see.
    testWidgets('the delete action states both consequences', (tester) async {
      await show(
        tester,
        ItemDetailScreen(item: claude, today: today, scheduledCount: 4),
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
        await show(tester, ItemDetailScreen(item: course, today: today));

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
            today: today,
            onMarkPaid: () => paid = true,
          ),
        );

        await tester.tap(find.text('Mark payment 4 as paid'));
        expect(paid, isTrue);
      });

      testWidgets('ending it is phrased in the plan own terms', (tester) async {
        await show(tester, ItemDetailScreen(item: course, today: today));

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
            today: today,
          ),
        );

        expect(find.text('Payment'), findsNothing);
        expect(find.text('Mark as paid'), findsOneWidget);
      });
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

      expect(find.textContaining('Holds 4 of the 64'), findsOneWidget);
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
  });

  group('History', () {
    testWidgets('groups by month and separates skipped from done', (
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
              amount: '169,000 ₫',
            ),
            HistoryEntry(
              itemName: 'Adobe',
              on: d('2026-07-04'),
              what: 'cancelled',
            ),
          ],
          skipped: [
            HistoryEntry(
              itemName: 'Netflix Premium',
              on: d('2026-07-21'),
              what: 'skipped one cycle',
            ),
          ],
        ),
      );

      expect(find.text('AUGUST'), findsOneWidget);
      expect(find.text('JULY'), findsOneWidget);
      expect(find.text('SKIPPED'), findsOneWidget);
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
    testWidgets('names the three things the app does, in order', (
      tester,
    ) async {
      await show(tester, const OnboardingScreen());

      expect(find.text('Never miss a due date again.'), findsOneWidget);
      expect(find.text('Add what you pay for'), findsOneWidget);
      expect(find.text('Pick when to be reminded'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);
    });

    testWidgets('the permission is asked for here, not at first launch', (
      tester,
    ) async {
      var allowed = false;
      var started = false;
      await show(
        tester,
        OnboardingScreen(
          onAllowNotifications: () => allowed = true,
          onStart: () => started = true,
        ),
      );

      await tester.tap(find.text('Allow notifications'));
      await tester.tap(find.text('Get started'));
      expect(allowed, isTrue);
      expect(started, isTrue);
    });

    testWidgets('once granted, the ask is replaced rather than repeated', (
      tester,
    ) async {
      await show(tester, const OnboardingScreen(notificationsGranted: true));

      expect(find.text('Allow notifications'), findsNothing);
      expect(find.text('Notifications are on'), findsOneWidget);
    });
  });

  group('Add item', () {
    final catalog = ServiceCatalog([
      const CatalogEntry(
        id: 'netflix',
        name: 'Netflix Premium',
        aliases: ['netflix'],
        category: Category.subscription,
        defaultCycle: Cycle.monthly,
        typicalAmountMinor: 260000,
        currency: 'VND',
      ),
    ]);

    testWidgets('save stays disabled until there is a name and a date', (
      tester,
    ) async {
      DraftItem? saved;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNull, reason: 'nothing typed yet');

      await tester.enterText(find.byType(TextField).first, 'Spotify');
      await tester.pumpAndSettle();
      // The date chips are one row that runs off the edge of the phone, so
      // the last of them has to be scrolled to before it can be tapped.
      await tester.ensureVisible(find.text('In 1 month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In 1 month'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Spotify');
      expect(saved?.expiresOn, d('2026-09-15'));
    });

    // Tapping a known service fills the category, the cycle and the price in
    // one go. It is the biggest single reduction in entry friction here.
    testWidgets('a catalog match fills the rest of the form', (tester) async {
      await show(tester, AddItemScreen(catalog: catalog, today: today));

      await tester.enterText(find.byType(TextField).first, 'net');
      await tester.pumpAndSettle();
      expect(find.text('Netflix Premium'), findsOneWidget);

      await tester.tap(find.text('Netflix Premium'));
      await tester.pumpAndSettle();

      // The chip the catalog picked is now the selected one.
      expect(find.text('Subscription'), findsOneWidget);
      expect(find.text('260000'), findsOneWidget);
    });

    // A relative shortcut the user cannot verify is a date they will have to
    // re-check against their provider anyway.
    testWidgets('the picked date is echoed back as a real date', (
      tester,
    ) async {
      await show(tester, AddItemScreen(catalog: catalog, today: today));

      await tester.tap(find.text('In 7 days'));
      await tester.pumpAndSettle();
      expect(find.text('22/08/2026'), findsOneWidget);
    });

    // "Once" and "how many times" cannot both be true.
    testWidgets('the repeat count disappears for a one-off', (tester) async {
      await show(tester, AddItemScreen(catalog: catalog, today: today));

      expect(find.text('HOW MANY TIMES'), findsOneWidget);
      await tester.tap(find.text('Once'));
      await tester.pumpAndSettle();
      expect(find.text('HOW MANY TIMES'), findsNothing);
    });

    testWidgets('a limited repeat count reaches the draft', (tester) async {
      DraftItem? saved;
      await show(
        tester,
        AddItemScreen(
          catalog: catalog,
          today: today,
          onSave: (draft) => saved = draft,
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Course');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('In 1 month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In 1 month'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forever'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 times'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.repeatCount, 6);
      expect(saved?.cycle, Cycle.monthly);
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
}
