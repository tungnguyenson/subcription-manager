import 'package:meta/meta.dart';

import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/manage_link.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/date_copy.dart';
import 'package:subdock/ui/money_format.dart';
import 'package:subdock/ui/screens/upcoming_screen.dart';
import 'package:subdock/i18n.dart';
import 'package:subdock/domain/fx.dart';

/// The two questions the Savings screen answers, and nothing else.
///
/// **Move to yearly** is arithmetic on prices the vendor publishes. **Cancel**
/// is arithmetic on what the user already told us they pay. Both are honest for
/// the same reason: neither invents a figure, and where a figure is missing the
/// screen says so instead of estimating one.
///
/// What this screen deliberately cannot do is claim a service is cancellable
/// when the app has no page for it. Only 25 of the 223 catalogue entries carry
/// a `cancelUrl`, so "no cancel page known" is the common answer and is stated
/// as such. A button that opens a search results page would be worse than no
/// button: it looks like the app knows where to go.
enum SavingsTab { yearly, cancel }

/// One monthly plan that costs less bought by the year.
@immutable
class YearlyRow {
  final String itemId;
  final String name;
  final String? iconName;

  /// `−456,000 ₫`. Signed, because every figure on this screen is money
  /// leaving the user's total rather than entering it.
  final String saving;

  /// `129,000 ₫ × 12 → 1,092,000 ₫ · 16% less`. The multiplication is shown
  /// rather than folded away: it is what lets a user whose own price differs
  /// redo the sum in their head instead of trusting the total.
  final String compare;

  /// Where the two prices came from and when, or the warning that they are old
  /// enough to check. Never absent.
  final String note;

  /// True once the listed price is over a year old. The wording already hedges;
  /// this is for the layout, which stops treating the note as a footnote.
  final bool stale;

  /// The date the renewal reminder will land on, already worded.
  final String remindOn;

  final YearlyChoice choice;

  const YearlyRow({
    required this.itemId,
    required this.name,
    this.iconName,
    required this.saving,
    required this.compare,
    required this.note,
    required this.stale,
    required this.remindOn,
    required this.choice,
  });

  bool get reminding => choice == YearlyChoice.remind;
}

/// A monthly plan with no yearly price to compare against.
///
/// Listed rather than dropped. The user knows their own price even where the
/// catalogue does not, and an item that silently never appears in a savings
/// screen looks like an item the app decided was fine.
@immutable
class UnpricedRow {
  final String itemId;
  final String name;
  final String? iconName;

  const UnpricedRow({required this.itemId, required this.name, this.iconName});
}

/// Where a service is actually cancelled, if the app knows.
@immutable
class CancelTarget {
  /// `Web`, `App Store`, `Google Play`, `Account page`, `Not cancellable`.
  final String via;

  /// What the user will see: a host and path, or a settings breadcrumb.
  final String where;

  /// The URL to open, or null when there is nowhere honest to send them.
  final String? url;

  /// The button's words. Null alongside a null [url].
  final String? action;

  const CancelTarget({
    required this.via,
    required this.where,
    this.url,
    this.action,
  });

  bool get canOpen => url != null;
}

/// One service, with what dropping it is worth over a year.
@immutable
class CancelRow {
  final String itemId;
  final String name;
  final String? iconName;
  final CancelTarget target;

  /// `−3,120,000 ₫/yr`, or `—` when the app has no amount for it. Never
  /// estimated: a subscription with no price entered contributes nothing to the
  /// group total and says so.
  final String yearly;

  final bool hasAmount;

  const CancelRow({
    required this.itemId,
    required this.name,
    this.iconName,
    required this.target,
    required this.yearly,
    required this.hasAmount,
  });
}

/// Services grouped by how easily they can be dropped.
@immutable
class CancelGroup {
  final String label;
  final String hint;
  final List<CancelRow> rows;

  /// The group's yearly total, one exact figure per currency. `—` when nothing
  /// in the group has an amount.
  final String total;

  /// True for the group nobody should be nudged to cancel. The screen dims its
  /// heading and its total: a green number beside "health insurance" is the app
  /// recommending something it has no business recommending.
  final bool discouraged;

  const CancelGroup({
    required this.label,
    required this.hint,
    required this.rows,
    required this.total,
    this.discouraged = false,
  });
}

