import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/money.dart';
import 'package:subdock/i18n.dart';

import 'item_presenter.dart';

/// The list as a spreadsheet: one line per service, and nothing else.
///
/// **Out only.** There is no reader for this, on purpose. A CSV of ten columns
/// cannot carry the shelves, the payment sources, the recorded payments or the
/// settings, so a file that went out of here and came back in would restore a
/// list into an app that had lost everything standing behind it. The JSON
/// backup on the same screen is the thing that comes back; this is the thing
/// that opens in Excel.
///
/// That split is why the two live side by side rather than one replacing the
/// other. Losing a phone and reading last year's spending are different jobs
/// and the file that serves one serves the other badly.
///
/// In `lib/ui` rather than `lib/domain` because every value in it is a decision
/// about what a person reads: the headers are translated, the amount is
/// formatted, and the interval says `Every 3 months` rather than `P3M`.
abstract final class CsvExport {
  /// RFC 4180 says CRLF, and a plain `\n` is the difference between one row and
  /// one cell in some spreadsheet readers on Windows.
  static const String _eol = '\r\n';

  /// Excel on Windows reads a BOM-less UTF-8 file in the system code page, so a
  /// list with Vietnamese names in it opens as mojibake. Every other reader
  /// ignores the mark.
  static const String _bom = '﻿';

  /// The whole file, ready to hand to the share sheet.
  ///
  /// Every item, inactive ones included, with a column that says which is
  /// which. Someone exporting their list to read it is entitled to the parts
  /// they have put away; the app already knows how to leave them out of a
  /// screen, and a file is not a screen.
  ///
  /// Ordered by date and then by name, because a spreadsheet has no other
  /// order to fall back on and the one the app draws is not one the file can
  /// carry.
  static String encode(
    List<TrackedItem> items, {
    required CategoryBook categories,
    required List<PaymentSource> sources,
  }) {
    final named = {for (final source in sources) source.id: source.name};

    final sorted = [...items]
      ..sort((a, b) {
        final byDate = a.expiresOn.compareTo(b.expiresOn);
        return byDate != 0 ? byDate : a.name.compareTo(b.name);
      });

    final rows = <List<String>>[
      [
        S.t.csvColName,
        S.t.csvColCategory,
        S.t.csvColNextDate,
        S.t.csvColRepeats,
        S.t.csvColAmount,
        S.t.csvColCurrency,
        S.t.csvColPaidWith,
        S.t.csvColTrial,
        S.t.csvColStatus,
        S.t.csvColNote,
      ],
      for (final item in sorted)
        [
          item.name,
          categories[item.categoryId].displayLabel,
          // ISO, not the day-first form the screens use. This column is sorted
          // and filtered in a spreadsheet rather than read as prose, and
          // `27/08/2026` is the one date shape a spreadsheet reads differently
          // depending on where the reader lives.
          item.expiresOn.toString(),
          ItemPresenter.cycleLabel(item.cycle),
          _amount(item.amountMinor, item.currency),
          item.currency ?? '',
          named[item.paymentSourceId] ?? '',
          // The flag, not `isTrialOn(today)`. The file has no today in it, and
          // the flag is the thing the user set. See trap 14.
          item.inTrial ? S.t.csvYes : S.t.csvNo,
          _state(item.state),
          item.note ?? '',
        ],
    ];

    return _bom + rows.map(_line).join(_eol) + _eol;
  }

  /// The name the file is offered under, dated like the JSON backup beside it.
  static String fileNameFor(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final local = at.toLocal();
    return 'subdock-${local.year}-${two(local.month)}-${two(local.day)}'
        '-${two(local.hour)}${two(local.minute)}.csv';
  }

  static String _line(List<String> cells) => cells.map(_cell).join(',');

  /// Quoted only where it has to be, and quotes inside doubled.
  ///
  /// A note is free text, so it can hold a comma, a quote, or a line break, and
  /// any of the three turns one row into two or one cell into three when
  /// written raw.
  static String _cell(String value) {
    if (!value.contains(RegExp('[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Plain digits with a full stop, never grouped.
  ///
  /// [MoneyFormat.majorInput] groups thousands for a human reading one number
  /// on a screen; here the comma is the column separator and a spreadsheet
  /// reads `260,000` as text rather than as a number. The currency travels in
  /// its own column, so no symbol goes in this one.
  static String _amount(int? minor, String? currency) {
    if (minor == null || currency == null) return '';

    final exponent = Currencies.exponentOf(currency);
    if (exponent == 0) return '$minor';

    final unit = Currencies.pow10(exponent);
    final fraction = (minor % unit).abs().toString().padLeft(exponent, '0');
    return '${minor ~/ unit}.$fraction';
  }

  static String _state(ItemState state) => switch (state) {
    ItemState.active => S.t.csvStateActive,
    ItemState.cancelledStillActive => S.t.csvStateCancelled,
    ItemState.inactive => S.t.csvStateInactive,
  };
}
