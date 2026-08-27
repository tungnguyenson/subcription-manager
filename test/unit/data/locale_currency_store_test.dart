import 'package:drift/drift.dart' show Value, InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/currency_store.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/locale_store.dart';
import 'package:subdock/i18n.dart';

void main() {
  late SubdockDatabase db;
  late LocaleStore locales;
  late CurrencyStore currencies;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    locales = LocaleStore(db);
    currencies = CurrencyStore(db);
  });

  tearDown(() => db.close());

  group('the language', () {
    // Null, not English. Onboarding has to tell "never asked" from "asked, and
    // they said English"; a store that defaulted to a language would tell it
    // the question was already settled.
    test('is unanswered until the user answers it', () async {
      expect(await locales.read(), isNull);
    });

    test('every choice survives the round trip', () async {
      for (final locale in AppLocale.values) {
        await locales.save(locale);
        expect(await locales.read(), locale);
      }
    });

    test('is stored by its code, not by its position', () async {
      await locales.save(AppLocale.vi);

      final rows = await db.selectAllSettings().get();
      expect(rows.firstWhere((r) => r.settingKey == 'app_locale').value, 'vi');
    });

    test('a code this build does not know reads as unanswered', () async {
      await db
          .into(db.settingRow)
          .insert(
            SettingRowCompanion(
              settingKey: const Value('app_locale'),
              value: const Value('ko'),
            ),
            mode: InsertMode.insertOrReplace,
          );

      expect(await locales.read(), isNull);
    });
  });

  group('the currency', () {
    test('is unanswered until the user answers it', () async {
      expect(await currencies.read(), isNull);
    });

    test('survives the round trip, upper-cased', () async {
      await currencies.save('usd');
      expect(await currencies.read(), 'USD');
    });

    // A three-letter code this build has never heard of is still a currency.
    // Refusing it would strand anyone whose choice was written by a later
    // build with a longer list.
    test('a code outside the catalogue still reads back', () async {
      await currencies.save('XPF');
      expect(await currencies.read(), 'XPF');
    });

    test('anything that is not a code at all reads as unanswered', () async {
      await db
          .into(db.settingRow)
          .insert(
            SettingRowCompanion(
              settingKey: const Value('base_currency'),
              value: const Value('dollars'),
            ),
            mode: InsertMode.insertOrReplace,
          );

      expect(await currencies.read(), isNull);
    });

    // Offered, never applied. The picker still shows what is selected and the
    // user still has to press on.
    test('the guess off the phone region is only a starting point', () {
      expect(CurrencyStore.suggestFor('VN'), 'VND');
      expect(CurrencyStore.suggestFor('de'), 'EUR');
      expect(CurrencyStore.suggestFor(null), 'VND');
      expect(CurrencyStore.suggestFor('ZZ'), 'VND');
    });
  });
}
