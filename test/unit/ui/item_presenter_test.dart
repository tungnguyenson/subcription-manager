import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/category_book.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/item_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-15');

  Category shelfOf(TrackedItem item) => CategoryBook.shipped[item.categoryId];

  TrackedItem item({
    String categoryId = 'STREAMING',
    String expiresOn = '2026-08-17',
    String? anchorDate,
    int actByOffsetDays = 0,
    int? amountMinor,
    String? currency,
    Cycle? cycle,
    int? repeatCount,
  }) => TrackedItem(
    id: 'x',
    name: 'x',
    categoryId: categoryId,
    expiresOn: d(expiresOn),
    actByOffsetDays: actByOffsetDays,
    anchorDate: d(anchorDate ?? expiresOn),
    cycle: cycle,
    repeatCount: repeatCount,
    amountMinor: amountMinor,
    currency: currency,
  );

  group('summary', () {
    test('says how soon, exactly when, and for how much', () {
      expect(
        ItemPresenter.summary(
          item(categoryId: 'STREAMING', amountMinor: 2000, currency: 'USD'),
          shelfOf(
            item(categoryId: 'STREAMING', amountMinor: 2000, currency: 'USD'),
          ),
          today,
        ),
        r'Due in 2 days · 17/08 · $20.00',
      );
      expect(
        ItemPresenter.summary(
          item(amountMinor: 260000, currency: 'VND'),
          shelfOf(item(amountMinor: 260000, currency: 'VND')),
          today,
        ),
        'Due in 2 days · 17/08 · 260,000 ₫',
      );
    });

    test('drops the amount clause when there is no amount', () {
      expect(
        ItemPresenter.summary(
          item(categoryId: 'DOCUMENTS'),
          shelfOf(item(categoryId: 'DOCUMENTS')),
          today,
        ),
        'Expires in 2 days · 17/08',
      );
    });

    // "Due tomorrow" on a passport reads as a bill, and a passport is not
    // something the user can settle by tapping Pay.
    test('a document expires, everything else is due', () {
      expect(
        ItemPresenter.when(
          item(categoryId: 'DOCUMENTS', expiresOn: '2026-08-16'),
          shelfOf(item(categoryId: 'DOCUMENTS', expiresOn: '2026-08-16')),
          today,
        ),
        'Expires tomorrow',
      );
      expect(
        ItemPresenter.when(
          item(categoryId: 'UTILITIES', expiresOn: '2026-08-16'),
          shelfOf(item(categoryId: 'UTILITIES', expiresOn: '2026-08-16')),
          today,
        ),
        'Due tomorrow',
      );
    });

    test('a lapsed item says how far past it is', () {
      expect(
        ItemPresenter.when(
          item(expiresOn: '2026-08-11'),
          shelfOf(item(expiresOn: '2026-08-11')),
          today,
        ),
        'Overdue by 4 days',
      );
      expect(
        ItemPresenter.when(
          item(categoryId: 'DOCUMENTS', expiresOn: '2026-08-14'),
          shelfOf(item(categoryId: 'DOCUMENTS', expiresOn: '2026-08-14')),
          today,
        ),
        'Expired 1 day ago',
      );
    });

    test('today is named rather than counted', () {
      expect(
        ItemPresenter.when(
          item(expiresOn: '2026-08-15'),
          shelfOf(item(expiresOn: '2026-08-15')),
          today,
        ),
        'Due today',
      );
    });
  });

  group('repeats', () {
    test('an open-ended cycle names only the cycle', () {
      expect(ItemPresenter.repeatLabel(item(cycle: Cycle.monthly)), 'Monthly');
      expect(ItemPresenter.repeatLabel(item()), 'Once');
    });

    test('a limited cycle names how many times', () {
      expect(
        ItemPresenter.repeatLabel(item(cycle: Cycle.monthly, repeatCount: 6)),
        'Monthly · 6 times',
      );
    });

    // The pips say the shape of it at a glance; this line says it in a form a
    // screen reader can read and a hurried reader can trust.
    test('the instalment line accounts for every payment', () {
      expect(
        ItemPresenter.instalmentLine(const Instalments(index: 4, total: 6)),
        '3 paid · this one due · 2 left',
      );
      expect(
        ItemPresenter.instalmentLine(const Instalments(index: 1, total: 6)),
        'this one due · 5 left',
      );
      expect(
        ItemPresenter.instalmentLine(const Instalments(index: 6, total: 6)),
        '5 paid · this one due · last one',
      );
    });
  });

  group('labels', () {
    test('every shelf and cycle has wording', () {
      for (final category in CategoryBook.shipped.all) {
        expect(category.label, isNotEmpty);
      }
      for (final cycle in [null, ...Cycle.values]) {
        expect(ItemPresenter.cycleLabel(cycle), isNotEmpty);
      }
    });

    test('a one-off cost carries no per-cycle suffix', () {
      expect(ItemPresenter.cyclePer(null), isNull);
      expect(ItemPresenter.cyclePer(Cycle.monthly), '/ mo');
      expect(ItemPresenter.cyclePer(Cycle.yearly), '/ yr');
    });

    // An interval the app has no name for still has to read as one, and read
    // back in the unit it was typed in: "every 2 weeks", never "every 14 days".
    test('a custom interval is spelled out rather than left blank', () {
      expect(
        ItemPresenter.cycleLabel(Cycle.every(5, CycleField.month)),
        'Every 5 months',
      );
      expect(
        ItemPresenter.cycleLabel(Cycle.every(2, CycleField.week)),
        'Every 2 weeks',
      );
      expect(
        ItemPresenter.cycleLabel(Cycle.every(45, CycleField.day)),
        'Every 45 days',
      );
      expect(
        ItemPresenter.cyclePer(Cycle.every(5, CycleField.month)),
        '/ 5 mo',
      );
      expect(
        ItemPresenter.cycleEveryShort(Cycle.every(2, CycleField.week)),
        '2 wk',
      );
    });

    // A cycle of one is still "every month", not "every 1 months".
    test('a step of one keeps the noun singular', () {
      expect(ItemPresenter.cycleEvery(Cycle.monthly), 'month');
      expect(ItemPresenter.cycleEvery(Cycle.weekly), 'week');
    });

    // The app only knows what the user typed. A date shown with more
    // confidence than its source deserves is what this label prevents.
    test(
      'date provenance is spelled out, never abbreviated to a checkmark',
      () {
        expect(
          ItemPresenter.dateSourceLabel(DateSource.userConfirmed),
          'confirmed with the provider',
        );
        expect(
          ItemPresenter.dateSourceLabel(DateSource.userEstimated),
          'from memory',
        );
        expect(
          ItemPresenter.dateSourceLabel(DateSource.extracted),
          contains('not checked'),
        );
      },
    );

    // The shipped shelves, in the order they are offered. Every one is a
    // label the user can change, so this pins what the app *ships* with rather
    // than anything it depends on.
    test('the shipped shelves lead with the ones people add most', () {
      expect(CategoryBook.shipped.all.take(6).map((c) => c.label), [
        'Streaming',
        'Music',
        'AI and tools',
        'Cloud storage',
        'Productivity',
        'Mobile and SIM',
      ]);
      expect(CategoryBook.shipped.all.last.label, 'Other');
    });

    test('lead days read as chips, with zero and one spelled out', () {
      expect(ItemPresenter.leadLabels([14, 3, 1, 0]), [
        '14 days before',
        '3 days before',
        '1 day before',
        'On the day',
      ]);
      expect(ItemPresenter.leadLabels([]), isEmpty);
    });
  });

  // Deleting also removes pending reminders, which the user cannot see. Saying
  // so makes the confirmation informed rather than reflexive.
  test('the delete warning names both consequences', () {
    expect(
      ItemPresenter.deleteConsequence(4),
      contains('Removes 4 pending reminders'),
    );
    expect(ItemPresenter.deleteConsequence(1), contains('1 pending reminder.'));
    expect(
      ItemPresenter.deleteConsequence(0),
      contains('No reminders are pending'),
    );
  });

  // The old wording ended with "What you have already paid stays under
  // Spending", and the schema says otherwise: handledEventRow cascades away
  // with the item. A line that promises a safety net which is not there is
  // worse than no line, because it is read right before the tap.
  test('the delete warning does not promise the payments survive', () {
    for (final count in [0, 1, 4]) {
      final line = ItemPresenter.deleteConsequence(count);
      expect(line, isNot(contains('stays under Spending')));
      expect(line, contains('recorded payments go too'));
    }
  });

  // A SIM is the case the whole app exists for: letting a prepaid one lapse
  // costs a phone number, which no refund returns. Nothing in the code knows
  // that any more -- it is the shipped settings on the shelf SIMs go on, and
  // the user can change every one of them.
  group('a SIM', () {
    TrackedItem sim(String expiresOn) => TrackedItem(
      id: 'viettel',
      name: 'Viettel 0912 345 678',
      categoryId: 'PHONE',
      expiresOn: LocalDate.parse(expiresOn),
      anchorDate: LocalDate.parse(expiresOn),
    );

    // "Due in 4 days" reads as a bill the user could pay late without losing
    // anything, and losing the number is exactly what happens.
    test('expires rather than falls due', () {
      final today = LocalDate.parse('2026-08-15');

      expect(
        ItemPresenter.when(
          sim('2026-08-19'),
          shelfOf(sim('2026-08-19')),
          today,
        ),
        'Expires in 4 days',
      );
      expect(
        ItemPresenter.when(
          sim('2026-08-15'),
          shelfOf(sim('2026-08-15')),
          today,
        ),
        'Expires today',
      );
      expect(
        ItemPresenter.when(
          sim('2026-08-11'),
          shelfOf(sim('2026-08-11')),
          today,
        ),
        'Expired 4 days ago',
      );
    });

    test('nags daily once the date has gone by, the way a bill does', () {
      expect(CategoryBook.shipped['PHONE'].nag, NagPolicy.daily);
    });

    // Time Sensitive gets past Focus and Do Not Disturb. A subscription
    // renewing is news; this is a deadline with a consequence.
    test('its reminders get past Focus', () {
      expect(CategoryBook.shipped['PHONE'].isTimeSensitive, isTrue);
    });
  });
}
