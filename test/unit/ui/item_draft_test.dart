import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/domain/instalments.dart';
import 'package:subdock/domain/local_date.dart';
import 'package:subdock/domain/model.dart';
import 'package:subdock/domain/recurrence.dart';
import 'package:subdock/ui/item_draft.dart';

void main() {
  LocalDate d(String iso) => LocalDate.parse(iso);

  /// A course paid in six monthly instalments, currently on the fourth.
  TrackedItem course() => TrackedItem(
    id: 'course',
    name: 'Course instalment',
    category: Category.bill,
    expiresOn: d('2026-08-21'),
    anchorDate: d('2026-05-21'),
    cycle: Cycle.monthly,
    repeatCount: 6,
    amountMinor: 1200000,
    currency: 'VND',
    actByOffsetDays: 2,
    leadDays: const [7, 3],
    note: 'Paid by transfer.',
    snoozedUntil: d('2026-08-19'),
  );

  group('DraftItem.of', () {
    test('carries every field the form can change', () {
      final draft = DraftItem.of(course());

      expect(draft.name, 'Course instalment');
      expect(draft.expiresOn, d('2026-08-21'));
      expect(draft.category, Category.bill);
      expect(draft.cycle, Cycle.monthly);
      expect(draft.repeatCount, 6);
      expect(draft.amountMinor, 1200000);
      expect(draft.currency, 'VND');
      expect(draft.leadDays, [7, 3]);
    });

    // The link and the note were settled when the item was created. Re-running
    // the name through the catalog would overwrite whatever the user has since
    // put there.
    test('does not re-derive the catalog match', () {
      expect(DraftItem.of(course()).matched, isNull);
    });
  });

  group('DraftItem.applyTo', () {
    test('the edited cost reaches the item', () {
      final edited = DraftItem.of(course())
          .copyForTest(amountMinor: 1500000)
          .applyTo(course());

      expect(edited.amountMinor, 1500000);
      expect(edited.currency, 'VND');
    });

    test('clearing the cost clears the currency with it', () {
      final edited = DraftItem(
        name: 'Course instalment',
        expiresOn: d('2026-08-21'),
        category: Category.bill,
        cycle: Cycle.monthly,
        repeatCount: 6,
      ).applyTo(course());

      expect(edited.amountMinor, isNull);
      expect(edited.money, isNull);
    });

    // The form asks for eight things; the item carries two dozen. Everything
    // it never showed has to come through the edit untouched.
    test('leaves the fields the form never showed alone', () {
      final edited = DraftItem.of(course())
          .copyForTest(amountMinor: 1500000)
          .applyTo(course());

      expect(edited.id, 'course');
      expect(edited.actByOffsetDays, 2);
      expect(edited.note, 'Paid by transfer.');
      expect(edited.leadDays, [7, 3]);
      expect(edited.snoozedUntil, d('2026-08-19'));
      expect(edited.dateSource, DateSource.userEstimated);
    });

    // The whole point of re-anchoring. Payment 4 of 6 has to still read 4 of 6
    // after its date is corrected.
    test('moving the due date keeps the place in a counted plan', () {
      expect(Instalments.of(course())!.index, 4);

      final edited = DraftItem.of(course())
          .copyForTest(expiresOn: d('2026-08-25'))
          .applyTo(course());

      expect(edited.expiresOn, d('2026-08-25'));
      expect(edited.anchorDate, d('2026-05-25'));
      expect(Instalments.of(edited)!.index, 4);
      expect(Instalments.of(edited)!.total, 6);
    });

    // Leaving the old anchor where it was would undo the edit on the next
    // mark-as-paid: the next occurrence is computed from the anchor's own day.
    test('the next occurrence lands on the day the user typed', () {
      final edited = DraftItem.of(course())
          .copyForTest(expiresOn: d('2026-08-25'))
          .applyTo(course());

      expect(
        Recurrence.nextDue(edited.anchorDate, edited.cycle, edited.expiresOn),
        d('2026-09-25'),
      );
    });

    test('a moved date is from memory again and drops the snooze', () {
      final edited = DraftItem.of(course())
          .copyForTest(expiresOn: d('2026-08-25'))
          .applyTo(course().copyWith(dateSource: DateSource.userConfirmed));

      expect(edited.dateSource, DateSource.userEstimated);
      expect(edited.snoozedUntil, isNull);
    });

    test('dropping the cycle drops the instalment count with it', () {
      final edited = DraftItem.of(course())
          .copyForTest(cycle: () => null)
          .applyTo(course());

      expect(edited.cycle, isNull);
      expect(edited.repeatCount, isNull);
      expect(edited.anchorDate, edited.expiresOn);
      expect(Instalments.of(edited), isNull);
    });

    // Neither is on the form and both are derived from the category, so they
    // are re-derived when the category moves.
    test('changing the category re-derives the nag and verify defaults', () {
      final edited = DraftItem.of(course())
          .copyForTest(category: Category.document)
          .applyTo(course());

      expect(edited.category, Category.document);
      expect(edited.nagAfterDue, NagPolicy.weekly);
      expect(edited.verifyEveryDays, 60);
    });

    test('keeping the category leaves an overridden nag policy in place', () {
      final overridden = course().copyWith(nagAfterDue: NagPolicy.none);
      final edited = DraftItem.of(overridden)
          .copyForTest(amountMinor: 1)
          .applyTo(overridden);

      expect(edited.nagAfterDue, NagPolicy.none);
    });

    test('a catalog match picked during the edit brings its link and note', () {
      const netflix = CatalogEntry(
        id: 'netflix',
        name: 'Netflix Premium',
        aliases: ['netflix'],
        category: Category.subscription,
        defaultCycle: Cycle.monthly,
        cancelUrl: 'https://netflix.com/cancelplan',
        noteVi: 'Huỷ trong phần Tài khoản.',
      );

      final edited = DraftItem.of(course())
          .copyForTest(matched: netflix)
          .applyTo(course());

      expect(edited.actionUrl, 'https://netflix.com/cancelplan');
      expect(edited.note, 'Huỷ trong phần Tài khoản.');
    });
  });
}

/// A test-only rebuilder. [DraftItem] has no `copyWith` in the app because
/// nothing there ever needs one — the form builds it whole.
extension on DraftItem {
  DraftItem copyForTest({
    String? name,
    LocalDate? expiresOn,
    Category? category,
    Cycle? Function()? cycle,
    int? repeatCount,
    int? amountMinor,
    String? currency,
    CatalogEntry? matched,
  }) => DraftItem(
    name: name ?? this.name,
    expiresOn: expiresOn ?? this.expiresOn,
    category: category ?? this.category,
    iconName: iconName,
    cycle: cycle != null ? cycle() : this.cycle,
    repeatCount: repeatCount ?? this.repeatCount,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency ?? this.currency,
    leadDays: leadDays,
    matched: matched ?? this.matched,
  );
}
