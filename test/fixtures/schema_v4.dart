/// Schema v4 — the shape every already-installed copy of the app is on.
///
/// This is the migration path that matters most and is easiest to get wrong.
/// A v1 file goes through the v3 rebuild, which recreates `itemRow` at the
/// *current* schema and so picks up every later column for free. A v4 file does
/// not: it takes the `addColumn` branch, one statement per column, and a column
/// listed in the rebuild but forgotten there is invisible until a real device
/// upgrades and reads a row.
///
/// Derived from the current DDL by removing exactly what v5 adds — the
/// `paymentSourceRow` table, the four columns on `itemRow`, and the index over
/// `paymentSourceId`. Regenerate the same way against a device file with:
///   `sqlite3 "<app support>/subdock.sqlite" .schema`
const schemaV4 = r'''
CREATE TABLE "itemRow" ("id" TEXT NOT NULL PRIMARY KEY, "name" TEXT NOT NULL, "category" TEXT NOT NULL, "iconName" TEXT, "expiresOn" TEXT NOT NULL, "actByOffsetDays" INTEGER NOT NULL DEFAULT 0, "anchorDate" TEXT NOT NULL, "cycle" TEXT, "repeatCount" INTEGER, "amountMinor" INTEGER, "currency" TEXT, "actionUrl" TEXT, "actionLabel" TEXT, "note" TEXT, "leadDays" TEXT NOT NULL, "remindAt" TEXT NOT NULL, "nagAfterDue" TEXT NOT NULL, "verifyEveryDays" INTEGER, "lastVerifiedAt" TEXT, "dateSource" TEXT NOT NULL, "snoozedUntil" TEXT, "state" TEXT NOT NULL, "purchaseChannel" TEXT NOT NULL DEFAULT 'UNKNOWN', "createdAt" INTEGER NOT NULL);
CREATE INDEX item_expiresOn ON itemRow (expiresOn);
CREATE INDEX item_state ON itemRow (state);
CREATE TABLE "handledEventRow" ("id" TEXT NOT NULL PRIMARY KEY, "itemId" TEXT NOT NULL REFERENCES itemRow(id)ON DELETE CASCADE, "handledAt" INTEGER NOT NULL, "forDueDate" TEXT NOT NULL, "amountMinor" INTEGER, "currency" TEXT, "fxRateScaled" INTEGER, "fxRateScale" INTEGER, "fxRateDate" TEXT, "fxSource" TEXT, "baseAmountMinor" INTEGER, "actualChargedMinor" INTEGER);
CREATE INDEX handledEvent_itemId ON handledEventRow (itemId);
CREATE UNIQUE INDEX handledEvent_occurrence ON handledEventRow (itemId, forDueDate);
CREATE TABLE "settingRow" ("settingKey" TEXT NOT NULL PRIMARY KEY, "value" TEXT NOT NULL);
''';

/// Two items and a handled event, so the upgrade has rows to carry and a
/// foreign key to keep intact.
const seedV4 = r'''
INSERT INTO itemRow (
  id, name, category, expiresOn, actByOffsetDays, anchorDate, cycle,
  amountMinor, currency, leadDays, remindAt, nagAfterDue, dateSource, state,
  purchaseChannel, createdAt
) VALUES
  ('netflix', 'Netflix Premium', 'SUBSCRIPTION', '2026-09-01', 0, '2026-08-01',
   'MONTHLY', 260000, 'VND', '7,3', '08:30', 'NONE', 'USER_ESTIMATED',
   'ACTIVE', 'WEB', 1),
  ('evn', 'Electricity bill', 'BILL', '2026-08-20', 0, '2026-08-20',
   'MONTHLY', 842000, 'VND', '3', '08:30', 'DAILY', 'USER_CONFIRMED',
   'ACTIVE', 'UNKNOWN', 1);

INSERT INTO handledEventRow (id, itemId, handledAt, forDueDate, amountMinor, currency)
VALUES ('e1', 'netflix', 1, '2026-08-01', 260000, 'VND');
''';
