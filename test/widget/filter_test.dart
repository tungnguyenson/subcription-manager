import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/domain/upcoming_filter.dart';
import 'package:subdock/ui/filter_presenter.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/ui/theme.dart';
import 'package:subdock/ui/upcoming_presenter.dart';
import 'package:subdock/ui/widgets/empty_placard.dart';
import 'package:subdock/ui/widgets/filter_sheet.dart';
import 'package:subdock/ui/widgets/item_row.dart';

void main() {
  final today = LocalDate.parse('2026-08-15');
  LocalDate d(String iso) => LocalDate.parse(iso);

  final book = CategoryBook([
    const Category(id: 'PHONE', label: 'Phone', sortOrder: 0),
    const Category(id: 'STREAMING', label: 'Streaming', sortOrder: 1),
  ]);

  TrackedItem item(
    String name, {
    required String expiresOn,
    String categoryId = 'STREAMING',
    Cycle? cycle = Cycle.monthly,
    String? paymentSourceId,
    bool paused = false,
  }) => TrackedItem(
    id: name,
    name: name,
    categoryId: categoryId,
    expiresOn: d(expiresOn),
    anchorDate: d(expiresOn),
    cycle: cycle,
    paymentSourceId: paymentSourceId,
    paused: paused,
  );

  final items = [
    item('Netflix', expiresOn: '2026-08-18'),
    item('Viettel', expiresOn: '2026-08-19', categoryId: 'PHONE'),
    item('Spotify', expiresOn: '2026-08-20', paused: true),
  ];

  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSubdockTheme(),
        home: Scaffold(backgroundColor: SubdockColors.canvas, body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The screen wired to a filter the way [HomePage] wires it, so a test can
  /// tap a chip and see the list underneath change.
  Widget screen(UpcomingFilter filter, {void Function(UpcomingFilter)? onSet}) {
    final view = UpcomingPresenter.build(items, today, filter: filter);
    final options = FilterPresenter.options(items, book);
    return UpcomingScreen(
      view: view,
      filterSummary: filter.isEmpty
          ? null
          : FilterPresenter.summary(
              filter,
              options,
              shown: view.shown,
              total: view.total,
            ),
      onOpenServices: () {},
      onOpenFilter: () {},
      onClearFilter: () => onSet?.call(UpcomingFilter.none),
    );
  }

  group('the header', () {
    testWidgets('the filter button sits beside the services link', (
      tester,
    ) async {
      await show(tester, screen(UpcomingFilter.none));
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.text('All services'), findsOneWidget);
    });

    // A list that is quietly short is indistinguishable from an app that has
    // lost things, so something on the header has to say the filter is on.
    testWidgets('the button fills with the accent while anything is on', (
      tester,
    ) async {
      await show(tester, screen(UpcomingFilter.none));
      expect(_buttonFill(tester), isNot(SubdockColors.accent));

      await show(tester, screen(const UpcomingFilter(categoryIds: {'PHONE'})));
      expect(_buttonFill(tester), SubdockColors.accent);
    });

    testWidgets('no summary row until something is filtered', (tester) async {
      await show(tester, screen(UpcomingFilter.none));
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('the summary names the counts and the conditions', (
      tester,
    ) async {
      await show(tester, screen(const UpcomingFilter(categoryIds: {'PHONE'})));
      expect(find.text('1 of 2 items · Phone'), findsOneWidget);
    });

    testWidgets('Clear drops every condition', (tester) async {
      UpcomingFilter? cleared;
      await show(
        tester,
        screen(
          const UpcomingFilter(categoryIds: {'PHONE'}),
          onSet: (next) => cleared = next,
        ),
      );

      await tester.tap(find.text('Clear'));
      expect(cleared, UpcomingFilter.none);
    });
  });

  group('the list', () {
    testWidgets('a shelf chip leaves only that shelf on screen', (
      tester,
    ) async {
      await show(tester, screen(const UpcomingFilter(categoryIds: {'PHONE'})));

      expect(find.text('Viettel'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
      // The sections keep their own names. Filtering narrows the list, it does
      // not restructure it.
      expect(find.textContaining('NEXT 7 DAYS'), findsOneWidget);
    });

    testWidgets('Reminders off is the one way back to a switched-off item', (
      tester,
    ) async {
      await show(tester, screen(const UpcomingFilter(mutedOnly: true)));

      expect(find.text('Spotify'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);
    });

    // Same emptiness, opposite cause, opposite way out: undo, not add.
    testWidgets('an empty result is not the untracked empty state', (
      tester,
    ) async {
      UpcomingFilter? cleared;
      await show(
        tester,
        screen(
          const UpcomingFilter(categoryIds: {'PHONE'}, mutedOnly: true),
          onSet: (next) => cleared = next,
        ),
      );

      expect(find.text('Nothing matches these filters'), findsOneWidget);
      expect(find.text('Nothing tracked yet'), findsNothing);
      expect(find.byType(EmptyPlacard), findsNothing);
      expect(find.byType(ItemRow), findsNothing);

      await tester.tap(find.text('Clear filters'));
      expect(cleared, UpcomingFilter.none);
    });

    testWidgets('an untracked app still gets its own empty state', (
      tester,
    ) async {
      await show(
        tester,
        UpcomingScreen(
          view: UpcomingPresenter.build(const [], today),
          onOpenFilter: () {},
        ),
      );

      expect(find.text('Nothing tracked yet'), findsOneWidget);
      expect(find.text('Nothing matches these filters'), findsNothing);
    });
  });

  group('the sheet', () {
    /// Opens the sheet over a bare page and reports every filter it emits.
    Future<List<UpcomingFilter>> open(
      WidgetTester tester, {
      UpcomingFilter filter = const UpcomingFilter(),
    }) async {
      final emitted = <UpcomingFilter>[];
      var current = filter;

      await show(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => FilterSheet.show(
              context,
              filter: current,
              options: FilterPresenter.options(items, book),
              countFor: (f) => f.apply(items, today).length,
              onChanged: (f) {
                current = f;
                emitted.add(f);
              },
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return emitted;
    }

    testWidgets('every group is offered, built from the real data', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('BILLING CYCLE'), findsOneWidget);
      expect(find.text('PAYS FROM'), findsOneWidget);
      expect(find.text('ONLY SHOW'), findsOneWidget);

      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Streaming'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('No source'), findsOneWidget);
    });

    // The whole interaction design: no Apply step, because the answer is right
    // there under the sheet if the chips are allowed to act.
    testWidgets('a chip changes the filter on the tap, not on close', (
      tester,
    ) async {
      final emitted = await open(tester);

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      expect(emitted, [
        const UpcomingFilter(categoryIds: {'PHONE'}),
      ]);
      expect(find.text('open'), findsOneWidget, reason: 'sheet stays open');
    });

    testWidgets('the button counts what closing will reveal', (tester) async {
      await open(tester);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('Show 1 item'), findsOneWidget);

      await tester.tap(find.text('Streaming'));
      await tester.pumpAndSettle();
      expect(find.text('Show 2 items'), findsOneWidget);
    });

    testWidgets('Clear all resets without closing the sheet', (tester) async {
      final emitted = await open(
        tester,
        filter: const UpcomingFilter(categoryIds: {'PHONE'}, trialOnly: true),
      );

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(emitted.last, UpcomingFilter.none);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('the primary button closes it', (tester) async {
      await open(tester);
      // The sheet scrolls inside itself, and the 800x600 test surface is
      // shorter than the phone the design is drawn for.
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('TYPE'), findsNothing);
    });
  });
}

/// The fill of the round filter button, whatever its state.
Color? _buttonFill(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .ancestor(
          of: find.byIcon(Icons.filter_list_rounded),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}
