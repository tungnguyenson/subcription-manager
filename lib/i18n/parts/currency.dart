/// The names of the currencies the picker offers.
///
/// Names, not symbols. A symbol is a property of the money and lives in
/// `CurrencyCatalog`; `Japanese yen` is a phrase in a language and belongs
/// here, next to every other phrase.
abstract class CurrencyStrings {
  /// The currency's name, or the bare code where this language has no name
  /// written down for it. Falling back to the code is honest: the row still
  /// says `XPF` beside its symbol and nothing has been invented.
  String currencyName(String code);
}
