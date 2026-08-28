// Throwaway screenshot harness. Renders the real app at the design frame so
// its screens can be compared against design/handoff/screens/*.png.
//
//     flutter test tool/shots/capture.dart --update-goldens
//
// Writes to /private/tmp/.../scratchpad/shots. Delete this file when done.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/bundled_data.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/cloud_store.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/data/currency_store.dart';
import 'package:subdock/domain/currency_picks.dart';
import 'package:subdock/data/locale_store.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/ui/screens/onboarding/onboarding_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/widgets/glass.dart';

const String outDir =
    '/private/tmp/claude-501/-Volumes-DATA-dev-projects-subcription-reminder/'
    'a1133711-480f-4af3-9258-1de30f37d192/scratchpad/shots';

void main() {
  setUpAll(() async {
    Directory(outDir).createSync(recursive: true);

    final families = {
      SubdockText.family: [
        'assets/fonts/BeVietnamPro-Regular.ttf',
        'assets/fonts/BeVietnamPro-Medium.ttf',
        'assets/fonts/BeVietnamPro-SemiBold.ttf',
        'assets/fonts/BeVietnamPro-Bold.ttf',
      ],
      SubdockText.mono: [
        'assets/fonts/IBMPlexMono-Regular.ttf',
        'assets/fonts/IBMPlexMono-Medium.ttf',
        'assets/fonts/IBMPlexMono-SemiBold.ttf',
      ],
    };
    for (final entry in families.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(
          File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      }
      await loader.load();
    }
  });

  testWidgets('capture every screen', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // `SHOTS_DARK=1` renders the same nine screens in the dark variant, into
    // `out/dark_*.png`. The app is left on ThemeChoice.system, so telling the
    // fake platform it is dark is the whole switch.
    final dark = Platform.environment['SHOTS_DARK'] == '1';
    if (dark) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    // `SHOTS_VI=1` renders the same screens with the interface in Vietnamese,
    // into `out/vi_*.png`. The language is a stored choice, so it is written
    // to the settings row before the app is pumped rather than poked into the
    // widget tree afterwards.
    final vietnamese = Platform.environment['SHOTS_VI'] == '1';

    final prefix = '${vietnamese ? 'vi_' : ''}${dark ? 'dark_' : ''}';

    final db = SubdockDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    if (vietnamese) await LocaleStore(db).save(AppLocale.vi);
    // Written explicitly, in both runs. With nothing stored the app falls back
    // to a guess off the host's region, which would make every figure in these
    // screenshots depend on the machine that took them.
    await CurrencyStore(db).save(CurrencyPicks.one('VND'));
    final repository = ItemRepository(db);
    final settings = SettingsStore(db);

    final catalog = ServiceCatalog(
      BundledData.parseCatalog(File('assets/services.json').readAsStringSync())
          .entries,
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final today = LocalDate.today();
    LocalDate plus(int d) => today.plusDays(d);

    Future<void> put(
      String id,
      String name, {
      required LocalDate expires,
      String categoryId = 'STREAMING',
      int? amountMinor,
      String? currency = 'VND',
      Cycle? cycle = Cycle.monthly,
      bool inTrial = false,
      String? sourceId,
      String? note,
    }) => repository.upsert(
      TrackedItem(
        id: id,
        name: name,
        categoryId: categoryId,
        expiresOn: expires,
        anchorDate: expires,
        cycle: cycle,
        amountMinor: amountMinor,
        currency: amountMinor == null ? null : currency,
        inTrial: inTrial,
        paymentSourceId: sourceId,
        note: note,
      ),
      now,
    );

    await repository.upsertSource(
      const PaymentSource(id: 'vcb', name: 'VCB 4412'),
      now,
    );
    await repository.upsertSource(
      const PaymentSource(id: 'tcb', name: 'Techcombank'),
      now,
    );

    await put(
      'viettel',
      'Viettel 0912 345 678',
      expires: plus(-4),
      categoryId: 'PHONE',
      cycle: null,
    );
    await put(
      'claude',
      'Claude Pro',
      expires: plus(2),
      amountMinor: 2000,
      currency: 'USD',
      inTrial: true,
      note: 'Ask about the education discount before the trial ends.',
    );
    await put(
      'spotify',
      'Spotify Individual',
      expires: plus(3),
      amountMinor: 59000,
      sourceId: 'tcb',
    );
    await put(
      'electricity',
      'Electricity bill',
      expires: plus(5),
      categoryId: 'UTILITIES',
      amountMinor: 842000,
      sourceId: 'tcb',
    );
    await put(
      'youtube',
      'YouTube Premium',
      expires: plus(6),
      amountMinor: 69000,
      sourceId: 'vcb',
    );
    await put(
      'netflix',
      'Netflix Premium',
      expires: plus(7),
      amountMinor: 260000,
      sourceId: 'vcb',
    );
    await put(
      'icloud',
      'iCloud+ 200GB',
      expires: plus(8),
      amountMinor: 89000,
      sourceId: 'vcb',
    );
    await put(
      'adobe',
      'Adobe Creative Cloud',
      expires: plus(8),
      amountMinor: 5290000,
      cycle: Cycle.yearly,
      sourceId: 'vcb',
    );
    await put(
      'passport',
      'Passport',
      expires: plus(220),
      categoryId: 'DOCUMENTS',
      cycle: null,
    );

    // Six months of closed occurrences, so the chart and the history filters
    // have something to draw.
    var seq = 0;
    for (final back in [0, 1, 2, 3, 4, 5]) {
      for (final (id, amount) in [('netflix', 260000), ('youtube', 69000)]) {
        final due = LocalDate(
          today.month - back < 1 ? today.year - 1 : today.year,
          (today.month - back - 1) % 12 + 1,
          10,
        );
        await repository.recordHandled(
          HandledEvent(
            id: 'h${seq++}',
            itemId: id,
            handledAtEpochSeconds:
                DateTime(
                  due.year,
                  due.month,
                  due.day + (back.isEven ? 0 : 3),
                ).millisecondsSinceEpoch ~/
                1000,
            forDueDate: due,
            baseAmountMinor: amount * (back + 1),
          ),
        );
      }
    }

    // `NotificationScheduler` reaches for a platform implementation that is
    // never registered under `flutter_test`, so `_refreshPermission` throws a
    // LateInitializationError out of `initState`. The framework catches it and
    // the tree still builds, which is why the screenshots are correct either
    // way -- but an uncollected exception fails the run. Draining it keeps the
    // harness honest about what it is: a renderer, not a test of the app.
    void drain() {
      while (tester.takeException() != null) {}
    }

    await tester.pumpWidget(
      SubdockApp(
        repository: repository,
        settings: settings,
        filters: FilterStore(db),
        themes: ThemeStore(db),
        locales: LocaleStore(db),
        currencies: CurrencyStore(db),
        scheduler: _StubScheduler(),
        catalog: catalog,
        backups: BackupStore(db, repository, settings),
        files: BackupFiles(),
        // Off in tests: the host has no iCloud container, and a timer
        // uploading in the background is not what any of these are about.
        cloud: const NoCloud(),
        clouds: CloudStore(db),
      ),
    );
    await tester.pumpAndSettle();
    drain();

    /// One screenful, then the whole scroll extent under it.
    ///
    /// Two images, not one, and the second is the point: comparing only the
    /// first screenful against a hand-off screenshot compares the two things
    /// that are easiest to get right. A section that arrives collapsed, a
    /// group in the wrong order, a block the design does not have -- all of it
    /// lives below the fold and none of it shows in a single frame.
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      drain();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/$prefix$name.png'),
      );

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isEmpty) return;

      // Tall enough to hold anything this app scrolls, so the second image is
      // the screen entire rather than a second arbitrary window onto it.
      tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
      await tester.pumpAndSettle();
      drain();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/$prefix${name}_full.png'),
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      await tester.pumpAndSettle();
      drain();
    }

    Future<void> tapText(String label) async {
      final target = find.text(label).first;
      // Scroll it into view first: half of these live below the fold, and a
      // finder that resolves is not the same as a target that can be tapped.
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      await tester.tap(target);
      await tester.pumpAndSettle();
      drain();
    }

    Future<void> pop() async {
      final ctx = tester.element(find.byType(Navigator).first);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
    }

    await shot('upcoming');

    // The calendar layout: the month grid, and the day open under it. Same
    // items, same filter, laid out by date instead of by distance.
    await tapText(S.t.layoutCalendar);
    await shot('upcoming-calendar');
    await tapText(S.t.layoutList);

    // The filter, in both of its states: the sheet open over the list, and the
    // list narrowed with the summary row under the title.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    drain();
    await tapText(S.t.categoryLabel('PHONE')!);
    await shot('upcoming-filter-sheet');
    await pop();
    await shot('upcoming-filtered');

    // And the third empty state: filtered down to nothing, which must not look
    // like the app having nothing in it.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    drain();
    await tapText(S.t.freeTrials);
    await pop();
    await shot('upcoming-filter-empty');
    await tapText(S.t.clearFilters);

    await tapText(S.t.spendingTitle);
    await shot('money');
    // A month other than the one the user is in. The whole card follows the
    // column, so this is the shot that shows whether it really does.
    await tapText('9');
    await shot('money-picked');
    await tapText('8');
    // The year view too. It is the densest card in the app -- a headline, a
    // per-currency sum and a per-kind sum, all of the same money -- and it is
    // where an unlabelled figure reads as a number the app made up.
    await tapText(S.t.spanYear);
    await shot('money-year');
    await tapText(S.t.spanMonth);

    await tapText(S.t.savingsTitle);
    await shot('savings');

    await tapText(S.t.settingsTitle);
    await shot('settings');

    await tapText(S.t.allServices);
    await shot('services');
    await pop();

    await tapText(S.t.rowReminders);
    await shot('reminders');
    await pop();

    // The backup channel that exists off iOS. iCloud is unsupported in this
    // harness, so its row is absent, which is the correct Android screen.
    await tapText(S.t.rowFile);
    await shot('backup-file');
    await pop();

    await tapText(S.t.rowAbout);
    await shot('about');
    await pop();

    await tapText(S.t.rowHistory);
    await shot('history');
    await pop();

    await tapText(S.t.upcomingTitle);
    await tapText('Netflix Premium');
    await shot('detail');
    await tapText(S.t.edit);
    await shot('edit');
    await pop();
    await pop();

    // The same screen on an item in a free trial. Its own shot because the
    // trial is a row of "What happens next" now rather than a card above it,
    // and that row is the only thing on the screen saying today is free.
    await tapText('Claude Pro');
    await shot('detail-trial');
    await pop();

    // The add form, on a service with plans, with Forever unticked so the
    // "when does it stop" card is on screen.
    await tester.tap(find.byTooltip(S.t.addAnItem));
    await tester.pumpAndSettle();
    drain();
    await shot('add-pick');
    // A service the shipped catalogue prices, so the plan grid is on screen
    // too. `Enter manually` is below the fold and a lazy list has not built
    // it, so a finder cannot reach it.
    await tapText('Disney+');
    await tapText(S.t.repeatsForever);
    await shot('add-details');
    await tester.dragUntilVisible(
      find.text(S.t.sourceNew),
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tapText(S.t.sourceNew);
    await shot('add-source');

    // Onboarding, last, and pumped on its own rather than reached through the
    // app: it only appears on a database with nothing in it, and everything
    // above needs a seeded one. Reduce Motion is on for the same reason the
    // widget tests turn it on -- the marquee and the arriving notifications
    // never stop, so `pumpAndSettle` would never return.
    // Three frames rather than two: the setup page has a shape it only takes
    // once a second currency is on it -- two cards, and the row of chips that
    // asks which of them the totals speak. Capturing only the one-currency
    // state hides the state the design is actually specified in.
    for (final (name, page, picks) in [
      ('onboarding', 0, CurrencyPicks.one('VND')),
      ('onboarding-setup', 1, CurrencyPicks.one('VND')),
      ('onboarding-setup-two', 1, CurrencyPicks(['VND', 'USD'], base: 'VND')),
    ]) {
      await tester.pumpWidget(
        SubdockTheme(
          // Follows `SHOTS_DARK` like every other frame. Hard-coded light
          // here before, so the dark run wrote a light onboarding into a file
          // named `dark_`, which is worse than not taking the shot at all.
          palette: dark ? SubdockPalette.dark : SubdockPalette.light,
          currency: picks.base,
          currencies: picks.codes,
          locale: vietnamese ? AppLocale.vi : AppLocale.en,
          child: MaterialApp(
            theme: buildSubdockTheme(),
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: GlassBackground(
                child: Scaffold(
                  backgroundColor: const Color(0x00000000),
                  body: SafeArea(
                    child: OnboardingScreen(
                      key: ValueKey(name),
                      picks: picks,
                      locale: vietnamese ? AppLocale.vi : AppLocale.en,
                      onCurrency: (_) {},
                      onLocale: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page == 1) {
        await tester.tap(find.text(vietnamese ? 'Tiếp tục' : 'Continue'));
        await tester.pumpAndSettle();
      }
      drain();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/$prefix$name.png'),
      );
    }

    // Tear the tree down inside the test rather than in a tearDown callback.
    // Disposing `HomePage` cancels its drift subscriptions, and drift closes a
    // query stream through a zero-duration timer; left to run after the test
    // body it trips the "a Timer is still pending" invariant. Unmounting and
    // pumping here lets that timer fire while there is still a clock to fire
    // it on.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// A scheduler that answers without touching the platform plugin.
///
/// `flutter_local_notifications` registers its platform implementation from
/// native code, which never runs under `flutter_test`, so the real scheduler
/// throws a `LateInitializationError` out of `HomePage.initState` and leaves a
/// pending timer behind. Nothing in these screenshots is about notifications,
/// so the honest stand-in is one that reports the permission as not granted --
/// which is also the state the hand-off draws, with the "Notifications are off"
/// banner on Upcoming.
class _StubScheduler implements NotificationScheduler {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool?> hasExactTiming() async => null;

  @override
  Future<void> apply(NotificationPlan plan) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
