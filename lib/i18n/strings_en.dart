import 'parts/currency_names_en.dart';
import 'strings.dart';

class EnStrings implements Strings {
  const EnStrings();

  // ---- common ----

  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get done => 'Done';
  @override
  String get back => 'Back';
  @override
  String get continueOn => 'Continue';
  @override
  String get getStarted => 'Get started';

  @override
  String millions(String digits, String symbol, {required bool minorUnits}) =>
      minorUnits ? '$symbol${digits}M' : '${digits}M $symbol';

  // ---- currency ----

  @override
  String currencyName(String code) =>
      CurrencyNamesEn.names[code.toUpperCase()] ?? code.toUpperCase();

  // ---- onboarding ----

  @override
  String get onboardTitle => 'Never miss a due date again.';

  @override
  String get onboardListTitle => 'Everything with a date, in one list';
  @override
  String get onboardNotifyTitle => 'Told before the date, not after';
  @override
  String get onboardSpendTitle => 'See what it adds up to';

  @override
  String get onboardNextTwelveMonths => 'Next 12 months';

  @override
  String get sampleMobileSim => 'Mobile SIM';
  @override
  String get sampleElectricity => 'Electricity';
  @override
  String get sampleCarInsurance => 'Car insurance';
  @override
  String get sampleDrivingLicence => 'Driving licence';
  @override
  String get sampleHomeInternet => 'Home internet';
  @override
  String get sampleWaterBill => 'Water bill';

  @override
  String expiresOn(String date) => 'expires $date';
  @override
  String dueOn(String date) => 'due $date';
  @override
  String renewsOn(String date) => 'renews $date';
  @override
  String trialEndsOn(String date) => 'trial ends $date';

  @override
  String notifSimTitle(int days) =>
      'Mobile SIM expires in $days ${days == 1 ? 'day' : 'days'}';
  @override
  String get notifSimBody => 'Top up to keep the number';
  @override
  String get notifNetflixTitle => 'Netflix renews tomorrow';
  @override
  String notifNetflixBody(String amount) => '$amount · one nudge only';

  @override
  String get notifNow => 'now';
  @override
  String notifAge(int days) => '${days}d';

  @override
  String get onboardCurrencyTitle => 'Which currency do you pay in?';
  @override
  String get onboardCurrencyBody =>
      'Totals and each item are shown in this currency. You can still enter '
      'a price in another one.';
  @override
  String get onboardOtherCurrency => 'Another currency';
  @override
  String get onboardSearchCurrency => 'Search currencies';
  @override
  String get onboardLanguageLabel => 'Language';
  @override
  String get onboardNoRateNote =>
      'Subdock carries one exchange rate, between the dong and the dollar. In '
      'another currency each one still adds up on its own, but there is no '
      'single combined total.';
}
