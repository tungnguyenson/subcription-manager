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
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/notification_planner.dart';
import 'package:subdock/platform/notification_scheduler.dart';
import 'package:subdock/ui/theme.dart';

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

    final db = SubdockDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
        scheduler: _StubScheduler(),
        catalog: catalog,
        backups: BackupStore(db, repository, settings),
        files: BackupFiles(),
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
        matchesGoldenFile('out/$name.png'),
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
        matchesGoldenFile('out/${name}_full.png'),
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

    // The filter, in both of its states: the sheet open over the list, and the
    // list narrowed with the summary row under the title.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    drain();
    await tapText('Mobile and SIM');
    await shot('upcoming-filter-sheet');
    await pop();
    await shot('upcoming-filtered');

    // And the third empty state: filtered down to nothing, which must not look
    // like the app having nothing in it.
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();
    drain();
    await tapText('Free trials');
    await pop();
    await shot('upcoming-filter-empty');
    await tapText('Clear filters');

    await tapText('Spending');
    await shot('money');
    // A month other than the one the user is in. The whole card follows the
    // column, so this is the shot that shows whether it really does.
    await tapText('9');
    await shot('money-picked');
    await tapText('8');
    // The year view too. It is the densest card in the app -- a headline, a
    // per-currency sum and a per-kind sum, all of the same money -- and it is
    // where an unlabelled figure reads as a number the app made up.
    await tapText('Year');
    await shot('money-year');
    await tapText('Month');

    await tapText('Savings');
    await shot('savings');

    await tapText('Settings');
    await shot('settings');

    await tapText('All services');
    await shot('services');
    await pop();

    await tapText('Reminders');
    await shot('reminders');
    await pop();

    await tapText('History');
    await shot('history');
    await pop();

    await tapText('Upcoming');
    await tapText('Netflix Premium');
    await shot('detail');
    await tapText('Edit');
    await shot('edit');
    await pop();

    // The add form, on a service with plans, with Forever unticked so the
    // "when does it stop" card is on screen.
    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();
    drain();
    await shot('add-pick');
    // A service the shipped catalogue prices, so the plan grid is on screen
    // too. `Enter manually` is below the fold and a lazy list has not built
    // it, so a finder cannot reach it.
    await tapText('Disney+');
    await tapText('Repeats forever');
    await shot('add-details');
    await tester.dragUntilVisible(
      find.text('New'),
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tapText('New');
    await shot('add-source');

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
