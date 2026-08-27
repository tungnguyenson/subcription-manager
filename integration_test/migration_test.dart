import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:subdock/app.dart';
import 'package:subdock/catalog/service_catalog.dart';
import 'package:subdock/data/connection.dart';
import 'package:subdock/data/item_repository.dart';
import 'package:subdock/data/backup_store.dart';
import 'package:subdock/data/filter_store.dart';
import 'package:subdock/platform/backup_files.dart';
import 'package:subdock/platform/cloud_backup.dart';
import 'package:subdock/data/settings_store.dart';
import 'package:subdock/data/theme_store.dart';
import 'package:subdock/platform/notification_scheduler.dart';

import '../test/fixtures/schema_v1.dart';

/// Opening an upgraded file on a device, through the app's own connection.
///
/// Every other test in the suite hands the app a `NativeDatabase.memory()`,
/// which is created at the current schema and therefore never migrates. That
/// is why a migration that crashed on every existing install still had a
/// green suite: nothing opened a file that a previous version had written.
///
/// The file name is a throwaway so a test run cannot eat real data, but it
/// goes through `openDatabase` into the same directory as the real one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const probe = 'subdock_migration_probe.sqlite';

  Future<File> writeV1File() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, probe));
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${file.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }

    final raw = sqlite3.open(file.path);
    raw.execute(schemaV1);
    raw.execute(seedV1);
    raw.execute('PRAGMA user_version = 1');
    raw.close();
    return file;
  }

  testWidgets('a v1 file on disk survives being opened by the app', (
    tester,
  ) async {
    final file = await writeV1File();
    final db = await openDatabase(fileName: probe);
    addTearDown(db.close);

    final items = await ItemRepository(db).observeAll().first;
    expect(items, hasLength(2));
    expect(items.map((i) => i.name), contains('Netflix'));

    final raw = sqlite3.open(file.path);
    addTearDown(raw.close);
    expect(raw.select('PRAGMA user_version;').single['user_version'], 2);
  });

  // The crash the user hit: the form saves, the write opens the database, the
  // migration throws, and the item never lands. Only a file-backed run sees it.
  testWidgets('adding an item on top of a migrated v1 file saves it', (
    tester,
  ) async {
    await writeV1File();
    final db = await openDatabase(fileName: probe);
    addTearDown(db.close);
    final repo = ItemRepository(db);

    await tester.pumpWidget(
      SubdockApp(
        repository: repo,
        settings: SettingsStore(db),
        filters: FilterStore(db),
        themes: ThemeStore(db),
        scheduler: NotificationScheduler(),
        catalog: ServiceCatalog(const []),
        backups: BackupStore(db, repo, SettingsStore(db)),
        files: BackupFiles(),
        // Off in tests: the host has no iCloud container, and a timer
        // uploading in the background is not what any of these are about.
        cloud: CloudBackup(TargetPlatform.android),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add an item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Vehicle inspection');
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 7 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // takeException is the only thing that catches a throw inside the save
    // future; without it the failure surfaces as a silently missing row.
    expect(tester.takeException(), isNull);
    expect(await repo.observeAll().first, hasLength(3));
    expect(find.text('Vehicle inspection'), findsOneWidget);
  });
}
