import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:subdock/data/database.dart';

/// Opens the on-device database.
///
/// The file lives in the app's support directory rather than documents: iOS
/// backs both up to iCloud, but documents is user-visible through the Files
/// app, and a SQLite file the user can delete by hand is a support ticket
/// waiting to happen.
///
/// [fileName] exists so an on-device test can open a throwaway file through
/// this exact function. Pointing a test at its own `NativeDatabase` instead
/// would skip the two things that only break on a real file — the migration
/// and WAL — which is how the `repeatCount` crash reached a device.
///
/// [reshelve] is only read by the v6 migration, and only on a file written
/// before it. `main` passes one backed by the service catalogue, which is the
/// difference between an old Netflix row landing on Streaming and landing in
/// Other; without it the fallback is honest but blunt.
Future<SubdockDatabase> openDatabase({
  String fileName = 'subdock.sqlite',
  LegacyCategoryResolver reshelve = legacyCategoryByCode,
}) async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, fileName));

  return SubdockDatabase(
    reshelve: reshelve,
    NativeDatabase.createInBackground(
      file,
      // Everything the app does with SQLite happens off the UI isolate, so a
      // slow write cannot drop a frame.
      setup: (db) {
        // Write-ahead logging: a reader never blocks on the writer, which is
        // what keeps the list responsive while a restore is running.
        db.execute('PRAGMA journal_mode = WAL');
      },
    ),
  );
}

/// An in-memory database, for tests and for previewing a screen with sample
/// data without touching the real file.
SubdockDatabase openInMemoryDatabase() =>
    SubdockDatabase(NativeDatabase.memory());

/// Drift wants this named so `QueryExecutor` stays out of the app's imports.
typedef DatabaseConnection = QueryExecutor;
