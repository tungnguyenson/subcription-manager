import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/screens/money_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/empty_placard.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/tab_mark.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSubdockTheme(),
        home: Scaffold(backgroundColor: SubdockColors.canvas, body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  TrackedItem item(
    String name, {
    required String expiresOn,
    Category category = Category.subscription,
    int? amountMinor,
    String? currency,
    Cycle? cycle,
    int? repeatCount,
    String? anchorDate,
  }) => TrackedItem(
    id: name,
    name: name,
    category: category,
    expiresOn: d(expiresOn),
    anchorDate: d(anchorDate ?? expiresOn),
    cycle: cycle,
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: currency,
  );

  final sample = [
    item(
      'SIM Viettel 0912 345 678',
      expiresOn: '2026-08-11',
      category: Category.subscription,
    ),
    item(
      'Claude Pro',
      expiresOn: '2026-08-17',
      category: Category.subscription,
      amountMinor: 2000,
      currency: 'USD',
    ),
    item(
      'Netflix Premium',
      expiresOn: '2026-08-21',
      amountMinor: 260000,
      currency: 'VND',
    ),
    item('Passport', expiresOn: '2027-03-01', category: Category.document),
  ];

  group('Upcoming', () {
    testWidgets('renders every bucket with real content', (tester) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('NEXT 7 DAYS'), findsOneWidget);
      expect(find.text('SIM Viettel 0912 345 678'), findsOneWidget);
      expect(find.text('Netflix Premium'), findsOneWidget);
    });

    // The row itself is not re-coloured. Only the countdown changes, so the
    // list does not read as a list of errors.
    testWidgets('an overdue row is drawn in the danger colour', (tester) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      final overdue = tester.widget<Text>(find.text('Overdue').last);
      expect(overdue.style?.color, SubdockColors.danger);
    });

    // Things a year out are real but must not compete with this week.
    testWidgets('a distant bucket starts folded and opens on tap', (
      tester,
    ) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      expect(find.text('Passport'), findsNothing);
      // The count is on the closed row, so the user knows there is something
      // in there before opening it.
      expect(find.textContaining('1 item'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Passport'), findsOneWidget);
    });

    // An empty list in a reminder app is ambiguous: nothing due, or the app
    // stopped working? Saying what it knows resolves that.
    testWidgets('an empty list explains itself and offers the way in', (
      tester,
    ) async {
      var added = false;
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(const [], today),
          onAdd: () => added = true,
        ),
      );

      expect(find.text('Nothing tracked yet'), findsOneWidget);
      // A blank rectangle reads as a component that failed to load. The
      // placard has to say "an item, with nothing in it" on its own.
      expect(find.byType(EmptyPlacard), findsOneWidget);
      await tester.tap(find.text('Add an item'));
      expect(added, isTrue);
    });

    testWidgets('tapping a row reports which one', (tester) async {
      String? opened;
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(sample, today),
          onOpen: (entry) => opened = entry.id,
        ),
      );

      await tester.tap(find.text('Netflix Premium'));
      await tester.pumpAndSettle();
      expect(opened, 'Netflix Premium');
    });

    // Four identical amounts in a row look like a bug; the instalment clause
    // is what makes them read as a plan running to schedule.
    testWidgets('an instalment row says which payment it is', (tester) async {
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build([
            item(
              'Course instalment',
              anchorDate: '2026-05-21',
              expiresOn: '2026-08-21',
              category: Category.bill,
              cycle: Cycle.monthly,
              repeatCount: 6,
              amountMinor: 1200000,
              currency: 'VND',
            ),
          ], today),
        ),
      );

      expect(find.text('1,200,000 ₫ · payment 4 of 6'), findsOneWidget);
    });
  });

  group('Money', () {
    testWidgets('shows the approximation and the exact subtotals under it', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.vnd(618000), Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );
      await show(tester, MoneyScreen(thisMonth: total));

      expect(find.text('Money'), findsOneWidget);
      expect(find.textContaining('≈'), findsWidgets);
      expect(find.textContaining('618,000 ₫'), findsWidgets);
      expect(find.textContaining(r'$20.00'), findsWidgets);
    });

    // A converted figure with no rate date silently rewrites itself.
    testWidgets('the converted total always carries its rate and date', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );
      await show(tester, MoneyScreen(thisMonth: total));

      expect(find.textContaining('26,046'), findsOneWidget);
      expect(find.textContaining('14/08/2026'), findsOneWidget);
    });

    testWidgets('a stale rate leaves no confident number on screen', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: LocalDate.parse('2026-12-01'),
      );
      await show(tester, MoneyScreen(thisMonth: total));

      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('left unconverted'), findsOneWidget);
    });

    // The breakdown answers "what is taking my money", not "what kind of
    // spender am I".
    testWidgets('the breakdown is by item, biggest first', (tester) async {
      await show(
        tester,
        MoneyScreen(
          thisMonth: Fx.total(
            [Money.vnd(260000), Money.vnd(842000)],
            rate: Fx.bundledUsdVnd,
            today: today,
          ),
          items: [
            ItemSpend(name: 'Electricity bill', total: Money.vnd(842000)),
            ItemSpend(name: 'Netflix Premium', total: Money.vnd(260000)),
          ],
        ),
      );

      expect(find.text('BY ITEM'), findsOneWidget);
      expect(find.text('842,000 ₫'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('dropped reminders are surfaced, not buried', (tester) async {
      await show(
        tester,
        const SettingsScreen(droppedReminders: ['Passport', 'Inspection']),
      );

      expect(
        find.textContaining('2 reminders could not be scheduled'),
        findsOneWidget,
      );
      expect(find.textContaining('Passport'), findsOneWidget);
    });

    testWidgets('no banner when everything fitted', (tester) async {
      await show(tester, const SettingsScreen());
      expect(find.byType(AlertBanner), findsNothing);
    });

    // A chevron promises a picker. Currency and language have neither, so
    // neither gets one.
    testWidgets('value rows do not pretend to lead anywhere', (tester) async {
      await show(tester, const SettingsScreen());

      expect(find.text('VND'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('›'), findsNWidgets(4));
    });
  });

  group('Shell', () {
    testWidgets('has three destinations plus the add button', (tester) async {
      ShellTab? picked;
      var added = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSubdockTheme(),
          home: AppShell(
            current: ShellTab.upcoming,
            onSelect: (tab) => picked = tab,
            onAdd: () => added = true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Money'));
      expect(picked, ShellTab.money);

      await tester.tap(find.byTooltip('Add an item'));
      expect(added, isTrue);
    });

    // Which tab you are on has to be answerable without comparing three
    // labels against each other, so the selected one differs in colour,
    // weight and background at once rather than in any single one of them.
    testWidgets('the selected destination is marked three ways', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSubdockTheme(),
          home: AppShell(
            current: ShellTab.money,
            onSelect: (_) {},
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selected = tester.widget<Text>(find.text('Money'));
      expect(selected.style?.color, SubdockColors.accent);
      expect(selected.style?.fontWeight, FontWeight.w600);

      final other = tester.widget<Text>(find.text('Settings'));
      expect(other.style?.color, SubdockColors.inkMuted);

      // Filled versus outlined, not colour alone: colour is the one signal
      // that fails in sunlight and for a red-green deficiency.
      final marks = tester.widgetList<TabMark>(find.byType(TabMark)).toList();
      expect(marks.where((mark) => mark.active), hasLength(1));
      expect(marks.where((mark) => !mark.active), hasLength(2));
      expect(
        tester.widget<Icon>(find.byType(Icon).at(1)).icon,
        TabGlyph.money.filled,
      );
    });
  });
}
