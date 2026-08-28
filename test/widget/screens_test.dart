import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/fx.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/app_shell.dart';
import 'package:subdock/ui/calendar_presenter.dart';
import 'package:subdock/ui/money_presenter.dart';
import 'package:subdock/ui/screens/money_screen.dart';
import 'package:subdock/ui/screens/about_screen.dart';
import 'package:subdock/ui/screens/backup_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/sources_screen.dart';
import 'package:subdock/ui/services_presenter.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/ui/backup_presenter.dart';
import 'package:subdock/ui/widgets/primitives.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/ui/widgets/cancel_ask.dart';
import 'package:subdock/ui/widgets/restore_ask.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/empty_placard.dart';
import 'package:subdock/ui/widgets/item_row.dart';
import 'package:subdock/ui/widgets/tab_mark.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  /// The decoration [ItemRow] draws itself with, for the row carrying [name].
  /// The row's own Container is the outermost one under it.
  BoxDecoration rowBoxOf(WidgetTester tester, String name) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.ancestor(
                        of: find.textContaining(name),
                        matching: find.byType(ItemRow),
                      ),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

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
    bool inTrial = false,
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
    inTrial: inTrial,
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

    // The rows are a list, and a list is read by running an eye down it. Each
    // row used to be its own translucent card, which put four edges and a 10px
    // moat around every line: a screen of eight items read as eight separate
    // objects that happened to be stacked.
    testWidgets('rows are ruled, not carded', (tester) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      final row = rowBoxOf(tester, 'Netflix');
      expect(row.color, isNull, reason: 'a ruled row has no fill');
      expect(row.borderRadius, isNull);
      expect(row.boxShadow, anyOf(isNull, isEmpty));
      expect(
        (row.border as Border).bottom.color,
        SubdockColors.hairline,
        reason: 'the rule under it is the whole separation',
      );
    });

    // The cost of dropping the card, named out loud: an overdue row can no
    // longer carry a danger fill and a danger edge, because there is nothing
    // left to fill. Its countdown pill carries it alone -- and that pill is
    // the loudest thing on the row either way.
    testWidgets('an overdue row signals with the pill, not a red panel', (
      tester,
    ) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );

      final row = rowBoxOf(tester, 'Viettel');
      expect(row.color, isNull);
      expect((row.border as Border).bottom.color, SubdockColors.hairline);
    });

    testWidgets('the card look can be asked for back', (tester) async {
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(sample, today),
          rowStyle: ItemRowStyle.cards,
        ),
      );

      expect(rowBoxOf(tester, 'Netflix').color, SubdockColors.card);
      expect(rowBoxOf(tester, 'Viettel').color, SubdockColors.dangerTint);
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

    // The header offers both layouts, and the calendar is a layout rather than
    // a second list: the same items, laid out by date instead of by distance.
    testWidgets('the calendar draws a grid and opens a day under it', (
      tester,
    ) async {
      final calendar = CalendarPresenter.build(sample, today);
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(sample, today),
          mode: UpcomingMode.calendar,
          calendar: calendar,
        ),
      );

      expect(find.text('Aug 2026'), findsOneWidget);
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      // The soonest day with something on it, headed the way a section is.
      expect(find.textContaining('MON 17 AUG 2026'), findsOneWidget);
      expect(find.text('Claude Pro'), findsOneWidget);
      // And none of the list's own headings, which would be the two layouts
      // drawn at once.
      expect(find.textContaining('NEXT 7 DAYS'), findsNothing);
    });

    // A day the reader taps that has nothing on it still gets its heading.
    // Dropping the block would leave them with no sign the tap landed.
    testWidgets('an empty day says so rather than vanishing', (tester) async {
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(sample, today),
          mode: UpcomingMode.calendar,
          calendar: CalendarPresenter.build(
            sample,
            today,
            selected: d('2026-08-04'),
          ),
        ),
      );

      expect(find.textContaining('TUE 4 AUG 2026'), findsOneWidget);
      expect(find.text('Nothing on this day.'), findsOneWidget);
      // No `0` beside the heading: the line under it already said that.
      expect(find.textContaining('TUE 4 AUG 2026  0'), findsNothing);
    });

    // The chip is a shortcut to the `Free trials` condition the sheet holds,
    // and it is the only trace of trials left on this header now that they
    // have no section of their own.
    testWidgets('the trial chip appears only when there is a trial', (
      tester,
    ) async {
      await show(
        tester,
        UpcomingScreen(view: UpcomingPresenter.build(sample, today)),
      );
      expect(find.textContaining('Free trial'), findsNothing);

      final withTrial = [
        ...sample,
        item('Claude Max', expiresOn: '2026-08-18', inTrial: true),
      ];
      await show(
        tester,
        UpcomingScreen(
          key: const ValueKey('with-trial'),
          view: UpcomingPresenter.build(withTrial, today),
        ),
      );
      // Label and count share one span: `Free trial  1`.
      expect(find.textContaining('Free trial'), findsOneWidget);
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

      // The same word as the tab that opens it. It used to read `Money`, and
      // a reader who taps `Spending` and lands somewhere called something else
      // has to check they got where they meant to go.
      expect(find.text('Spending'), findsOneWidget);
      expect(find.text('Money'), findsNothing);
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
    // A taller surface than the 800px default. The backup card and its
    // footnote sit below the fold on a short viewport, and a ListView child
    // that was never built is a child no finder can see.
    Future<void> showTall(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await show(tester, child);
    }

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

    // A chevron promises a picker. Currency and language now have one each --
    // they are answered in onboarding, and the row that shows the answer has
    // to be the row that changes it. The widget row still has none.
    // Tall, because the screen no longer fits a phone: the Appearance tray
    // sits above Backup, and a ListView does not build what is below the fold.
    testWidgets('the rows that lead somewhere are the ones with a picker', (
      tester,
    ) async {
      var currency = 0;
      var language = 0;
      await showTall(
        tester,
        SettingsScreen(
          onOpenCurrency: () => currency++,
          onOpenLanguage: () => language++,
        ),
      );

      expect(find.text('VND'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      // Four destinations, currency, language, the one backup channel that
      // exists without a cloud behind it, and About at the very bottom.
      expect(find.text('›'), findsNWidgets(8));

      await tester.tap(find.text('VND'));
      await tester.tap(find.text('English'));
      expect((currency, language), (1, 1));
    });

    // The only copy of anything is on the phone, and no other screen says so.
    // Two rows, not five. The section used to carry a status, a date and three
    // actions, two of which replace the whole list.
    testWidgets('the two channels are two rows, each with its own date', (
      tester,
    ) async {
      var cloud = 0;
      var file = 0;
      await showTall(
        tester,
        SettingsScreen(
          backup: BackupPresenter.build(
            items: const [],
            saved: LastBackups(
              fileAt: LocalDateTime(d('2026-08-11'), const LocalTime(9, 30)),
            ),
            device: DeviceBackup.wholeDeviceOnly,
            cloud: const CloudChannel(result: CloudResult(CloudState.saved)),
          ),
          onOpenCloudBackup: () => cloud++,
          onOpenFileBackup: () => file++,
        ),
      );

      expect(find.textContaining('no account and no server'), findsOneWidget);
      // The file has a copy; iCloud has written nothing yet. One date beside
      // both rows would have reported the file's date next to iCloud.
      expect(find.text('11/08/2026'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);

      await tester.tap(find.text('iCloud'));
      await tester.tap(find.text('Import/Export'));
      await tester.pumpAndSettle();

      expect((cloud, file), (1, 1));
    });

    // A date beside an iCloud that has been signed out since July is the app
    // reporting a copy it stopped keeping.
    testWidgets('a cloud problem outranks the cloud date', (tester) async {
      await showTall(
        tester,
        SettingsScreen(
          backup: BackupPresenter.build(
            items: const [],
            saved: LastBackups(
              cloudAt: LocalDateTime(d('2026-06-25'), const LocalTime(9, 30)),
            ),
            device: DeviceBackup.wholeDeviceOnly,
            cloud: const CloudChannel(
              result: CloudResult(CloudState.signedOut),
            ),
          ),
          onOpenCloudBackup: () {},
          onOpenFileBackup: () {},
        ),
      );

      expect(find.text('Sign in to iCloud'), findsOneWidget);
      expect(find.text('25/06/2026'), findsNothing);
    });

    // Off iOS the system already carries the database to the next phone, so a
    // row about iCloud would report a gap that does not exist.
    testWidgets('with no cloud there is one row', (tester) async {
      await showTall(
        tester,
        SettingsScreen(
          backup: BackupPresenter.build(
            items: const [],
            saved: LastBackups.none,
            device: DeviceBackup.perAppUnverifiable,
          ),
          onOpenCloudBackup: () {},
          onOpenFileBackup: () {},
        ),
      );

      expect(find.text('iCloud'), findsNothing);
      expect(find.text('Import/Export'), findsOneWidget);
    });

    // The banner exists because Settings is where you go if you already know
    // to worry. It fires on the cost of rebuilding the list, not its length.
    testWidgets('a list of confirmed dates and no backup raises a banner', (
      tester,
    ) async {
      var exported = 0;
      await showTall(
        tester,
        SettingsScreen(
          backup: BackupPresenter.build(
            items: [
              TrackedItem(
                id: 'sim',
                name: 'Viettel',
                categoryId: 'PHONE',
                expiresOn: d('2026-09-01'),
                anchorDate: d('2026-09-01'),
                dateSource: DateSource.userConfirmed,
              ),
            ],
            saved: LastBackups.none,
            device: DeviceBackup.wholeDeviceOnly,
          ),
          onExport: () => exported++,
        ),
      );

      expect(find.text('Nothing has been backed up'), findsOneWidget);

      // The banner carries the fix, so nobody has to hunt for the row below.
      await tester.tap(find.text('Export a backup').first);
      await tester.pumpAndSettle();
      expect(exported, 1);
    });

    testWidgets('no banner once a backup exists', (tester) async {
      await showTall(
        tester,
        SettingsScreen(
          backup: BackupPresenter.build(
            items: [
              TrackedItem(
                id: 'sim',
                name: 'Viettel',
                categoryId: 'PHONE',
                expiresOn: d('2026-09-01'),
                anchorDate: d('2026-09-01'),
                dateSource: DateSource.userConfirmed,
              ),
            ],
            saved: LastBackups(
              fileAt: LocalDateTime(d('2026-08-25'), const LocalTime(9, 30)),
            ),
            device: DeviceBackup.wholeDeviceOnly,
          ),
        ),
      );

      expect(find.byType(AlertBanner), findsNothing);
      expect(find.text('25/08/2026'), findsOneWidget);
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

  group('About', () {
    // The one row nobody comes to Settings to find, so it is last. It is read
    // once, by someone reporting a problem.
    testWidgets('is the last row on Settings', (tester) async {
      var opened = 0;
      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await show(tester, SettingsScreen(onAbout: () => opened++));

      final about = tester.getRect(find.text('About'));
      for (final label in ['All services', 'Widget', 'Import/Export']) {
        expect(
          about.top,
          greaterThan(tester.getRect(find.text(label)).top),
          reason: '$label should come first',
        );
      }

      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    // The version is the reason the screen exists: it is what a person has to
    // read off the app when they are describing a problem to someone else.
    testWidgets('names the build', (tester) async {
      await show(
        tester,
        const AboutScreen(version: '1.2.0', buildNumber: '47'),
      );

      expect(find.text('1.2.0'), findsOneWidget);
      expect(find.text('47'), findsOneWidget);
    });

    // The three rows saying there is no account, no server, and that the list
    // is on this phone have gone. The same three facts are in the lead
    // paragraph and the footnote, and saying them twice on one short screen
    // read as an argument rather than as an answer.
    testWidgets('the card about the list is gone', (tester) async {
      await show(
        tester,
        const AboutScreen(version: '1.2.0', buildNumber: '47'),
      );

      expect(find.text('What it does with your list'), findsNothing);
      expect(find.text('On this phone'), findsNothing);
    });

    // A platform that will not answer gets a dash rather than a crash, and the
    // rest of the screen is still worth reading.
    testWidgets('a version nobody would say still draws the screen', (
      tester,
    ) async {
      await show(tester, const AboutScreen(version: '—', buildNumber: '—'));

      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('About'), findsOneWidget);
    });
  });

  group('A backup channel', () {
    // The two are genuinely different promises -- one the app keeps by itself,
    // one the user keeps by hand -- and the copy is most of what says so.
    testWidgets('iCloud has nothing to press for the copy itself', (
      tester,
    ) async {
      var restored = 0;
      final page = BackupPresenter.cloudPage(
        saved: LastBackups(
          cloudAt: LocalDateTime(d('2026-08-11'), const LocalTime(9, 30)),
        ),
        cloud: const CloudChannel(result: CloudResult(CloudState.saved)),
      );

      await show(
        tester,
        BackupScreen(page: page!, onRestore: () => restored++),
      );

      expect(find.text('iCloud'), findsOneWidget);
      // One row about the copy, and it is the moment. `Saved` over a date said
      // the same thing twice, and could contradict it.
      expect(find.text('Last saved'), findsOneWidget);
      expect(find.text('11/08/2026 at 09:30'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      // The app writes on its own; a button would suggest it does not.
      expect(find.text('Export a backup'), findsNothing);

      await tester.tap(find.text('Restore from iCloud'));
      await tester.pumpAndSettle();
      expect(restored, 1);
    });

    // The label was capped at 55% of the row to leave the value somewhere to
    // sit, and the cap applied even on a row with no value at all. This one
    // has none, so it was cutting the label to make room for nothing and the
    // button reached the screen as `Connect a Google a...`.
    testWidgets('a Drive account is connected from one full-width row', (
      tester,
    ) async {
      // At the width the design is drawn for. The default test surface is
      // wider than any phone, and at that width the capped label still fits,
      // so the bug this test exists for is invisible there.
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      var connected = 0;
      final page = BackupPresenter.cloudPage(
        saved: LastBackups.none,
        cloud: const CloudChannel(
          kind: CloudKind.drive,
          result: CloudResult(CloudState.disconnected),
          needsAccount: true,
        ),
      );

      await show(
        tester,
        BackupScreen(page: page!, onConnect: () => connected++),
      );

      // Measured as a share of the row rather than against the text's own
      // width: the font the test framework substitutes is far wider than the
      // real one, so what fits here says nothing about what fits on a phone.
      // What this pins down is the rule that changed, which is how much of the
      // row the label may occupy when nothing is sharing it.
      final row = tester.getSize(find.byType(DetailRow).first).width;
      final label = tester.getSize(find.text('Connect a Google account')).width;

      expect(
        label / row,
        greaterThan(0.6),
        reason: 'a row with no value must not cap its label at 55%',
      );

      await tester.tap(find.text('Connect a Google account'));
      await tester.pumpAndSettle();
      expect(connected, 1);
    });

    testWidgets('a file is written and read back by hand', (tester) async {
      var exported = 0;
      var restored = 0;
      await show(
        tester,
        BackupScreen(
          page: BackupPresenter.filePage(saved: LastBackups.none),
          onBackUp: () => exported++,
          onRestore: () => restored++,
        ),
      );

      expect(find.text('Never'), findsOneWidget);
      await tester.tap(find.text('Export a backup'));
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();

      expect((exported, restored), (1, 1));
    });

    // Two files on one screen, and they are not versions of each other: the
    // JSON comes back, the CSV does not. Three rows rather than a format
    // chooser, because the choice is between two different jobs.
    testWidgets('the spreadsheet is its own row, under the backup', (
      tester,
    ) async {
      var csv = 0;
      await show(
        tester,
        BackupScreen(
          page: BackupPresenter.filePage(saved: LastBackups.none),
          onBackUp: () {},
          onExportCsv: () => csv++,
          onRestore: () {},
        ),
      );

      expect(
        tester.getRect(find.text('Export as CSV')).top,
        greaterThan(tester.getRect(find.text('Export a backup')).top),
        reason: 'the row someone reaches for after losing a phone comes first',
      );

      await tester.tap(find.text('Export as CSV'));
      await tester.pumpAndSettle();
      expect(csv, 1);
    });

    // A row that writes a file the app cannot read back has to say so, or the
    // reader takes it for a second backup.
    testWidgets('the note says the CSV does not come back', (tester) async {
      await show(
        tester,
        BackupScreen(page: BackupPresenter.filePage(saved: LastBackups.none)),
      );

      expect(find.textContaining('does not come back'), findsOneWidget);
    });

    // iCloud writes its own copy on a timer. A spreadsheet is something the
    // user asks for, and the row belongs where the asking happens.
    testWidgets('iCloud offers no spreadsheet', (tester) async {
      final page = BackupPresenter.cloudPage(
        saved: LastBackups.none,
        cloud: const CloudChannel(result: CloudResult(CloudState.saved)),
      );

      await show(tester, BackupScreen(page: page!));

      expect(find.text('Export as CSV'), findsNothing);
    });

    // Restoring replaces the list and there is nowhere to undo it from. The
    // screen says so under the actions rather than leaving it to the sheet.
    testWidgets('both say a restore replaces rather than merges', (
      tester,
    ) async {
      for (final page in [
        BackupPresenter.cloudPage(
          saved: LastBackups.none,
          cloud: const CloudChannel(result: CloudResult(CloudState.saved)),
        )!,
        BackupPresenter.filePage(saved: LastBackups.none),
      ]) {
        await show(tester, BackupScreen(key: ValueKey(page.title), page: page));
        expect(
          find.textContaining('does not merge'),
          findsOneWidget,
          reason: page.title,
        );
      }
    });

    // Off iOS there is no such page to open.
    testWidgets('no iCloud page where there is no iCloud', (tester) async {
      expect(
        BackupPresenter.cloudPage(
          saved: LastBackups.none,
          cloud: CloudChannel.none,
        ),
        isNull,
      );
    });
  });

  group('Payment sources', () {
    const vcb = PaymentSource(id: 'vcb', name: 'VCB 4412');
    const momo = PaymentSource(id: 'momo', name: 'Momo');

    List<SourceRow> rows({String? defaultId}) => ServicesPresenter.sourceRows(
      [vcb, momo],
      const [],
      defaultId: defaultId,
    );

    // Someone who has just switched cards cannot say so while the app is
    // guessing from a count: the old card goes on winning until enough items
    // have moved. This row is where they say it.
    testWidgets('says which source a new item starts on, and changes it', (
      tester,
    ) async {
      String? chosen;
      await show(
        tester,
        SourcesScreen(
          rows: rows(defaultId: 'vcb'),
          onSetDefault: (id) => chosen = id,
        ),
      );

      expect(find.text('Starts on'), findsOneWidget);
      expect(find.text('VCB 4412'), findsWidgets);

      await tester.tap(find.text('Starts on'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Momo').last);
      await tester.pumpAndSettle();

      expect(chosen, 'momo');
    });

    // The list says it too. Scanning three cards should not mean reading a row
    // further up to work out which one a new item lands on.
    testWidgets('the list marks the default row', (tester) async {
      await show(
        tester,
        SourcesScreen(
          rows: rows(defaultId: 'momo'),
          onSetDefault: (_) {},
        ),
      );

      expect(find.textContaining('Default · Not used yet'), findsOneWidget);
    });

    // One source is not a choice, and a row offering to pick between one thing
    // is a control that cannot do anything.
    testWidgets('no picker while there is only one source', (tester) async {
      await show(
        tester,
        SourcesScreen(
          rows: ServicesPresenter.sourceRows([vcb], const [], defaultId: 'vcb'),
          onSetDefault: (_) {},
        ),
      );

      expect(find.text('Starts on'), findsNothing);
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

  // `Cancel this subscription` wrote to the database and popped, with no word
  // about what it did. Two of the things it does are visible nowhere else in
  // the app: how many reminders it drops, and the date the item goes on being
  // charged until.
  group('Cancel confirmation', () {
    testWidgets('names the reminders it drops and the date it runs to', (
      tester,
    ) async {
      await show(
        tester,
        CancelAsk(
          name: 'Netflix',
          usableUntil: d('2026-09-05'),
          reminderCount: 4,
        ),
      );

      expect(find.text('Cancel Netflix?'), findsOneWidget);
      expect(find.text('4 pending reminders'), findsOneWidget);
      expect(find.textContaining('05/09/2026'), findsOneWidget);
    });

    // The item is not deleted and the reader has a delete button two taps
    // away, so the sheet has to draw the line between them.
    testWidgets('says what it does not take', (tester) async {
      await show(
        tester,
        CancelAsk(name: 'Netflix', usableUntil: d('2026-09-05')),
      );

      expect(find.text('Recorded payments, dates and amounts'), findsOneWidget);
    });

    // Saying "usable until 20/08" on the 28th describes a window that shut
    // last week. The item closes on the next sweep instead.
    testWidgets('does not promise a window that has already shut', (
      tester,
    ) async {
      await show(
        tester,
        CancelAsk(
          name: 'Netflix',
          usableUntil: d('2026-08-01'),
          alreadyLapsed: true,
        ),
      );

      expect(find.textContaining('01/08/2026'), findsNothing);
      expect(find.text('That date has gone, so it closes now'), findsOneWidget);
      // The label follows the value. `Usable until` over `That date has gone`
      // is a row arguing with itself.
      expect(find.text('Usable until'), findsNothing);
      expect(find.text('The paid-up period'), findsOneWidget);
    });

    // Shortening a counted plan touches no reminders and can be undone by
    // editing the count, so it is not dressed in the same ink. Red where
    // nothing is at risk teaches people to read past red.
    testWidgets('a counted plan is a different sheet', (tester) async {
      await show(
        tester,
        const CancelAsk(
          name: 'Course',
          position: Instalments(index: 4, total: 6),
        ),
      );

      expect(find.text('Stop after payment 4?'), findsOneWidget);
      expect(find.text('4 payments instead of 6'), findsOneWidget);
      expect(find.text('They run on to the last payment'), findsOneWidget);
      expect(
        tester.widget<QuietButton>(find.byType(QuietButton)).danger,
        isFalse,
      );
    });

    testWidgets('the filled button is the one that changes nothing', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;
      await show(
        tester,
        CancelAsk(
          name: 'Netflix',
          usableUntil: d('2026-09-05'),
          onConfirm: () => confirmed++,
          onCancel: () => cancelled++,
        ),
      );

      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect((confirmed, cancelled), (0, 1));

      await tester.tap(find.text('Cancel it'));
      await tester.pumpAndSettle();
      expect((confirmed, cancelled), (1, 1));
    });
  });

  // The row is the only thing on Upcoming that can say a subscription is
  // cancelled. Its reminders are gone, and a row with no reminders looks
  // exactly like every other quiet row.
  group('the cancelled badge', () {
    testWidgets('marks a cancelled row and leaves the rest alone', (
      tester,
    ) async {
      await show(
        tester,
        Column(
          children: [
            ItemRow(
              name: 'Netflix',
              when: '5d',
              date: '05/09',
              cancelled: true,
            ),
            ItemRow(name: 'Spotify', when: '9d', date: '09/09'),
          ],
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
    });

    // One slot, and cancelled takes it. Two badges after the name leave the
    // name about four characters, on the line the row exists to show.
    testWidgets('takes the slot from the trial badge', (tester) async {
      await show(
        tester,
        ItemRow(
          name: 'Netflix',
          when: '5d',
          date: '05/09',
          trial: true,
          cancelled: true,
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('FREE TRIAL'), findsNothing);
    });

    // Accent is for news the reader wants. This row is on screen only because
    // it has not run out yet, and a list whose ended items are the brightest
    // is a list read backwards.
    testWidgets('does not use the accent the trial badge uses', (tester) async {
      await show(
        tester,
        Column(
          children: [
            ItemRow(
              name: 'Netflix',
              when: '5d',
              date: '05/09',
              cancelled: true,
            ),
            ItemRow(name: 'Spotify', when: '9d', date: '09/09', trial: true),
          ],
        ),
      );

      Color inkOf(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;

      expect(inkOf('FREE TRIAL'), SubdockColors.accent);
      expect(inkOf('CANCELLED'), SubdockColors.inkMuted);
    });
  });
}
