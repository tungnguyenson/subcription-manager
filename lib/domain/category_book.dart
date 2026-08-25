import 'default_categories.dart';
import 'model.dart';

/// The shelves as they exist right now, indexed by id.
///
/// Everywhere that used to switch on a five-value enum takes one of these and
/// asks it a question instead. It is passed down rather than reached for
/// globally so a presenter stays pure and a test can hand it three shelves it
/// made up.
class CategoryBook {
  final List<Category> all;
  final Map<String, Category> _byId;

  CategoryBook(List<Category> all)
    : all = List.unmodifiable(all),
      _byId = {for (final category in all) category.id: category};

  /// The shelves the app ships with. For tests and for the moment before the
  /// first read comes back from storage.
  static final CategoryBook shipped = CategoryBook(defaultCategories);

  /// The shelf with this id.
  ///
  /// Never null. A row pointing at a shelf that is not here means storage and
  /// this list disagree, which the foreign key is supposed to prevent; the
  /// screen still has to draw, so it draws the item under a shelf that promises
  /// nothing rather than crashing on a list the user needs.
  Category operator [](String id) => _byId[id] ?? fallback;

  /// Whether the shelf is one this book actually knows.
  bool contains(String id) => _byId.containsKey(id);

  /// Where an item goes when nothing better is known.
  ///
  /// The shipped `OTHER` shelf if it is still here -- the user can delete it --
  /// and otherwise whatever sorts last, because a shelf that exists beats a
  /// shelf that is right.
  Category get fallback =>
      _byId[fallbackCategoryId] ?? (all.isEmpty ? _emptyBookShelf : all.last);

  /// Only reachable if the user has deleted every shelf, which the manager does
  /// not allow. It exists so that [operator []] can promise never to be null
  /// without any caller having to prove the list is non-empty.
  static const Category _emptyBookShelf = Category(
    id: fallbackCategoryId,
    label: 'Other',
    sortOrder: 0,
  );
}
