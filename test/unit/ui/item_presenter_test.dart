import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/item_presenter.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);
  final today = d('2026-08-15');

  TrackedItem item({
    Category category = Category.subscription,
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
    category: category,
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
          item(
            category: Category.subscription,
            amountMinor: 2000,
            currency: 'USD',
          ),
          today,
        ),
        r'Due in 2 days · 17/08 · $20.00',
      );
      expect(
        ItemPresenter.summary(
          item(amountMinor: 260000, currency: 'VND'),
          today,
        ),
        'Due in 2 days · 17/08 · 260,000 ₫',
      );
    });

    test('drops the amount clause when there is no amount', () {
      expect(
        ItemPresenter.summary(item(category: Category.document), today),
        'Expires in 2 days · 17/08',
      );
    });

    // "Due tomorrow" on a passport reads as a bill, and a passport is not
    // something the user can settle by tapping Pay.
    test('a document expires, everything else is due', () {
      expect(
        ItemPresenter.when(
          item(category: Category.document, expiresOn: '2026-08-16'),
          today,
        ),
        'Expires tomorrow',
      );
      expect(
        ItemPresenter.when(
          item(category: Category.bill, expiresOn: '2026-08-16'),
          today,
        ),
        'Due tomorrow',
      );
    });

    test('a lapsed item says how far past it is', () {
      expect(
        ItemPresenter.when(item(expiresOn: '2026-08-11'), today),
        'Overdue by 4 days',
      );
      expect(
        ItemPresenter.when(
          item(category: Category.document, expiresOn: '2026-08-14'),
          today,
        ),
        'Expired 1 day ago',
      );
    });

    test('today is named rather than counted', () {
      expect(
        ItemPresenter.when(item(expiresOn: '2026-08-15'), today),
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
    test('every category and cycle has wording', () {
      for (final category in Category.values) {
        expect(ItemPresenter.categoryLabel(category), isNotEmpty);
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

    // The five the hand-off names, in its wording. "Other" is a real choice
    // the user makes, not the fallback an unrecognised value lands in.
    test('the categories read as the hand-off writes them', () {
      expect(Category.values.map(ItemPresenter.categoryLabel), [
        'Subscription',
        'Bill',
        'Insurance',
        'Document',
        'Other',
      ]);
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
    expect(ItemPresenter.deleteConsequence(4), contains('stays under Money'));
    expect(ItemPresenter.deleteConsequence(1), contains('1 pending reminder.'));
    expect(
      ItemPresenter.deleteConsequence(0),
      contains('No reminders are pending'),
    );
  });
}
