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
import 'package:subdock/ui/screens/backup_screen.dart';
import 'package:subdock/ui/screens/settings_screen.dart';
import 'package:subdock/ui/screens/sources_screen.dart';
import 'package:subdock/ui/services_presenter.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/ui/backup_presenter.dart';
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

    // A chevron promises a picker. Currency, language and the widget row have
    // none, so none of them gets one.
    testWidgets('value rows do not pretend to lead anywhere', (tester) async {
      await show(tester, const SettingsScreen());

      expect(find.text('VND'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      // Four destinations, About, and the one backup channel that exists
      // without a cloud behind it.
      expect(find.text('›'), findsNWidgets(6));
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
            saved: LastBackups(file: d('2026-08-11')),
            device: DeviceBackup.wholeDeviceOnly,
            cloud: const CloudResult(CloudState.saved),
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
      await tester.tap(find.text('File'));
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
            saved: LastBackups(cloud: d('2026-06-25')),
            device: DeviceBackup.wholeDeviceOnly,
            cloud: const CloudResult(CloudState.signedOut),
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
      expect(find.text('File'), findsOneWidget);
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
            saved: LastBackups(file: d('2026-08-25')),
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

  group('A backup channel', () {
    // The two are genuinely different promises -- one the app keeps by itself,
    // one the user keeps by hand -- and the copy is most of what says so.
    testWidgets('iCloud has nothing to press for the copy itself', (
      tester,
    ) async {
      var restored = 0;
      final page = BackupPresenter.cloudPage(
        saved: LastBackups(cloud: d('2026-08-11')),
        cloud: const CloudResult(CloudState.saved),
      );

      await show(
        tester,
        BackupScreen(page: page!, onRestore: () => restored++),
      );

      expect(find.text('iCloud'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('11/08/2026'), findsOneWidget);
      // The app writes on its own; a button would suggest it does not.
      expect(find.text('Export a backup'), findsNothing);

      await tester.tap(find.text('Restore from iCloud'));
      await tester.pumpAndSettle();
      expect(restored, 1);
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

    // Restoring replaces the list and there is nowhere to undo it from. The
    // screen says so under the actions rather than leaving it to the sheet.
    testWidgets('both say a restore replaces rather than merges', (
      tester,
    ) async {
      for (final page in [
        BackupPresenter.cloudPage(
          saved: LastBackups.none,
          cloud: const CloudResult(CloudState.saved),
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
          cloud: CloudResult.unsupported,
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
}
