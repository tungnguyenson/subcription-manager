package space.denhan.catalog

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import space.denhan.domain.Carrier

/**
 * Per-carrier facts that go stale faster than an App Store review cycle.
 *
 * The proof case: multiple sources report Viettel shut off all USSD codes on
 * 13/05/2026 in favour of SMS. If that is true, an app shipping `*101#` is
 * already handing users a dead code. So every value here is data with a
 * last-verified date, loadable from a file that a newer copy can override,
 * never a constant compiled into the binary.
 *
 * Nothing in here is authoritative. No carrier publishes a tariff document with
 * a reclamation timeline; every specific figure traces to reseller sites, some
 * from 2022. The UI must present these as "check this" rather than as fact.
 * See product-spec.md sections 4bis.2 and 4bis.5.
 */
@Serializable
data class CarrierConfig(
    val carrier: Carrier,
    val displayName: String,

    /** How to ask the carrier for the current validity date. Ordered best-first. */
    val checkMethods: List<CheckMethod>,

    /** Long-term number retention packages, the right answer for a dormant SIM. */
    val retentionPackages: List<RetentionPackage>,

    /** Worst-case margins used for reminder scheduling. See [SafetyMargins]. */
    val margins: SafetyMargins,

    /** ISO date this entry was last checked against a source. Shown in the UI. */
    val lastVerified: String,

    /** Free-text caveats to surface verbatim rather than paraphrase. */
    val caveats: List<String> = emptyList(),
)

@Serializable
data class CheckMethod(
    val kind: CheckKind,
    /** USSD code, SMS body, or phone number depending on [kind]. */
    val value: String,
    /** SMS destination. Null for USSD and hotline. */
    val sendTo: String? = null,
    val label: String,
    /**
     * False when sources disagree about whether this still works. The UI must
     * not offer a disputed method as the primary action.
     */
    val confirmed: Boolean = true,
    val note: String? = null,
)

@Serializable
enum class CheckKind {
    /** Dial a code. iOS cannot auto-dial USSD; the user must press call. */
    @SerialName("ussd") USSD,
    @SerialName("sms") SMS,
    @SerialName("hotline") HOTLINE,
    @SerialName("app") CARRIER_APP,
}

@Serializable
data class RetentionPackage(
    val code: String,
    val smsBody: String,
    val sendTo: String,
    /** Price in dong. Sources conflict, so the UI shows this as unverified. */
    val priceVnd: Long,
    val days: Int,
    /** Registering repeatedly accumulates the window, per carrier documentation. */
    val stacks: Boolean = true,
    val note: String? = null,
)

/**
 * Deliberately pessimistic scheduling margins.
 *
 * Where sources conflict, these take the shortest window found, never the
 * average and never the most generous. A comfortable-looking number derived
 * from the most generous source is how a user loses a number.
 */
@Serializable
data class SafetyMargins(
    /** Days of receive-only service after validity lapses. Assume the shortest. */
    val receiveOnlyDays: Int = 10,
    /** Days from validity lapse to possible permanent loss. Assume the shortest. */
    val permanentLossDays: Int = 45,
    /** First reminder at least this far ahead. */
    val firstReminderDays: Int = 30,
)

/**
 * Risks that are not tied to any expiry date and that topping up does not fix.
 *
 * These exist because a SIM has three independent clocks and the app's own core
 * user behaviour, keeping a dormant SIM and occasionally putting it in a phone,
 * is what triggers the third one. See product-spec.md section 4bis.1.
 */
@Serializable
data class StandingRisk(
    val id: String,
    val titleVi: String,
    val bodyVi: String,
    val severity: RiskSeverity,
    /** ISO date after which this warning stops being shown. Null means indefinite. */
    val showUntil: String? = null,
)

@Serializable
enum class RiskSeverity {
    @SerialName("critical") CRITICAL,
    @SerialName("warning") WARNING,
}

@Serializable
data class CarrierConfigBundle(
    val schemaVersion: Int,
    val generatedAt: String,
    val carriers: List<CarrierConfig>,
    val standingRisks: List<StandingRisk>,
)
