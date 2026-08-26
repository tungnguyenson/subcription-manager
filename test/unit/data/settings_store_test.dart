import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subdock/data/database.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/domain/local_date.dart';

void main() {
  late SubdockDatabase db;
  late SettingsStore store;

  setUp(() {
    db = SubdockDatabase(NativeDatabase.memory());
    store = SettingsStore(db);
  });

  tearDown(() => db.close());

  test('nothing stored reads back as the defaults', () async {
    final settings = await store.read();

    expect(settings.defaultLeadDays, const AppSettings().defaultLeadDays);
    expect(settings.defaultSourceId, isNull);
  });

  test('every value survives the round trip', () async {
    await store.save(
      const AppSettings(
        defaultLeadDays: [7, 1],
        remindAt: LocalTime(21, 15),
        defaultSourceId: 'src42',
      ),
    );

    final read = await store.read();
    expect(read.defaultLeadDays, [7, 1]);
    expect(read.remindAt, const LocalTime(21, 15));
    expect(read.defaultSourceId, 'src42');
  });

  // The table only ever writes and replaces, so the empty case is a row
  // holding an empty string rather than a missing key. An id is a microsecond
  // timestamp and cannot collide with it.
  test('the default source can be cleared again', () async {
    await store.save(const AppSettings(defaultSourceId: 'src42'));
    await store.save((await store.read()).withDefaultSource(null));

    expect((await store.read()).defaultSourceId, isNull);
  });

  // Every `with…` returns a whole settings object, so one that forgot to carry
  // a field would silently reset it on the next save.
  test('changing one value leaves the others alone', () async {
    const settings = AppSettings(
      defaultLeadDays: [7],
      remindAt: LocalTime(9, 0),
      defaultSourceId: 'src42',
    );

    expect(settings.withLead(3, true).defaultSourceId, 'src42');
    expect(
      settings.withRemindAt(const LocalTime(10, 0)).defaultSourceId,
      'src42',
    );
    expect(settings.withDefaultSource('src9').defaultLeadDays, [7]);
    expect(settings.withDefaultSource('src9').remindAt, const LocalTime(9, 0));
  });
}
