/// The names of the shelves the app ships with.
///
/// A translation of a *default*, not of a shelf. A category is a row the user
/// owns — they can rename it, and the moment they do, the name they typed is
/// the name, in either language. This table only answers for a shipped row
/// still carrying the label it was seeded with; see [Category.displayLabel].
///
/// It is keyed by the shipped id rather than by the English label, so renaming
/// one in `default_categories.dart` cannot silently orphan its translation.
abstract class CategoryStrings {
  /// The shipped label for [id] in this language, or null where there is
  /// none — which is every shelf the user made.
  String? categoryLabel(String id);
}
