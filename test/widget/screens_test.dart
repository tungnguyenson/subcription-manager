import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/money_presenter.dart';
import 'package:subdock/ui/screens/money_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/ui/widgets/restore_ask.dart';
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
    String categoryId = 'STREAMING',
    int? amountMinor,
    String? currency,
    Cycle? cycle,
    int? repeatCount,
    String? anchorDate,
  }) => TrackedItem(
    id: name,
    name: name,
    categoryId: categoryId,
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
      categoryId: 'STREAMING',
    ),
    item(
      'Claude Pro',
      expiresOn: '2026-08-17',
      categoryId: 'STREAMING',
      amountMinor: 2000,
      currency: 'USD',
    ),
    item(
      'Netflix Premium',
      expiresOn: '2026-08-21',
      amountMinor: 260000,
      currency: 'VND',
    ),
    item('Passport', expiresOn: '2027-03-01', categoryId: 'DOCUMENTS'),
  ];

  group('Upcoming', () {
    testWidgets('renders every bucket with real content', (tester) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      expect(find.text('Upcoming'), findsOneWidget);
      // The heading carries its count in the same span, so match on the words
      // rather than on the whole string: `OVERDUE  1`.
      expect(find.textContaining('OVERDUE'), findsOneWidget);
      expect(find.textContaining('NEXT 7 DAYS'), findsOneWidget);
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

      // `Late` in a filled danger pill, so the colour to check is the fill
      // rather than the type: white words on red, not red words on glass.
      final pill = tester.widget<Container>(
        find
            .ancestor(of: find.text('Late'), matching: find.byType(Container))
            .first,
      );
      expect((pill.decoration as BoxDecoration).color, SubdockColors.danger);
    });

    // Every bucket on this screen is open. A section that arrives folded hides
    // items behind a tap the user has no reason to expect, and the hand-off
    // draws none of them that way. Distance is expressed by scroll position,
    // not by a summary row.
    testWidgets('a distant bucket is a section like any other, not a fold', (
      tester,
    ) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      expect(find.textContaining('LATER'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      // Nothing to tap open, so nothing offering to be tapped open.
      expect(find.textContaining('1 item'), findsNothing);
    });

    // The tab bar is drawn *over* the list, not above it, so a screen padded
    // by `contentBottom` alone leaves its last row underneath the bar where no
    // tap reaches it. This is how `Delete this item` became unreachable.
    testWidgets('the last row clears the tab bar rather than hiding under it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      // A home indicator, which is what makes the bar tall enough on a real
      // phone to swallow a row.
      tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildSubdockTheme(),
          home: AppShell(
            current: ShellTab.settings,
            onSelect: (_) {},
            child: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to the very bottom, the way a user reaching for the last row
      // would.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('About')).bottom,
        lessThan(tester.getRect(find.byType(TabMark).first).top),
        reason: 'the last row sits under the tab bar and cannot be tapped',
      );
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
              categoryId: 'UTILITIES',
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
    /// The month view, with a total the caller controls.
    ///
    /// Reconstructed after the screen moved from loose parameters to a single
    /// [MoneyView]; the assertions below are unchanged in what they check.
    MoneyView view(
      MixedTotal total, {
      List<ItemSpend> items = const [],
      List<SpendBar> bars = const [],
    }) => MoneyView(
      span: MoneySpan.month,
      label: 'This month',
      total: total,
      // Derived the way the real presenter derives it rather than hand-built:
      // the point of the line is that it is the headline converted, and a
      // fixture that makes up a figure cannot check that.
      alternateTotal: MoneyPresenter.alternateTotal(total),
      items: items,
      bars: bars,
    );

    testWidgets('restates a mixed total once, in the other currency', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.vnd(618000), Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );
      await show(tester, MoneyScreen(view: view(total)));

      // `Money` on the screen, `Spending` on the tab that opens it. See the
      // comment on the title in MoneyScreen.
      expect(find.text('Money'), findsOneWidget);
      // 618,000 ₫ + $20 at 26,046, then the same figure back at the same rate.
      expect(find.textContaining('1,138,920 ₫'), findsOneWidget);
      expect(find.textContaining(r'$43.73'), findsOneWidget);
      // The same total in the other currency, quietly, under the headline.
      // Three groups of figures on this card was the bug; one restatement is
      // what a second currency actually needs.
      expect(find.text('EXACT AMOUNTS'), findsNothing);
    });

    // The rate sits against the figure it produced, once, and nowhere else.
    // It used to have a line of its own at the foot of the card, where it
    // showed up whether or not anything had been converted.
    testWidgets('the converted figure carries its rate, and only there', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.vnd(618000), Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );
      await show(tester, MoneyScreen(view: view(total)));

      expect(find.textContaining(r'(26,046 ₫/$)'), findsOneWidget);
      expect(find.textContaining('rate 26,046'), findsNothing);
      expect(find.textContaining('14/08/2026'), findsNothing);
    });

    // The tilde means a rate was applied. A list of dong amounts is exact to
    // the dong, and a tilde over it claims an imprecision it never incurred.
    testWidgets('a dong-only total is shown without a tilde', (tester) async {
      final total = Fx.total(
        [Money.vnd(618000)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );
      await show(tester, MoneyScreen(view: view(total)));

      expect(find.text('618,000 ₫'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
      expect(find.textContaining('26,046'), findsNothing);
    });

    testWidgets('a stale rate leaves no confident number on screen', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.usd(20)],
        rate: Fx.bundledUsdVnd,
        today: LocalDate.parse('2026-12-01'),
      );
      await show(tester, MoneyScreen(view: view(total)));

      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('left unconverted'), findsOneWidget);
      expect(find.textContaining('26,046'), findsNothing);
    });

    // The breakdown answers "what is taking my money", not "what kind of
    // spender am I".
    testWidgets('the breakdown is by item, biggest first', (tester) async {
      await show(
        tester,
        MoneyScreen(
          view: view(
            Fx.total(
              [Money.vnd(260000), Money.vnd(842000)],
              rate: Fx.bundledUsdVnd,
              today: today,
            ),
            items: [
              ItemSpend(name: 'Electricity bill', total: Money.vnd(842000)),
              ItemSpend(name: 'Netflix Premium', total: Money.vnd(260000)),
            ],
          ),
        ),
      );

      expect(find.text('BY ITEM'), findsOneWidget);
      expect(find.text('842,000 ₫'), findsOneWidget);
    });

    // Six zeroed columns claim "you spent nothing"; no chart at all says "no
    // record yet", which is the truth about a list with nothing in the year.
    testWidgets('the chart is absent when the year holds nothing', (
      tester,
    ) async {
      final total = Fx.total(
        [Money.vnd(260000)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );

      await show(tester, MoneyScreen(view: view(total)));
      expect(find.text('COST BY MONTH'), findsNothing);

      await show(
        tester,
        MoneyScreen(
          view: view(
            total,
            bars: const [
              SpendBar(month: 7, label: '7', longLabel: 'July', minor: 100000),
              SpendBar(
                month: 8,
                label: '8',
                longLabel: 'August',
                minor: 260000,
                current: true,
                selected: true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('COST BY MONTH'), findsOneWidget);
    });

    // The whole point of twelve columns: the card follows the one you tap.
    testWidgets('tapping a column asks for that month', (tester) async {
      final total = Fx.total(
        [Money.vnd(260000)],
        rate: Fx.bundledUsdVnd,
        today: today,
      );

      int? asked;
      await show(
        tester,
        MoneyScreen(
          view: view(
            total,
            bars: const [
              SpendBar(month: 7, label: '7', longLabel: 'July', minor: 100000),
              SpendBar(
                month: 8,
                label: '8',
                longLabel: 'August',
                minor: 260000,
                current: true,
                selected: true,
              ),
            ],
          ),
          onMonth: (month) => asked = month,
        ),
      );

      await tester.tap(find.text('7'));
      expect(asked, 7);
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

    // A chevron promises a picker. Currency, language and the widget row have
    // none, so none of them gets one.
    testWidgets('value rows do not pretend to lead anywhere', (tester) async {
      await show(tester, const SettingsScreen());

      expect(find.text('VND'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text('›'), findsNWidgets(7));
    });

    // The only copy of anything is on the phone, and no other screen says so.
    // The two rows below this footnote are the only answer to a lost phone.
    testWidgets('backup rows say why they are there', (tester) async {
      var exported = 0;
      var imported = 0;
      await show(
        tester,
        SettingsScreen(onExport: () => exported++, onImport: () => imported++),
      );

      expect(find.textContaining('no account and no server'), findsOneWidget);

      await tester.tap(find.text('Export a backup'));
      await tester.tap(find.text('Restore from a backup'));
      await tester.pumpAndSettle();

      expect((exported, imported), (1, 1));
    });

    // A value sitting at the end of its own half of the row reads as a second
    // column of labels. It belongs against the card's right edge.
    testWidgets('a value is flush right, not stranded mid-row', (tester) async {
      await show(tester, const SettingsScreen());

      // Two values of different widths share a right edge only when both are
      // flush right. Stranded at the end of their own half of the row, they
      // would each stop wherever their own text happened to end.
      expect(
        tester.getRect(find.text('VND')).right,
        closeTo(tester.getRect(find.text('English')).right, 0.5),
      );
      expect(
        tester.getRect(find.text('VND')).right,
        greaterThan(tester.getRect(find.text('Currency')).right),
      );
    });
  });

  group('Shell', () {
    Future<void> shell(
      WidgetTester tester, {
      ShellTab current = ShellTab.upcoming,
      ValueChanged<ShellTab>? onSelect,
      VoidCallback? onAdd,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSubdockTheme(),
          home: AppShell(
            current: current,
            onSelect: onSelect ?? (_) {},
            onAdd: onAdd,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('has four destinations plus the add button', (tester) async {
      ShellTab? picked;
      var added = false;

      await shell(
        tester,
        onSelect: (tab) => picked = tab,
        onAdd: () => added = true,
      );

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Spending'));
      expect(picked, ShellTab.money);

      await tester.tap(find.byTooltip('Add an item'));
      expect(added, isTrue);
    });

    // Which tab you are on has to be answerable without comparing four labels
    // against each other, so the selected one differs in colour *and* in the
    // mark being filled rather than outlined. Colour is the one signal that
    // fails in sunlight and for a red-green deficiency.
    testWidgets('the selected destination is marked two ways', (tester) async {
      await shell(tester, current: ShellTab.money);

      final selected = tester.widget<Text>(find.text('Spending'));
      expect(selected.style?.color, SubdockColors.accent);

      final other = tester.widget<Text>(find.text('Settings'));
      expect(other.style?.color, SubdockColors.inkMuted);

      final marks = tester.widgetList<TabMark>(find.byType(TabMark)).toList();
      expect(marks.where((mark) => mark.active), hasLength(1));
      expect(marks.where((mark) => !mark.active), hasLength(3));
    });

    // The savings *screen* is green; the bar is not part of any one screen. A
    // row of four where one is a different hue reads as that tab being in a
    // different state.
    testWidgets('every selected tab takes the same accent', (tester) async {
      for (final tab in ShellTab.values) {
        await shell(tester, current: tab);
        final label = switch (tab) {
          ShellTab.upcoming => 'Upcoming',
          ShellTab.money => 'Spending',
          ShellTab.savings => 'Savings',
          ShellTab.settings => 'Settings',
        };
        expect(
          tester.widget<Text>(find.text(label)).style?.color,
          SubdockColors.accent,
          reason: '$tab is not in the accent',
        );
      }
    });
  });

  // Restoring deletes rows the user typed and there is nowhere to undo it
  // from, so this sheet is the one place in the app whose job is to be read.
  group('Restore confirmation', () {
    testWidgets('names both sides of the trade', (tester) async {
      await show(
        tester,
        const RestoreAsk(
          incoming: '12 items, 40 payments',
          existing: '3 items',
          takenOn: 'taken 25/08/2026',
        ),
      );

      expect(
        find.textContaining('12 items, 40 payments'),
        findsOneWidget,
        reason: 'what arrives',
      );
      expect(find.text('3 items'), findsOneWidget, reason: 'what goes');
      expect(find.textContaining('taken 25/08/2026'), findsOneWidget);
    });

    // The prettiest button on a sheet gets tapped by people who were not
    // reading, so the filled one is the safe answer -- the same shape the item
    // screen uses for "Mark as paid" against "Delete this item".
    testWidgets('the filled button is the one that changes nothing', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;
      await show(
        tester,
        RestoreAsk(
          incoming: '12 items',
          existing: '3 items',
          onConfirm: () => confirmed++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect((confirmed, cancelled), (0, 1));

      await tester.tap(find.text('Replace everything'));
      await tester.pumpAndSettle();
      expect((confirmed, cancelled), (1, 1));
    });

    // A fresh install is the common case for a restore, and there is nothing
    // to lose on one. Shouting about deletion there teaches the user to tap
    // through the warning that will matter later.
    testWidgets('with nothing to lose it does not talk about losing', (
      tester,
    ) async {
      await show(tester, const RestoreAsk(incoming: '12 items'));

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.textContaining('Deleted from this phone'), findsNothing);
    });
  });
}
