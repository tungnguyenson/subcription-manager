import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/services_screen.dart';
import 'package:subdock/ui/screens/sources_screen.dart';
import 'package:subdock/i18n.dart';

/// The two list screens that answer "what is in here", worded.
///
/// Both are pure and both take the whole item list, because both say something
/// about the *relationship* between two tables — which services are switched
/// off, and which items point at which source. Neither answer can be assembled
/// a row at a time.
abstract final class ServicesPresenter {
  /// Every tracked service, on the shelves the user keeps.
  ///
  /// One grouping, and it is the shelf the item already carries. This screen is
  /// read to answer "do I still have a music subscription", which a heading
  /// that says *Subscription* over forty rows cannot answer -- and which is why
  /// the old five-value classification and the catalogue's own twenty-one-way
  /// grouping were folded into one thing the user owns.
  ///
  /// Empty shelves are left out, so the list is what the user has rather than
  /// what they could have. Order comes from [Category.sortOrder], which they
  /// set: nothing here jumps the queue on its own, not even the shelf the SIMs
  /// are on. A shelf the app promotes by name is a shelf the user cannot demote
  /// when the app guessed wrong about them.
  ///
  /// Inactive items are left out. They are not paused, they are finished — the
  /// last instalment of a course, a cancelled plan whose period has run out --
  /// and a switch on one would promise to bring it back, which it cannot.
  static List<ServiceGroup> groups(
    List<TrackedItem> items,
    CategoryBook categories,
    LocalDate today,
  ) {
    final byCategory = <String, List<ServiceToggle>>{};

    for (final item in items) {
      if (item.state == ItemState.inactive) continue;

      byCategory
          .putIfAbsent(item.categoryId, () => [])
          .add(
            ServiceToggle(
              id: item.id,
              name: item.name,
              subtitle: _subtitle(item, today),
              iconName: item.iconName,
              on: !item.paused,
              cancelled: item.state == ItemState.cancelledStillActive,
            ),
          );
    }

    for (final rows in byCategory.values) {
      rows.sort((a, b) => a.name.compareTo(b.name));
    }

    return [
      for (final category in categories.all)
        if (byCategory[category.id] case final rows?)
          ServiceGroup(label: category.displayLabel, rows: rows),

      // Anything pointing at a shelf that is not in the book. The foreign key
      // is supposed to make this impossible; it is drawn rather than dropped
      // because a service missing from this list is a service the user thinks
      // they are not being charged for.
      for (final id in byCategory.keys.where((id) => !categories.contains(id)))
        ServiceGroup(
          label: categories.fallback.displayLabel,
          rows: byCategory[id]!,
        ),
    ];
  }

  /// `Next 22/08 · 260,000 ₫`, or `Off · no reminders`.
  ///
  /// The off state replaces the whole line rather than appending to it. A
  /// paused item's next date is not a fact about the future any more — nothing
  /// will happen on it — so showing it beside the word "off" would be showing
  /// two contradictory things on one line.
  static String _subtitle(TrackedItem item, LocalDate today) {
    if (item.paused) return S.t.servicesOff;

    final parts = <String>[
      if (item.isTrialOn(today))
        S.t.servicesTrialEnds(MoneyFormat.shortDate(item.expiresOn))
      else
        S.t.servicesNext(MoneyFormat.shortDate(item.expiresOn)),
      if (item.money case final money?) MoneyFormat.full(money),
    ];
    return parts.join(S.t.bullet);
  }

  /// Each source, with what is pointing at it.
  ///
  /// The usage line names the single item when there is only one, and that is
  /// the point of it: Remove is destructive-looking and the user has to be able
  /// to see what it costs them before tapping. "1 item" makes them guess;
  /// "Netflix Premium" does not.
  static List<SourceRow> sourceRows(
    List<PaymentSource> sources,
    List<TrackedItem> items, {

    /// The source a new item starts on. Absent, or naming one that has since
    /// been removed, leaves the flag off every row and the screen falls back
    /// to the first.
    String? defaultId,
  }) => [
    for (final source in sources)
      () {
        final used = items
            .where((i) => i.paymentSourceId == source.id)
            .toList(growable: false);
        return SourceRow(
          source: source,
          itemCount: used.length,
          isDefault: source.id == defaultId,
          usage: switch (used.length) {
            0 => S.t.sourcesNotUsedYet,
            1 => used.single.name,
            final n => S.t.sourcesItemCount(n),
          },
        );
      }(),
  ];
}
