/// Schema v6 — the shape every already-installed copy of the app is on today.
///
/// v7 is the first migration that has to *read* an old column and write its
/// meaning into a new one: `trialStart` becomes the `inTrial` flag. Neither
/// older fixture can prove that. A v1 file goes through the v3 rebuild, which
/// recreates `itemRow` at the current schema, and a v4 file predates trials
/// altogether — in both, every row is correctly not in a trial no matter what
/// the backfill does, so a backfill that did nothing would pass.
///
/// Derived from the current DDL by putting back exactly what v7 replaced: the
/// `inTrial` column becomes `trialStart TEXT` in the same position. Regenerate
/// the same way against a device file with:
///   `sqlite3 "<app support>/subdock.sqlite" .schema`
const schemaV6 = r'''
CREATE TABLE "paymentSourceRow" ("id" TEXT NOT NULL PRIMARY KEY, "name" TEXT NOT NULL, "glyph" TEXT NOT NULL, "createdAt" INTEGER NOT NULL);
CREATE TABLE "categoryRow" ("id" TEXT NOT NULL PRIMARY KEY, "label" TEXT NOT NULL, "iconName" TEXT, "wording" TEXT NOT NULL, "nag" TEXT NOT NULL, "leadDays" TEXT NOT NULL, "verifyEveryDays" INTEGER, "countsTowardSpend" INTEGER NOT NULL DEFAULT TRUE, "builtIn" INTEGER NOT NULL DEFAULT FALSE, "sortOrder" INTEGER NOT NULL);
CREATE TABLE "itemRow" ("id" TEXT NOT NULL PRIMARY KEY, "name" TEXT NOT NULL, "category" TEXT NOT NULL REFERENCES categoryRow(id), "iconName" TEXT, "expiresOn" TEXT NOT NULL, "actByOffsetDays" INTEGER NOT NULL DEFAULT 0, "anchorDate" TEXT NOT NULL, "cycle" TEXT, "repeatCount" INTEGER, "amountMinor" INTEGER, "currency" TEXT, "actionUrl" TEXT, "actionLabel" TEXT, "note" TEXT, "leadDays" TEXT NOT NULL, "remindAt" TEXT NOT NULL, "nagAfterDue" TEXT NOT NULL, "verifyEveryDays" INTEGER, "lastVerifiedAt" TEXT, "dateSource" TEXT NOT NULL, "snoozedUntil" TEXT, "state" TEXT NOT NULL, "trialStart" TEXT, "paymentSourceId" TEXT REFERENCES paymentSourceRow(id)ON DELETE SET NULL, "paused" INTEGER NOT NULL DEFAULT FALSE, "yearlyChoice" TEXT, "purchaseChannel" TEXT NOT NULL DEFAULT 'UNKNOWN', "createdAt" INTEGER NOT NULL);
CREATE INDEX item_expiresOn ON itemRow (expiresOn);
CREATE INDEX item_paymentSourceId ON itemRow (paymentSourceId);
CREATE INDEX item_state ON itemRow (state);
CREATE INDEX item_category ON itemRow (category);
CREATE TABLE "handledEventRow" ("id" TEXT NOT NULL PRIMARY KEY, "itemId" TEXT NOT NULL REFERENCES itemRow(id)ON DELETE CASCADE, "handledAt" INTEGER NOT NULL, "forDueDate" TEXT NOT NULL, "amountMinor" INTEGER, "currency" TEXT, "fxRateScaled" INTEGER, "fxRateScale" INTEGER, "fxRateDate" TEXT, "fxSource" TEXT, "baseAmountMinor" INTEGER, "actualChargedMinor" INTEGER);
CREATE INDEX handledEvent_itemId ON handledEventRow (itemId);
CREATE UNIQUE INDEX handledEvent_occurrence ON handledEventRow (itemId, forDueDate);
CREATE TABLE "settingRow" ("settingKey" TEXT NOT NULL PRIMARY KEY, "value" TEXT NOT NULL);
''';

/// One shelf and two items: one carrying a trial start date, one not. The pair
/// is the point — a backfill that sets the flag on everything, or on nothing,
/// fails on exactly one of them.
///
/// A handled event hangs off the trial row so the rebuild that drops
/// `trialStart` has a foreign key to keep intact while it copies the table.
const seedV6 = r'''
INSERT INTO categoryRow (
  id, label, wording, nag, leadDays, countsTowardSpend, builtIn, sortOrder
) VALUES ('STREAMING', 'Streaming', 'DUE', 'ONCE', '7,3,1', 1, 1, 0);

INSERT INTO itemRow (
  id, name, category, expiresOn, actByOffsetDays, anchorDate, cycle,
  amountMinor, currency, leadDays, remindAt, nagAfterDue, dateSource, state,
  trialStart, paused, purchaseChannel, createdAt
) VALUES (
  'claude', 'Claude Pro', 'STREAMING', '2026-09-05', 0, '2026-09-05', 'MONTHLY',
  520000, 'VND', '7,3,1', '09:00', 'ONCE', 'USER_ESTIMATED', 'ACTIVE',
  '2026-08-22', 0, 'UNKNOWN', 1750000000
);

INSERT INTO itemRow (
  id, name, category, expiresOn, actByOffsetDays, anchorDate, cycle,
  amountMinor, currency, leadDays, remindAt, nagAfterDue, dateSource, state,
  trialStart, paused, purchaseChannel, createdAt
) VALUES (
  'netflix', 'Netflix Premium', 'STREAMING', '2026-09-01', 0, '2026-09-01',
  'MONTHLY', 260000, 'VND', '7,3,1', '09:00', 'ONCE', 'USER_ESTIMATED',
  'ACTIVE', NULL, 0, 'UNKNOWN', 1750000000
);

INSERT INTO handledEventRow (id, itemId, handledAt, forDueDate)
VALUES ('e1', 'claude', 1750000000, '2026-08-05');
''';
