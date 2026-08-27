/// The Spending screen: its card, its chart, and the two breakdowns under it.
abstract class MoneyStrings {
  String get spanMonth;
  String get spanYear;

  /// The card's own heading. `This month` while the month shown is the one we
  /// are in, and the month's name otherwise.
  String get thisMonth;

  /// The heading of the twelve-month view.
  String get nextTwelveMonths;

  String get costByMonth;

  String get inAFreeTrial;

  /// `Starts charging 17/08`, under a trial's name.
  String startsCharging(String date);

  String get byCategory;
  String get byItem;
  String get paymentHistory;

  /// The link at the end of that row.
  String get open;

  /// The second breakdown of the same total. It says so because three figures
  /// under a total, separated by nothing but a hairline, read as more money
  /// rather than as the same money sorted.
  String get whereItGoes;
  String get whereItGoesCaption;

  String get bandSubscriptions;
  String get bandBills;
  String get bandAnnual;

  /// `Netflix ×4` — a charge that lands more than once in the month says so,
  /// because four times the price with no explanation reads as a bug.
  String timesInMonth(String name, int times);

  /// The one mark that means "converted with a bundled rate". It never means
  /// "multiplied by a cycle": twelve times a whole number of dong is exact.
  String approximately(String amount);

  /// `≈ $545.31 (26,046 ₫/$)` — the same total in the other currency, with
  /// the rate that produced it riding on the same line.
  String alternateTotal(String amount, String rate);

  /// Money that fell out of the total for want of a rate. A warning, not a
  /// footnote: it is the one thing on the card the figures cannot say for
  /// themselves.
  String unconverted(int currencies);

  // ---- what a screen reader hears on a chart column ----

  String get chartNothingDue;
  String chartAmount(String digits, String currency);
  String get chartNotDueYet;
}
