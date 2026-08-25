import 'package:drift/drift.dart';

import 'package:subdock/domain/default_categories.dart';

import 'mappers.dart';

part 'database.g.dart';

/// Works out which shelf an item written before v6 belongs on, from its name
/// and the classification it carried.
///
/// A function passed in rather than a table compiled into the migration,
/// because the good answer needs the service catalogue and the catalogue is a
/// bundled asset the data layer cannot read. `main` hands in one backed by it;
/// anything that does not gets [legacyCategoryByCode], which is right about the
/// paperwork shelves and honest about the rest.
typedef LegacyCategoryResolver = String Function(
  String itemName,
  String legacyCategory,
);

/// The fallback mapping from the five-value classification to a shelf.
///
/// `DOCUMENT`, `INSURANCE` and `SIM` each had exactly one shelf they could mean
/// and land on it. `BILL` and `SUBSCRIPTION` spanned four and seventeen, so
/// without the catalogue there is nothing to go on: bills go to the shelf that
/// held three quarters of them and everything else goes to Other rather than
/// being scattered by a guess. The user moves them in one tap, and a wrong
/// shelf they can see beats a right one they cannot check.
String legacyCategoryByCode(String itemName, String legacyCategory) =>
    switch (legacyCategory) {
      'DOCUMENT' => 'DOCUMENTS',
      'INSURANCE' => 'INSURANCE',
      'SIM' => 'PHONE',
      'BILL' => 'UTILITIES',
      _ => fallbackCategoryId,
    };

/// The SQLite database, generated from `tables.drift`.
///
/// The connection is passed in rather than opened here so tests can hand it an
/// in-memory database and the app can hand it a file inside the App Group
/// container. See `connection_native.dart`.
@DriftDatabase(include: {'tables.drift'})
class SubdockDatabase extends _$SubdockDatabase {
  /// [reshelve] is only ever called by the v6 migration, on a file that
  /// predates the category table. A fresh install never reaches it.
  SubdockDatabase(super.executor, {this.reshelve = legacyCategoryByCode});

  final LegacyCategoryResolver reshelve;

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    onUpgrade: (m, from, to) async {
      // First, before anything that rebuilds itemRow. A rebuild recreates the
      // table at the *current* schema, where `category` carries a REFERENCES
      // clause -- so the table it points at has to exist and be populated by
      // then, or the rebuilt rows point at nothing.
      if (from < 6) {
        await m.createTable(categoryRow);
        await _seedCategories();
      }

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
              itemRow.trialStart,
              itemRow.paymentSourceId,
              itemRow.paused,
              itemRow.yearlyChoice,
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

      // v5 adds free trials, payment sources and the per-item pause.
      //
      // The table comes first: `paymentSourceId` carries a REFERENCES clause,
      // and SQLite resolves it lazily, but a file where the target does not
      // exist yet is one the next `PRAGMA foreign_key_check` fails on. It is
      // created for every upgrade path -- the v3 rebuild above recreates
      // *itemRow*, not this.
      if (from < 5) {
        await m.createTable(paymentSourceRow);
      }

      // The three columns, only for a file already past the rebuild. Anything
      // older came out of `alterTable` at the current schema and already has
      // them; adding one twice fails on a duplicate name.
      //
      // `paused` and `paymentSourceId` are both safe as plain addColumn:
      // SQLite allows ADD COLUMN with a REFERENCES clause as long as the
      // default is NULL, which it is, and `paused` carries DEFAULT 0 so
      // existing rows read as "not paused" -- which is true of all of them.
      if (from >= 3 && from < 5) {
        await m.addColumn(itemRow, itemRow.trialStart);
        await m.addColumn(itemRow, itemRow.paymentSourceId);
        await m.addColumn(itemRow, itemRow.paused);
        await m.addColumn(itemRow, itemRow.yearlyChoice);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS item_paymentSourceId '
          'ON itemRow(paymentSourceId)',
        );
      }

      // v6 turns the classification into a shelf the user owns. The column
      // keeps its name and its type and changes what the text in it means:
      // from one of five words the app knew, to a row id it does not.
      if (from < 6) {
        // Row by row rather than one UPDATE, because the answer depends on the
        // item's *name* -- 'SUBSCRIPTION' alone cannot say whether Spotify
        // belongs on Music or on Streaming, and only the catalogue can.
        final rows = await customSelect(
          'SELECT id, name, category FROM itemRow',
        ).get();
        for (final row in rows) {
          final shelf = reshelve(
            row.read<String>('name'),
            row.read<String>('category'),
          );
          await customStatement(
            'UPDATE itemRow SET category = ? WHERE id = ?',
            [shelf, row.read<String>('id')],
          );
        }

        // The foreign key itself only arrives with a rebuild: SQLite cannot add
        // one to an existing column. Files older than v3 already got it from
        // the rebuild above, which recreated the table at the current schema;
        // rebuilding those a second time would copy every row again for
        // nothing.
        if (from >= 3) {
          await m.alterTable(TableMigration(itemRow));
          await customStatement(
            'CREATE INDEX IF NOT EXISTS item_category ON itemRow(category)',
          );
        }
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

  /// Writes the shipped shelves. Insert-or-ignore so that re-running it can
  /// never overwrite a label or a nag setting the user has since changed.
  Future<void> _seedCategories() async {
    for (final category in defaultCategories) {
      await into(categoryRow)
          .insert(category.toCompanion(), mode: InsertMode.insertOrIgnore);
    }
  }
}
