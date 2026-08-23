/// Schema v1, dumped verbatim off a real device database (`user_version = 1`).
///
/// It exists nowhere else: v1 was never committed, so the only copies are on
/// already-installed devices. Writing this DDL from memory is what let the
/// `repeatCount` crash ship — the guess invented a `riskLevel` column and
/// missed `stake`, the column v2 actually drops.
///
/// Regenerate against a device file with:
///   `sqlite3 "<app support>/subdock.sqlite" .schema`
const schemaV1 = r'''
CREATE TABLE IF NOT EXISTS "itemGroupRow" ("id" TEXT NOT NULL PRIMARY KEY, "name" TEXT NOT NULL, "kind" TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS "itemRow" ("id" TEXT NOT NULL PRIMARY KEY, "name" TEXT NOT NULL, "groupId" TEXT REFERENCES itemGroupRow(id)ON DELETE SET NULL, "kind" TEXT NOT NULL, "stake" TEXT NOT NULL, "categoryId" TEXT, "expiresOn" TEXT NOT NULL, "actByOffsetDays" INTEGER NOT NULL DEFAULT 0, "anchorDate" TEXT NOT NULL, "cycle" TEXT, "amountMinor" INTEGER, "currency" TEXT, "actionUrl" TEXT, "actionLabel" TEXT, "note" TEXT, "leadDays" TEXT NOT NULL, "remindAt" TEXT NOT NULL, "nagAfterDue" TEXT NOT NULL, "verifyEveryDays" INTEGER, "lastVerifiedAt" TEXT, "dateSource" TEXT NOT NULL, "state" TEXT NOT NULL, "createdAt" INTEGER NOT NULL);
CREATE INDEX item_expiresOn ON itemRow (expiresOn);
CREATE INDEX item_state ON itemRow (state);
CREATE INDEX item_groupId ON itemRow (groupId);
CREATE TABLE IF NOT EXISTS "handledEventRow" ("id" TEXT NOT NULL PRIMARY KEY, "itemId" TEXT NOT NULL REFERENCES itemRow(id)ON DELETE CASCADE, "handledAt" INTEGER NOT NULL, "forDueDate" TEXT NOT NULL, "amountMinor" INTEGER, "currency" TEXT, "fxRateScaled" INTEGER, "fxRateScale" INTEGER, "fxRateDate" TEXT, "fxSource" TEXT, "baseAmountMinor" INTEGER, "actualChargedMinor" INTEGER);
CREATE INDEX handledEvent_itemId ON handledEventRow (itemId);
CREATE UNIQUE INDEX handledEvent_occurrence ON handledEventRow (itemId, forDueDate);
''';

/// One row of every shape the migration has to carry across: a grouped item, a
/// standalone one, a row whose category is the only thing that says what it
/// really is, and a handled event hanging off a foreign key.
const seedV1 = r'''
INSERT INTO itemGroupRow (id, name, kind) VALUES ('sim1', 'SIM Viettel', 'SIM');

INSERT INTO itemRow (
  id, name, groupId, kind, stake, categoryId, expiresOn, actByOffsetDays,
  anchorDate, cycle, amountMinor, currency, leadDays, remindAt, nagAfterDue,
  dateSource, state, createdAt
) VALUES
  ('netflix', 'Netflix', NULL, 'RECURRING', 'HIGH', 'entertainment',
   '2026-09-01', 0, '2026-08-01', 'MONTHLY', 26000000, 'VND', '7,1', '09:00',
   'true', 'MANUAL', 'ACTIVE', 1),
  ('hsd', 'SIM validity', 'sim1', 'PREPAID', 'LOW', 'telecom', '2026-08-12', 0,
   '2026-08-12', NULL, NULL, NULL, '7', '09:00', 'false', 'MANUAL',
   'ACTIVE', 1),
  ('pvi', 'Car insurance', NULL, 'RECURRING', 'LOW', 'insurance',
   '2027-01-10', 0, '2027-01-10', 'YEARLY', 480000000, 'VND', '7', '09:00',
   'false', 'MANUAL', 'ACTIVE', 1);

INSERT INTO handledEventRow (id, itemId, handledAt, forDueDate, amountMinor,
  currency) VALUES ('e1', 'netflix', 1, '2026-08-01', 26000000, 'VND');
''';
