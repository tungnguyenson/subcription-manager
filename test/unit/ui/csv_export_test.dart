import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/csv_export.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  TrackedItem item({
    String id = 'a',
    String name = 'Netflix',
    String categoryId = 'STREAMING',
    String expires = '2026-09-01',
    Cycle? cycle = Cycle.monthly,
    int? amountMinor = 260000,
    String? currency = 'VND',
    String? sourceId,
    bool inTrial = false,
    ItemState state = ItemState.active,
    String? note,
  }) => TrackedItem(
    id: id,
    name: name,
    categoryId: categoryId,
    expiresOn: d(expires),
    anchorDate: d(expires),
    cycle: cycle,
    amountMinor: amountMinor,
    currency: currency,
    paymentSourceId: sourceId,
    inTrial: inTrial,
    state: state,
    note: note,
  );

  String encode(
    List<TrackedItem> items, {
    List<PaymentSource> sources = const [],
  }) => CsvExport.encode(
    items,
    categories: CategoryBook.shipped,
    sources: sources,
  );

  /// The file without its byte order mark, split into rows.
  List<String> rows(String csv) =>
      csv.replaceFirst('﻿', '').trimRight().split('\r\n');

  List<String> cells(String row) => row.split(',');

  group('the shape of the file', () {
    // Excel on Windows reads a BOM-less UTF-8 file in the system code page,
    // which turns a list of Vietnamese names into mojibake on open.
    test('starts with a byte order mark', () {
      expect(encode([item()]).startsWith('﻿'), isTrue);
    });

    // RFC 4180. A bare newline is one row to some readers and one cell to
    // others.
    test('rows end with CRLF, including the last one', () {
      expect(encode([item()]).endsWith('\r\n'), isTrue);
      expect(encode([item()]).contains('\n\r'), isFalse);
    });

    test('the first row names the columns', () {
      expect(cells(rows(encode([item()])).first), [
        'Name',
        'Category',
        'Next date',
        'Repeats',
        'Amount',
        'Currency',
        'Paid with',
        'Free trial',
        'Status',
        'Note',
      ]);
    });

    test('an empty list is still a file with headings in it', () {
      expect(rows(encode([])).length, 1);
    });

    // A spreadsheet has no order of its own to fall back on, and the order the
    // app draws is not one a file can carry.
    test('items come out by date, then by name', () {
      final out = rows(
        encode([
          item(id: 'c', name: 'Spotify', expires: '2026-09-05'),
          item(id: 'b', name: 'Adobe', expires: '2026-09-01'),
          item(id: 'a', name: 'Netflix', expires: '2026-09-01'),
        ]),
      ).skip(1).map((row) => cells(row).first);

      expect(out, ['Adobe', 'Netflix', 'Spotify']);
    });
  });

  group('a cell', () {
    // A note is free text, so it can hold the separator, the quote and the row
    // ending. Any of the three written raw turns one row into two.
    test('a comma in a note does not become a new column', () {
      final row = rows(encode([item(note: 'Shared with Mai, pays half')])).last;

      expect(row, contains('"Shared with Mai, pays half"'));
      expect(cells(row).length, greaterThan(10), reason: 'raw split sees more');
    });

    test('a quote inside a note is doubled', () {
      expect(
        rows(encode([item(note: 'the "family" plan')])).last,
        contains('"the ""family"" plan"'),
      );
    });

    test('a line break inside a note stays inside its cell', () {
      final csv = encode([item(note: 'one\ntwo')]);

      expect(csv, contains('"one\ntwo"'));
    });

    // Quoting everything would be valid too, and would make the file harder to
    // read in the text editor half the point of a CSV is that it opens in.
    test('an ordinary value is not quoted', () {
      expect(rows(encode([item()])).last, startsWith('Netflix,'));
    });
  });

  group('the amount column', () {
    // The comma is the column separator here, and a spreadsheet reads
    // `260,000` as text rather than as a number.
    test('is not grouped', () {
      expect(cells(rows(encode([item()])).last)[4], '260000');
    });

    test('carries the currency in its own column, not a symbol', () {
      final row = cells(rows(encode([item()])).last);

      expect(row[4], isNot(contains('₫')));
      expect(row[5], 'VND');
    });

    test('a currency with decimals keeps them', () {
      final row = cells(
        rows(encode([item(amountMinor: 2000, currency: 'USD')])).last,
      );

      expect(row[4], '20.00');
      expect(row[5], 'USD');
    });

    // An item with no price yet is a normal item, not a broken one.
    test('an item with no amount leaves both columns empty', () {
      final row = cells(
        rows(encode([item(amountMinor: null, currency: null)])).last,
      );

      expect(row[4], '');
      expect(row[5], '');
    });
  });

  group('the columns that name something', () {
    test('the shelf comes out under its own name', () {
      expect(cells(rows(encode([item()])).last)[1], 'Streaming');
    });

    test('the interval reads as words, not as a machine value', () {
      expect(cells(rows(encode([item()])).last)[3], 'Monthly');
    });

    test('a one-off has an interval too, and it says so', () {
      expect(cells(rows(encode([item(cycle: null)])).last)[3], 'Once');
    });

    test('the payment source comes out under its name', () {
      final row = cells(
        rows(
          encode(
            [item(sourceId: 'visa')],
            sources: const [PaymentSource(id: 'visa', name: 'VCB 4412')],
          ),
        ).last,
      );

      expect(row[6], 'VCB 4412');
    });

    test('an item that pays from nothing leaves the column empty', () {
      expect(cells(rows(encode([item()])).last)[6], '');
    });

    // A source the file cannot name is a source the app has lost track of. An
    // empty cell is the honest answer; the id would be noise.
    test('a source id nothing answers to leaves the column empty', () {
      expect(cells(rows(encode([item(sourceId: 'gone')])).last)[6], '');
    });
  });

  group('trial and state', () {
    // The flag, not `isTrialOn(today)`. A file has no today in it, and the flag
    // is what the user set. See trap 14.
    test('the trial column reports the flag', () {
      expect(cells(rows(encode([item(inTrial: true)])).last)[7], 'Yes');
      expect(cells(rows(encode([item()])).last)[7], 'No');
    });

    // Cancelled and archived are different facts and the file must not merge
    // them: one is a subscription that ends, the other is a row put away.
    test('each state has its own word', () {
      String stateOf(ItemState state) =>
          cells(rows(encode([item(state: state)])).last)[8];

      expect(stateOf(ItemState.active), 'Active');
      // In brackets rather than after a comma: a comma would make the writer
      // quote this cell on every cancelled row, for nothing.
      expect(
        stateOf(ItemState.cancelledStillActive),
        'Cancelled (still usable)',
      );
      expect(stateOf(ItemState.archived), 'Archived');
    });

    // The app hides these on every screen. A file is not a screen, and someone
    // reading their own list is entitled to the parts they have put away.
    test('an archived item is in the file', () {
      final out = rows(
        encode([
          item(id: 'a', name: 'Netflix'),
          item(id: 'b', name: 'Old thing', state: ItemState.archived),
        ]),
      );

      expect(out.length, 3);
    });
  });

  group('the file name', () {
    // Local, not UTC, for the same reason the JSON backup's name is: a file
    // saved at 1am in Vietnam that files itself under yesterday is a file the
    // user will not find.
    test('is dated on the user\'s own calendar', () {
      expect(
        CsvExport.fileNameFor(DateTime(2026, 8, 27, 14, 8)),
        'subdock-2026-08-27-1408.csv',
      );
    });
  });
}