@immutable
class SavingsView {
  // ---- move to yearly ----

  /// `456,000 ₫ + $24.00`. One exact subtotal per currency, joined — never
  /// converted into one number. Mixing two currencies through a bundled rate
  /// would turn the one figure on this screen into an estimate.
  final String total;

  /// `a year, moving 2 plans to yearly`.
  final String totalSub;

  final List<YearlyRow> yearly;
  final List<UnpricedRow> unpriced;

  /// `Left out: 1 already yearly · 1 in a trial · 3 with no yearly plan`.
  ///
  /// Not optional when anything was left out. A savings screen that quietly
  /// considers half the list is a savings screen whose total cannot be trusted.
  final String? leftOut;

  /// How many suggestions the user dismissed, for the line that brings them
  /// back. Zero when none.
  final int skipped;

  // ---- cancel ----

  final List<CancelGroup> groups;

  const SavingsView({
    required this.total,
    required this.totalSub,
    required this.yearly,
    required this.unpriced,
    required this.groups,
    this.leftOut,
    this.skipped = 0,
  });

  bool get hasYearly => yearly.isNotEmpty;
  bool get hasGroups => groups.isNotEmpty;

  /// The line under the tab strip on the yearly tab.
  String leadFor(SavingsTab tab, int monthlyCount) => switch (tab) {
    SavingsTab.cancel => S.t.savingsCancelLead,
    SavingsTab.yearly when yearly.isEmpty => S.t.savingsNothingToMove,
    SavingsTab.yearly => S.t.savingsYearlyLead(yearly.length, monthlyCount),
  };
}

abstract final class SavingsPresenter {
  /// How easy each shipped shelf is to walk away from.
  ///
  /// A judgement, and it is made here in one table rather than scattered
  /// through the screen so it can be argued with. The third tier is not "the
  /// rest" — it is the set the app should *not* nudge anyone out of: storage
  /// holding the only copy of their photos, the line their phone number lives
  /// on, insurance, a password manager. Suggesting those be cancelled to save
  /// money is exactly the mistake this app was built to avoid, since losing a
  /// phone number costs more than ten years of Netflix.
  ///
  /// A shelf not named here — one the user made — lands in the third tier too.
  /// "I have no idea what this is" and "do not suggest dropping it" are the
  /// same answer.
  static const Map<String, int> _ease = {
    'STREAMING': 0,
    'ENTERTAINMENT': 0,
    'MUSIC': 0,
    'GAMING': 0,
    'DATING': 0,
    'SOCIAL': 0,
    'NEWS': 0,
    'FOOD': 0,
    'TRAVEL': 0,
    'PRODUCTIVITY': 1,
    'AI': 1,
    'EDUCATION': 1,
    'FITNESS': 1,
    'STORAGE': 2,
    'PHONE': 2,
    'UTILITIES': 2,
    'HOUSING': 2,
    'INSURANCE': 2,
    'FINANCE': 2,
    'SECURITY': 2,
    'DOCUMENTS': 2,
  };

  /// Read per call, not held as a `const`: these are words and words move
  /// with the language. The tier *order* does not, and neither does which
  /// shelf lands in which tier — that judgement is [_ease] above.
  static List<(String, String)> get _tiers => [
    (S.t.tierEntertainment, S.t.tierEntertainmentHint),
    (S.t.tierWork, S.t.tierWorkHint),
    (S.t.tierHard, S.t.tierHardHint),
  ];

  /// A price older than this stops being stated and starts being suggested.
  /// Twelve months, matching [AnnualSavingPresenter]: most vendors move list
  /// prices about once a year, so a shorter hedge prints the warning on nearly
  /// every row and teaches the user to read past it.
  static const int staleAfterMonths = 12;

