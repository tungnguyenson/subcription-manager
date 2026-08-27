/// The two screens shown before the list exists.
abstract class OnboardingStrings {
  // ---- screen one: what the app is for ----

  String get onboardTitle;

  String get onboardListTitle;
  String get onboardNotifyTitle;
  String get onboardSpendTitle;

  /// Under the bar chart, beside the total.
  String get onboardNextTwelveMonths;

  // ---- the sample rows in the marquee ----
  //
  // Written out per language rather than shipped as data. These are the first
  // words about the app a user reads, and "Mobile SIM" has to become "SIM
  // điện thoại" rather than a English name with a Vietnamese date beside it.

  String get sampleMobileSim;
  String get sampleElectricity;
  String get sampleCarInsurance;
  String get sampleDrivingLicence;
  String get sampleHomeInternet;
  String get sampleWaterBill;

  /// `expires 23/09`, `hết hạn 23/09`.
  String expiresOn(String date);

  /// `due 20/08`.
  String dueOn(String date);

  /// `renews 22/08`.
  String renewsOn(String date);

  /// `trial ends 17/08`.
  String trialEndsOn(String date);

  // ---- the notification mock-up ----

  String notifSimTitle(int days);
  String get notifSimBody;
  String get notifNetflixTitle;
  String notifNetflixBody(String amount);

  /// The stamp on the right of a notification: `now`.
  String get notifNow;

  /// `1d`, `2d` — how long ago a notification arrived.
  String notifAge(int days);

  // ---- screen two: language and currency ----

  /// The page title. It names both questions, because both are on it and a
  /// title that named only one would make the other look like a detail of it.
  String get onboardCurrencyTitle;

  String get onboardLanguageLabel;

  /// The heading over the declared currencies.
  String get onboardCurrencyLabel;

  /// The dashed row under the declared currencies.
  String get onboardAddCurrency;

  /// The row at the bottom of the currency list, into the full search.
  String get onboardOtherCurrency;

  String get onboardSearchCurrency;

  /// Under each sample card: the cycle the sample amount is charged on.
  ///
  /// The only part of the sample card that is translated. The service name and
  /// the plan tier beside it are not, and that follows the real catalog, where
  /// `CatalogPlan.name` ships in the provider's own wording and stays in it
  /// whichever language the app is being read in.
  String get onboardSampleMonthly;

  /// The heading over the two chips, shown only once there are two currencies
  /// to choose between.
  String get onboardDefaultLabel;

  /// Under those chips, saying what the choice actually does.
  String get onboardDefaultNote;

  /// The label on the control that takes a currency back off the list.
  String get onboardRemoveCurrency;

  /// Shown under a currency the app holds no exchange rate for.
  ///
  /// The app converts only between the dong and the dollar, because that is
  /// the one rate it has a bundled figure for. Picking anything else is
  /// allowed and everything still adds up per currency — but the single
  /// combined total goes away, and this is where the app says so rather than
  /// letting the user discover it on the Money screen.
  String get onboardNoRateNote;
}
