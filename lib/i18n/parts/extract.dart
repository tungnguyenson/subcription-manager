/// Reading a bill from a photo: the review screen, the warnings it raises,
/// and every way the request can fail.
///
/// The warnings are the part that matters. Everything on that screen was read
/// by a model rather than typed by the user, and a screen that does not say so
/// is the app claiming a certainty it does not have.
abstract class ExtractStrings {
  String get scanTitle;
  String get scanLead;
  String get scanCaption;
  String get scanRetake;
  String get scanCouldNotRead;
  String get scanNothingToQuote;
  String get scanDue;
  String get scanAmount;

  /// `2,000 · unit unclear` — digits the model read but could not place a
  /// currency against.
  String scanUnitUnclear(String minor);

  String get scanDayBeforeMonth;
  String get scanMonthBeforeDay;

  // ---- warnings ----

  String warnUnsupportedValue(String field);
  String warnAmbiguousDate(String raw);
  String get warnMissingDate;
  String get warnUnknownCurrency;
  String get warnLowConfidence;

  /// The field names those warnings quote.
  String get fieldServiceNameLower;
  String get fieldDueLower;
  String get fieldAmountLower;

  // ---- failures ----

  String get errRateLimited;
  String get errCreditExhausted;
  String get errSpendLimit;
  String get errInvalidKey;
  String get errRegionUnsupported;
  String get errUpstream;
  String get errNoNetwork;
  String get errUnreadable;
  String get errTruncated;
  String get errBadShape;
  String get errNoApiKey;
}
