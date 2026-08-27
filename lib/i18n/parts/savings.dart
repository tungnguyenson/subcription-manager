/// The Savings screen: the yearly-plan tab, the cancel tab, and the block on
/// the item screen that compares a monthly price with a yearly one.
abstract class SavingsStrings {
  String get tabMoveToYearly;
  String get tabCancelAService;

  /// The line under the tab strip.
  String get savingsCancelLead;
  String get savingsNothingToMove;
  String savingsYearlyLead(int cheaper, int monthlyCount);

  /// Under the big figure.
  String get savingsNothingToMoveShort;
  String savingsTotalSub(int plans);

  String get paidUpFront;

  /// `3 suggestions skipped — show again`.
  String skippedSuggestions(int count);

  /// The standing caveat on the cancel tab. The app cannot cancel anything for
  /// anyone, and says so before offering a single button.
  String get cancelDisclaimer;

  String reminderSetFor(String date);
  String remindMeOn(String date);
  String get skip;

  /// `2 plans have no yearly price yet`.
  String noYearlyPriceYet(int count);
  String get addPrice;

  String get openedOpenAgain;
  String get cancelledRemove;

  // ---- the three tiers on the cancel tab ----

  String get tierEntertainment;
  String get tierEntertainmentHint;
  String get tierWork;
  String get tierWorkHint;
  String get tierHard;
  String get tierHardHint;

  // ---- one yearly row ----

  /// `260,000 ₫ × 12 → 2,400,000 ₫ · 23% less`.
  String yearlyCompare(String monthly, String yearly, int percent);

  String yearlyNoteStale(String checkedDate);
  String yearlyNoteMismatch(String listed, String entered);
  String yearlyNoteFresh(String checkedDate);

  /// `Left out: 2 already yearly · 1 in a trial`.
  String leftOut(String parts);
  String leftOutAlreadyYearly(int count);
  String leftOutInTrial(int count);
  String leftOutUnpriced(int count);

  /// `−1,200,000 ₫/yr`, the total of one tier.
  String perYearAmount(String amount);

  // ---- where a subscription is actually cancelled ----

  String get viaAppStore;
  String get whereAppStore;
  String get actionAppStore;
  String get viaGooglePlay;
  String get whereGooglePlay;
  String get actionGooglePlay;
  String get viaWeb;
  String get actionCancelPage;
  String get viaAccountPage;
  String get actionAccountPage;
  String get viaNotInCatalogue;
  String get whereNotInCatalogue;

  // ---- the yearly-plan block on the item screen ----

  String get savingLeadAbout;
  String get savingLeadExact;
  String savingLine(String lead, String amount);
  String twelveTimes(String monthly, String twelve);
  String annualNoteStale(String checkedDate);
  String annualNoteFresh(String checkedDate);
  String annualNoteMismatch(String listed, String entered);

  // ---- the button that opens a provider's own page ----

  String openAccount(String name);
  String get manageInAppStore;
  String get manageInGooglePlay;
  String get boughtThroughAppStore;
}