  static SavingsView build({
    required List<TrackedItem> items,
    required ServiceCatalog catalog,
    required CategoryBook categories,
    required LocalDate today,
    required List<int> defaultLeadDays,
  }) {
    // Archived items are gone; paused ones are not. A service switched off is
    // still being paid for, so it still belongs in a screen about money going
    // out — hiding it here would be the app losing track of a charge.
    final live = items
        .where((i) => i.state != ItemState.archived)
        .toList(growable: false);

    // Only what the user could choose to stop paying. An obligation -- a bill,
    // a policy, the line a phone number lives on -- has no yearly plan to move
    // to and no version of "cancel it" worth putting on screen.
    final monthly = live
        .where(
          (i) =>
              !categories[i.categoryId].isObligation &&
              !i.isTrialOn(today) &&
              _billedMoreOftenThanYearly(i.cycle),
        )
        .toList(growable: false);

    final yearlyRows = <YearlyRow>[];
    final unpriced = <UnpricedRow>[];
    final totals = <String, int>{};
    var skipped = 0;

    for (final item in monthly) {
      final saving = _worthShowing(catalog.matchByName(item.name));
      if (saving == null) {
        unpriced.add(
          UnpricedRow(
            itemId: item.id,
            name: item.name,
            iconName: item.iconName,
          ),
        );
        continue;
      }
      if (item.yearlyChoice == YearlyChoice.skipped) {
        skipped++;
        continue;
      }

      final row = _yearlyRow(item, saving, today, defaultLeadDays);
      yearlyRows.add(row);
      totals.update(
        saving.currency,
        (n) => n + saving.savingMinor,
        ifAbsent: () => saving.savingMinor,
      );
    }

    final alreadyYearly = live
        .where(
          (i) =>
              !categories[i.categoryId].isObligation &&
              !i.isTrialOn(today) &&
              !_billedMoreOftenThanYearly(i.cycle),
        )
        .length;
    final inTrial = live.where((i) => i.isTrialOn(today)).length;

    return SavingsView(
      total: _joinCurrencies(totals, sign: false),
      totalSub: yearlyRows.isEmpty
          ? S.t.savingsNothingToMoveShort
          : S.t.savingsTotalSub(yearlyRows.length),
      yearly: yearlyRows,
      unpriced: unpriced,
      leftOut: _leftOut(
        alreadyYearly: alreadyYearly,
        inTrial: inTrial,
        unpriced: unpriced.length,
      ),
      skipped: skipped,
      groups: _groups(live, catalog, categories),
    );
  }

  /// How many monthly plans were considered, for the lead line's denominator.
  static int monthlyCount(
    List<TrackedItem> items,
    CategoryBook categories,
    LocalDate today,
  ) => items
      .where(
        (i) =>
            i.state != ItemState.archived &&
            !categories[i.categoryId].isObligation &&
            !i.isTrialOn(today) &&
            _billedMoreOftenThanYearly(i.cycle),
      )
      .length;

  // ---- move to yearly ----

  static YearlyRow _yearlyRow(
    TrackedItem item,
    AnnualSaving saving,
    LocalDate today,
    List<int> defaultLeadDays,
  ) {
    final currency = saving.currency;
    final monthly = Money(saving.monthly.amountMinor, currency);
    final twelve = Money(saving.monthly.amountMinor * 12, currency);
    final yearly = Money(saving.yearly.amountMinor, currency);
    final saved = Money(saving.savingMinor, currency);

    // The older of the two dates. The sum is only as fresh as its weaker half,
    // and quoting the newer one would overstate how current it is.
    final checked = LocalDate.min(
      LocalDate.parse(saving.monthly.checkedAt),
      LocalDate.parse(saving.yearly.checkedAt),
    );
    final stale = _monthsBetween(checked, today) > staleAfterMonths;

    final percent = twelve.minor == 0
        ? 0
        : (saving.savingMinor * 100 / twelve.minor).round();

    // The user's own price, when it differs enough from the listed one that the
    // sum above would look broken to them. This is the same hazard
    // AnnualSavingPresenter guards on the detail screen: a listed price is not
    // the price they pay.
    final theirs = item.money;
    final mismatch =
        theirs != null &&
        theirs.currency == currency &&
        monthly.minor != 0 &&
        (theirs.minor - monthly.minor).abs() * 10 > monthly.minor.abs();

    return YearlyRow(
      itemId: item.id,
      name: item.name,
      iconName: item.iconName,
      saving: '−${MoneyFormat.full(saved)}',
      compare: S.t.yearlyCompare(
        MoneyFormat.full(monthly),
        MoneyFormat.full(yearly),
        percent,
      ),
      note: stale
          ? S.t.yearlyNoteStale(DateCopy.listedDate(checked))
          : (mismatch
                ? S.t.yearlyNoteMismatch(
                    MoneyFormat.full(monthly),
                    MoneyFormat.full(theirs),
                  )
                : S.t.yearlyNoteFresh(DateCopy.listedDate(checked))),
      stale: stale,
      remindOn: _remindOn(item, defaultLeadDays),
      choice: item.yearlyChoice,
    );
  }

