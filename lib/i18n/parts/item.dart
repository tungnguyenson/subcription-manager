/// The item detail screen, the sentences its presenter builds, and the sheet
/// that asks before deleting one.
abstract class ItemStrings {
  // ---- the summary line ----
  //
  // Each of these comes in two wordings, and which one is used is the
  // category's decision, not the item's. `Due tomorrow` on a passport reads
  // as a bill that could be settled by tapping Pay; `Expires in 4 days` on a
  // prepaid SIM is the difference between a late payment and a lost number.

  String expiredAgo(int days);
  String overdueBy(int days);
  String get expiresToday;
  String get dueToday;
  String get expiresTomorrow;
  String get dueTomorrow;
  String expiresInDays(int days);
  String dueInDays(int days);

  // ---- the rows ----

  String get edit;
  String get rowCategory;
  String get rowRepeats;
  String get rowLastPayment;
  String get rowRemindMe;
  String get rowCost;
  String get rowTotalLeft;
  String get rowPaysFrom;
  String get rowDateFrom;
  String get rowNote;
  String get rowYearlyPlan;

  /// The heading over the timeline card.
  String get whatHappensNext;

  /// What the Cost row says instead of a dash when there is no price yet and
  /// the form can still be opened. A dash on a row that leads somewhere reads
  /// as "nothing to see here".
  String get addACost;
  String get rowHistory;
  String get never;

  /// `Monthly · 3 times`.
  String repeatTimes(String cycle, int total);

  // ---- cycles ----

  String get cycleOnce;
  String get cycleWeekly;
  String get cycleMonthly;
  String get cycleQuarterly;
  String get cycleTwiceAYear;
  String get cycleYearly;

  /// `Every 5 months`, for an interval with no name of its own.
  String cycleEvery(String interval);

  /// `5 months`, `2 weeks`, `10 days` — read back in the largest unit the
  /// interval divides into, so someone who typed "every 2 weeks" is not shown
  /// "every 14 days".
  String intervalDays(int count);
  String intervalWeeks(int count);
  String intervalMonths(int count);
  String intervalYears(int count);

  /// The interval as short as it goes, for the suffix on a cost: `5m`.
  String intervalShortDays(int count);
  String intervalShortWeeks(int count);
  String intervalShortMonths(int count);
  String intervalShortYears(int count);

  /// The suffix on a cost: `$20.00/m`. One letter for the unit, because it
  /// rides on every price in every list and the price is what is being read.
  String get perWeek;
  String get perMonth;
  String get perQuarter;
  String get perHalfYear;
  String get perYear;
  String perInterval(String shortInterval);

  /// An amount and that suffix as one string: `$20.00/m`.
  ///
  /// A method rather than a join in Dart, because the two halves do not go
  /// together the same way in both languages: English spaces the slash off the
  /// number, Vietnamese writes it against the number the way a Vietnamese bill
  /// does -- `260.000đ/tháng`.
  String costEvery(String amount, String per);

  /// The suffix on the yearly-plan comparison: `... a year`.
  String get aYear;

  // ---- instalments ----

  String get instalmentPayment;

  /// `3 of 12`, under the pips.
  String instalmentPosition(int index, int total);

  String instalmentPaid(int count);
  String get instalmentThisOneDue;
  String instalmentLeft(int count);
  String get instalmentLastOne;

  // ---- where a date came from ----

  String get dateSourceConfirmed;
  String get dateSourceRemembered;
  String get dateSourceComputed;
  String get dateSourceExtracted;

  // ---- the reminder ladder ----

  String get leadOnTheDay;
  String leadDaysBefore(int days);

  // ---- actions ----

  String get actions;
  String get editReminders;
  String get remindAgainInThreeDays;
  String get deleteThisItem;
  String get markAsPaid;
  String markPaymentAsPaid(int index);
  String get stopAfterThisPayment;
  String get cancelThisSubscription;
  String get paid;

  /// The line under the delete button, and the one the sheet repeats.
  ///
  /// It used to end by promising the recorded payments survive. They do not —
  /// the rows cascade with the item — and the Spending screen stopped reading
  /// that table when it started deriving months from the cycle. A line that
  /// promises a safety net that is not there is worse than no line, because it
  /// is read immediately before the tap.
  String deleteConsequence(int reminderCount);

  // ---- the sheet that asks ----

  String deleteAskTitle(String name);
  String get deleteAskLost;
  String get deleteAskRemindersStopped;
  String get deleteAskKeep;
  String get deleteAskConfirm;
  String get recordedPaymentsNone;
  String recordedPayments(int count);
  String get pendingRemindersNone;
  String pendingReminders(int count);

  // -- the sheet that stands in front of "Cancel this subscription" --
  String cancelAskTitle(String name);
  String cancelAskStopTitle(int payment);
  String get cancelAskRemindersKept;
  String get cancelAskUsableLabel;
  String get cancelAskLapsedLabel;
  String cancelAskUsableUntil(String date);
  String get cancelAskClosesNow;
  String get cancelAskPlanLabel;
  String cancelAskPlanPayments(int kept, int planned);
  String get cancelAskKeptLabel;
  String get cancelAskKeptValue;
  String get cancelAskConfirm;
  String get cancelAskStopConfirm;
}
