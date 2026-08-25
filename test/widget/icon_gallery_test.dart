import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subdock/ui/widgets/icon_gallery.dart';
import 'package:subdock/ui/widgets/primitives.dart';

/// The sheet behind the tile next to the name field.
///
/// The marks themselves are covered by the golden sheet; what is tested here
/// is the part a user can get wrong -- searching for a service and being told
/// the app has nothing, when the app has it under another name.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? selected,
    void Function(String)? onPick,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IconGallery(selected: selected, onPick: onPick ?? (_) {}),
      ),
    ),
  );

  /// The keys of every choice currently drawn, in the order they are drawn.
  List<String> shown(WidgetTester tester) => tester
      .widgetList<ServiceTile>(find.byType(ServiceTile))
      .map((tile) => tile.iconName)
      .whereType<String>()
      .toList();

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
  }

  testWidgets('opens on the whole set, shapes before logos', (tester) async {
    await pump(tester);

    final keys = shown(tester);
    expect(keys, contains('netflix'));
    expect(keys, contains('power'));
    expect(
      keys.indexOf('power'),
      lessThan(keys.indexOf('netflix')),
      reason: 'the shapes are what a manual pick is usually for',
    );
  });

  testWidgets('the search narrows to what was typed', (tester) async {
    await pump(tester);
    await search(tester, 'netflix');

    expect(shown(tester), ['netflix']);
    expect(find.text('Categories'), findsNothing);
  });

  // The detector already knows these names. A search that did not would be
  // telling the user the app has no Disney icon while the name field is
  // quietly drawing one.
  testWidgets('a service is found under the name it is sold as', (
    tester,
  ) async {
    await pump(tester);

    await search(tester, 'disney');
    expect(shown(tester), ['streaming']);

    await search(tester, 'max');
    expect(shown(tester), contains('hbo'));
  });

  testWidgets('a search with no answer says so and offers the way back', (
    tester,
  ) async {
    await pump(tester);
    await search(tester, 'zzzz');

    expect(shown(tester), isEmpty);
    expect(find.text('No icon called "zzzz"'), findsOneWidget);

    await search(tester, '');
    expect(shown(tester), isNotEmpty);
  });

  testWidgets('picking hands back the key that was tapped', (tester) async {
    final picked = <String>[];
    await pump(tester, onPick: picked.add);
    await search(tester, 'spotify');

    await tester.tap(find.byType(ServiceTile).first);
    expect(picked, ['spotify']);
  });

  // The tile is the cell now. A second card around it would take the width
  // back off the mark, which is the only thing in the sheet worth looking at.
  testWidgets('the selected mark is ringed without resizing the cell', (
    tester,
  ) async {
    await pump(tester, selected: 'netflix');
    await search(tester, 'netflix');
    final ringed = tester.getSize(find.byType(ServiceTile).first);

    await pump(tester);
    await search(tester, 'netflix');
    expect(tester.getSize(find.byType(ServiceTile).first), ringed);
  });
}