  /// The day the renewal reminder actually lands, so the button can name it.
  ///
  /// The item's own furthest-out lead, falling back to the app default, because
  /// that is the notification the note rides on — see [PlannedAlert.note]. A
  /// button that promised the renewal date itself would be a day or a week out.
  static String _remindOn(TrackedItem item, List<int> defaultLeadDays) {
    final leads = item.leadDays.isNotEmpty ? item.leadDays : defaultLeadDays;
    final lead = leads.isEmpty ? 0 : leads.reduce((a, b) => a > b ? a : b);
    return UpcomingCopy.shortDate(item.actBy.minusDays(lead));
  }

  static String? _leftOut({
    required int alreadyYearly,
    required int inTrial,
    required int unpriced,
  }) {
    final parts = <String>[
      if (alreadyYearly > 0) S.t.leftOutAlreadyYearly(alreadyYearly),
      if (inTrial > 0) S.t.leftOutInTrial(inTrial),
      if (unpriced > 0) S.t.leftOutUnpriced(unpriced),
    ];
    return parts.isEmpty ? null : S.t.leftOut(parts.join(S.t.bullet));
  }

  // ---- cancel ----

  static List<CancelGroup> _groups(
    List<TrackedItem> live,
    ServiceCatalog catalog,
    CategoryBook categories,
  ) {
    final buckets = <int, List<CancelRow>>{0: [], 1: [], 2: []};
    final totals = <int, Map<String, int>>{0: {}, 1: {}, 2: {}};

    for (final item in live) {
      // Whatever the user keeps off their spending is renewed, not cancelled:
      // a passport is not a subscription, and offering to stop paying for one
      // is nonsense.
      if (!categories[item.categoryId].countsTowardSpend) continue;

      final entry = catalog.matchByName(item.name);
      final tier = _ease[item.categoryId] ?? 2;
      final target = cancelTarget(item, entry);
      final money = _yearlyCost(item);

      buckets[tier]!.add(
        CancelRow(
          itemId: item.id,
          name: item.name,
          iconName: item.iconName,
          target: target,
          yearly: money == null
              ? '—'
              : S.t.perYearAmount('−${MoneyFormat.full(money)}'),
          hasAmount: money != null,
        ),
      );

      if (money != null) {
        totals[tier]!.update(
          money.currency,
          (n) => n + money.minor,
          ifAbsent: () => money.minor,
        );
      }
    }

    return [
      for (var tier = 0; tier < _tiers.length; tier++)
        if (buckets[tier]!.isNotEmpty)
          CancelGroup(
            label: _tiers[tier].$1,
            hint: _tiers[tier].$2,
            rows: buckets[tier]!,
            total: totals[tier]!.isEmpty
                ? '—'
                : S.t.perYearAmount(_joinCurrencies(totals[tier]!, sign: true)),
            discouraged: tier == 2,
          ),
    ];
  }

