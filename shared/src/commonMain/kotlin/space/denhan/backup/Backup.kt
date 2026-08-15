package space.denhan.backup

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import space.denhan.domain.HandledEvent
import space.denhan.domain.ItemGroup
import space.denhan.domain.SimProfile
import space.denhan.domain.TrackedItem

/**
 * Export and restore.
 *
 * Ships in the first release, not as later polish. Losing hand-typed data is the
 * most common reason people abandon this category of app, and that is true even
 * of the ones that sync; an offline app with no account has strictly worse odds.
 * "There is no way to get my data out" is separately cited as an uninstall
 * reason. See product-spec.md section 11.2.
 *
 * JSON is the restorable format. CSV is export-only, for spreadsheets.
 */
@Serializable
data class BackupFile(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val exportedAt: String,
    val items: List<BackupItem>,
    val groups: List<BackupGroup>,
    val sims: List<BackupSim>,
    val history: List<BackupEvent>,
) {
    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

@Serializable
data class BackupItem(
    val id: String,
    val name: String,
    val groupId: String? = null,
    val kind: String,
    val stake: String,
    val categoryId: String? = null,
    val expiresOn: String,
    val actByOffsetDays: Int = 0,
    val anchorDate: String,
    val cycle: String? = null,
    val amountMinor: Long? = null,
    val currency: String? = null,
    val actionUrl: String? = null,
    val actionLabel: String? = null,
    val note: String? = null,
    val leadDays: List<Int> = emptyList(),
    val remindAt: String,
    val nagAfterDue: String,
    val verifyEveryDays: Int? = null,
    val lastVerifiedAt: String? = null,
    val dateSource: String,
    val state: String,
)

@Serializable
data class BackupGroup(val id: String, val name: String, val kind: String)

@Serializable
data class BackupSim(
    val groupId: String,
    val carrier: String,
    val msisdn: String,
    val isDormant: Boolean = false,
    val hsdConfirmedDate: String? = null,
    val hsdConfirmedAt: String? = null,
    val identityVerified: String = "UNKNOWN",
    val identityCheckedAt: String? = null,
    val lastDeviceChangeAt: String? = null,
    val retentionPackage: String? = null,
    val retentionExpiryDate: String? = null,
)

@Serializable
data class BackupEvent(
    val id: String,
    val itemId: String,
    val handledAt: Long,
    val forDueDate: String,
    val amountMinor: Long? = null,
    val currency: String? = null,
    val fxRateScaled: Long? = null,
    val fxRateScale: Int? = null,
    val fxRateDate: String? = null,
    val fxSource: String? = null,
    val baseAmountMinor: Long? = null,
    val actualChargedMinor: Long? = null,
)

object Backup {

    private val json = Json {
        prettyPrint = true
        // A file written by a newer build must still restore on an older one
        // rather than failing outright.
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun encode(file: BackupFile): String = json.encodeToString(file)

    fun decode(raw: String): Result<BackupFile> = runCatching {
        val parsed = json.decodeFromString<BackupFile>(raw)
        require(parsed.schemaVersion <= BackupFile.CURRENT_SCHEMA_VERSION) {
            "tệp sao lưu từ phiên bản mới hơn (${parsed.schemaVersion}), cần cập nhật app"
        }
        parsed
    }

    fun build(
        exportedAt: String,
        items: List<TrackedItem>,
        groups: List<ItemGroup>,
        sims: List<SimProfile>,
        history: List<HandledEvent>,
    ) = BackupFile(
        exportedAt = exportedAt,
        items = items.map { it.toBackup() },
        groups = groups.map { BackupGroup(it.id, it.name, it.kind.name) },
        sims = sims.map { it.toBackup() },
        history = history.map { it.toBackup() },
    )

    /**
     * Spreadsheet export. One row per item.
     *
     * Money stays in minor units with the currency in its own column rather than
     * being formatted: a spreadsheet would otherwise reinterpret "231.000" as a
     * decimal and silently divide a Vietnamese amount by a thousand.
     */
    fun toCsv(items: List<TrackedItem>): String {
        val header = listOf(
            "id", "name", "group_id", "kind", "stake", "category",
            "expires_on", "act_by_offset_days", "anchor_date", "cycle",
            "amount_minor", "currency", "state", "date_source",
        )

        val rows = items.map { item ->
            listOf(
                item.id, item.name, item.groupId.orEmpty(), item.kind.name, item.stake.name,
                item.categoryId.orEmpty(), item.expiresOn.toString(), item.actByOffsetDays.toString(),
                item.anchorDate.toString(), item.cycle?.name.orEmpty(),
                item.amountMinor?.toString().orEmpty(), item.currency.orEmpty(),
                item.state.name, item.dateSource.name,
            )
        }

        return (listOf(header) + rows).joinToString("\n") { row ->
            row.joinToString(",") { it.csvEscaped() }
        }
    }

    /** RFC 4180: wrap in quotes when the value contains a comma, quote or newline. */
    private fun String.csvEscaped(): String =
        if (any { it == ',' || it == '"' || it == '\n' || it == '\r' }) {
            "\"" + replace("\"", "\"\"") + "\""
        } else {
            this
        }
}

private fun TrackedItem.toBackup() = BackupItem(
    id = id,
    name = name,
    groupId = groupId,
    kind = kind.name,
    stake = stake.name,
    categoryId = categoryId,
    expiresOn = expiresOn.toString(),
    actByOffsetDays = actByOffsetDays,
    anchorDate = anchorDate.toString(),
    cycle = cycle?.name,
    amountMinor = amountMinor,
    currency = currency,
    actionUrl = actionUrl,
    actionLabel = actionLabel,
    note = note,
    leadDays = leadDays,
    remindAt = remindAt.toString(),
    nagAfterDue = nagAfterDue.name,
    verifyEveryDays = verifyEveryDays,
    lastVerifiedAt = lastVerifiedAt?.toString(),
    dateSource = dateSource.name,
    state = state.name,
)

private fun SimProfile.toBackup() = BackupSim(
    groupId = groupId,
    carrier = carrier.name,
    msisdn = msisdn,
    isDormant = isDormant,
    hsdConfirmedDate = hsdConfirmedDate?.toString(),
    hsdConfirmedAt = hsdConfirmedAt?.toString(),
    identityVerified = identityVerified.name,
    identityCheckedAt = identityCheckedAt?.toString(),
    lastDeviceChangeAt = lastDeviceChangeAt?.toString(),
    retentionPackage = retentionPackage,
    retentionExpiryDate = retentionExpiryDate?.toString(),
)

private fun HandledEvent.toBackup() = BackupEvent(
    id = id,
    itemId = itemId,
    handledAt = handledAtEpochSeconds,
    forDueDate = forDueDate.toString(),
    amountMinor = amountMinor,
    currency = currency,
    fxRateScaled = fxRateScaled,
    fxRateScale = fxRateScale,
    fxRateDate = fxRateDate?.toString(),
    fxSource = fxSource,
    baseAmountMinor = baseAmountMinor,
    actualChargedMinor = actualChargedMinor,
)
