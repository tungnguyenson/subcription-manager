/// Words that belong to no one screen: buttons, the tab bar, the units a
/// number is counted in.
abstract class CommonStrings {
  // ---- buttons ----
  String get cancel;
  String get save;
  String get done;
  String get back;
  String get continueOn;
  String get getStarted;

  // ---- units ----

  /// The abbreviation on a big stat card: `14.2M`, `14,2 triệu`.
  ///
  /// A method rather than a suffix string. English puts the letter hard
  /// against the digits and Vietnamese puts a word after a space, and a
  /// caller that concatenated a suffix would have to know which.
  String millions(String digits, String symbol, {required bool minorUnits});
}