  /// Where this subscription is actually cancelled.
  ///
  /// Four answers in falling order of certainty, and the last one is "nowhere
  /// we know". That case is the majority — 25 of 223 catalogue entries carry a
  /// cancel page — and it is stated rather than papered over. Sending someone
  /// to a search page they have to work out for themselves, from a button that
  /// looked like the app knew, is worse than telling them the app does not.
  static CancelTarget cancelTarget(TrackedItem item, CatalogEntry? entry) {
    // Where they bought it beats where the vendor would like them to go. A
    // subscription billed through the App Store cannot be cancelled on the
    // vendor's site at all — the vendor's page will not even list it.
    switch (item.purchaseChannel) {
      case PurchaseChannel.appStore:
        return CancelTarget(
          via: S.t.viaAppStore,
          where: S.t.whereAppStore,
          url: ManageLinks.appStore,
          action: S.t.actionAppStore,
        );
      case PurchaseChannel.playStore:
        return CancelTarget(
          via: S.t.viaGooglePlay,
          where: S.t.whereGooglePlay,
          url: ManageLinks.playStore,
          action: S.t.actionGooglePlay,
        );
      case PurchaseChannel.web:
      case PurchaseChannel.unknown:
        break;
    }

    final cancel = entry?.cancelUrl;
    if (cancel != null && cancel.isNotEmpty) {
      return CancelTarget(
        via: S.t.viaWeb,
        where: _readable(cancel),
        url: cancel,
        action: S.t.actionCancelPage,
      );
    }

    // No cancel page, but an account page. Cancelling almost always lives
    // inside it, and "Account page" says exactly what the app is offering
    // rather than claiming this link cancels anything.
    final manage = entry?.manageUrl;
    if (manage != null && manage.isNotEmpty) {
      return CancelTarget(
        via: S.t.viaAccountPage,
        where: _readable(manage),
        url: manage,
        action: S.t.actionAccountPage,
      );
    }

    return CancelTarget(
      via: S.t.viaNotInCatalogue,
      where: S.t.whereNotInCatalogue,
    );
  }

  /// What this item costs over twelve months, or null when no amount is set.
  ///
  /// A one-off is excluded: it is not a recurring charge, so "stop paying it
  /// every year" is not a thing that can be stopped.
  static Money? _yearlyCost(TrackedItem item) {
    final money = item.money;
    final cycle = item.cycle;
    if (money == null || cycle == null) return null;

    final perYear = switch (cycle.unit) {
      CycleUnit.month => 12 / cycle.step,
      CycleUnit.day => 365 / cycle.step,
    };
    return Money((money.minor * perYear).round(), money.currency);
  }

  /// `example.com/cancel` — the part the user will recognise, without the
  /// scheme, which is noise in a line whose job is to say where they are going.
  static String _readable(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final path = uri.path == '/' ? '' : uri.path;
    return '${uri.host}$path';
  }

  // ---- shared ----

  /// One exact subtotal per currency, joined with a plus. Never converted.
  ///
  /// The bundled FX rate is good enough to orient someone on a spending total
  /// behind a tilde. It is not good enough here: this screen's whole claim is
  /// "you would keep exactly this much", and an approximation inside that
  /// sentence makes the sentence false.
  static String _joinCurrencies(Map<String, int> totals, {required bool sign}) {
    if (totals.isEmpty) return '—';
    // VND first — it is the money that actually leaves a card in Vietnam —
    // then the rest alphabetically so the order never depends on insertion.
    final keys = totals.keys.toList()
      // The currency the app counts in leads, whichever one that is. It used
      // to be the dong by name, which put a foreign subtotal first for anyone
      // who told onboarding they pay in something else.
      ..sort((a, b) {
        if (a == Fx.base) return -1;
        if (b == Fx.base) return 1;
        return a.compareTo(b);
      });
    return keys
        .map(
          (c) => '${sign ? "−" : ""}${MoneyFormat.full(Money(totals[c]!, c))}',
        )
        .join(' + ');
  }

  /// The pair worth putting on screen: Vietnam first, then global.
  ///
  /// A saving of zero counts as nothing to show. Some vendors list the yearly
  /// plan at exactly twelve monthly payments and put the discount in a
  /// promotion instead; `Save 0 ₫ a year` is not a smaller version of this row,
  /// it is a different and much worse one.
  static AnnualSaving? _worthShowing(CatalogEntry? entry) {
    if (entry == null) return null;
    for (final region in const ['VN', 'GLOBAL']) {
      final saving = entry.annualSaving(region: region);
      if (saving != null && saving.savingMinor > 0) return saving;
    }
    return null;
  }

  static bool _billedMoreOftenThanYearly(Cycle? cycle) => switch (cycle) {
    null => false,
    Cycle(unit: CycleUnit.month, :final step) => step < 12,
    Cycle(unit: CycleUnit.day, :final step) => step < 365,
  };

  static int _monthsBetween(LocalDate from, LocalDate to) {
    final months = (to.year - from.year) * 12 + (to.month - from.month);
    return to.day < from.day ? months - 1 : months;
  }
}
