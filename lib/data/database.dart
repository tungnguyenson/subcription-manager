import 'package:drift/drift.dart';

part 'database.g.dart';

/// The SQLite database, generated from `tables.drift`.
///
/// The connection is passed in rather than opened here so tests can hand it an
/// in-memory database and the app can hand it a file inside the App Group
/// container. See `connection_native.dart`.
@DriftDatabase(include: {'tables.drift'})
class SubdockDatabase extends _$SubdockDatabase {
  SubdockDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // The settings table arrived in v2 and nothing else touches it.
      if (from < 2) await m.createTable(settingRow);

      // v3 rebuilds itemRow, and one rebuild covers every version before it:
      // the risk axis (v1), the two overlapping classification columns, and
      // groups. Rebuilding twice would copy every row twice for no gain, and
      // drift's `alterTable` always targets the *current* schema anyway — a
      // v1 -> v2 step written against the old shape cannot survive a later
      // column rename.
      //
      // Dropping columns is worth the rebuild rather than leaving dead ones
      // behind: a NOT NULL column nothing writes to still has to be supplied
      // on every insert, so it keeps a removed concept alive in the write
      // path forever.
      if (from < 3) {
        // Fold `kind` and `categoryId` into one value while both still exist.
        // Order matters, and neither column is sufficient alone: `kind` is the
        // only place a document is named, and `categoryId` is the only place
        // insurance is.
        await customStatement("""
          UPDATE itemRow SET kind = CASE
            WHEN categoryId = 'insurance'               THEN 'INSURANCE'
            WHEN kind = 'DOCUMENT'                      THEN 'DOCUMENT'
            WHEN kind = 'BILL'                          THEN 'BILL'
            WHEN categoryId IN ('home_bills', 'loans')  THEN 'BILL'
            ELSE 'SUBSCRIPTION'
          END
        """);

        // Drop the index on the way out. `alterTable` saves and replays the
        // indexes it finds attached to the table, so an index over a column
        // this rebuild removes would be replayed against a table that no
        // longer has it.
        await customStatement('DROP INDEX IF EXISTS item_groupId');

        // `newColumns` is not optional. Without it drift copies every column
        // of the current schema out of the old table and the rebuild dies on
        // the first one that was not there yet; listing them tells drift to
        // leave them NULL for existing rows instead of reading them.
        // `category` is not among them — the transformer supplies it.
        await m.alterTable(
          TableMigration(
            itemRow,
            columnTransformer: {
              itemRow.category: const CustomExpression<String>('kind'),
            },
            newColumns: [
              if (from < 2) itemRow.repeatCount,
              itemRow.iconName,
              itemRow.snoozedUntil,
              // Every column added after v3 has to be listed here too, not just
              // in its own step below. This rebuild copies the *current*
              // schema out of the old table, so a column the old file never
              // had makes the SELECT fail on a name that does not exist there.
              itemRow.purchaseChannel,
            ],
          ),
        );

        // Nothing points at it any more, so it can go.
        await m.deleteTable('itemGroupRow');
      }

      // v4 adds where the subscription was bought. A plain addColumn is enough
      // because the column has a default: existing rows become UNKNOWN, which
      // is exactly what is true of them -- nobody was ever asked.
      //
      // Only for a file that is already at v3. Anything older went through the
      // rebuild above, which recreated the table at the current schema and so
      // already has this column; adding it twice fails on a duplicate name.
      if (from >= 3 && from < 4) {
        await m.addColumn(itemRow, itemRow.purchaseChannel);
      }
    },
    beforeOpen: (details) async {
      // SQLite does not enforce foreign keys unless asked, and the setting
      // is per connection rather than stored in the file. Without this,
      // deleting an item leaves its history rows behind pointing at
      // nothing, and deleting a group leaves its items pointing at a row
      // that no longer exists. Nothing reports either.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
