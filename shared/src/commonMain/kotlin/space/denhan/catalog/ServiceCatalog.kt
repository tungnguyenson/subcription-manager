package space.denhan.catalog

import kotlinx.serialization.Serializable
import space.denhan.domain.Cycle
import space.denhan.domain.Kind

/**
 * A known service, used to prefill the add form.
 *
 * This is the highest-leverage fix for entry friction, and it beats the image
 * scanner on every axis that matters: deterministic, effectively perfect on a
 * hit, no network, no API key, no privacy exposure. Service names are a small
 * closed set of global brands, so a lookup table is enough; no model required.
 *
 * Crucially it also carries [categoryId] and derives [Kind], so the add form
 * never has to ask the user to classify anything. See product-spec.md 4.2.
 */
@Serializable
data class CatalogEntry(
    val id: String,
    val name: String,
    /** Lowercase strings the user might type. Matched as prefixes and substrings. */
    val aliases: List<String> = emptyList(),
    val kind: Kind,
    val categoryId: String,
    val defaultCycle: Cycle? = null,
    /** Indicative price in minor units. Shown as a suggestion, never as fact. */
    val typicalAmountMinor: Long? = null,
    val currency: String? = null,
    /** Opens the page where the subscription is actually cancelled. */
    val cancelUrl: String? = null,
    val noteVi: String? = null,
)

@Serializable
data class CatalogBundle(
    val schemaVersion: Int,
    val generatedAt: String,
    val entries: List<CatalogEntry>,
)

/**
 * The eight spend categories.
 *
 * Eight because a personal tracker holds 20 to 30 items, and 25 split across 8
 * averages about 3 per category, which is the point at which a breakdown chart
 * still aggregates something. Wallos ships 16 and its own default row is
 * "No category". Eight rows also fit one phone picker screen without scrolling.
 * See product-spec.md section 4.3.
 */
object Categories {
    const val ENTERTAINMENT = "entertainment"
    const val AI_SOFTWARE = "ai_software"
    const val CLOUD = "cloud"
    const val TELECOM = "telecom"
    const val HOME_BILLS = "home_bills"
    const val LOANS = "loans"
    const val INSURANCE = "insurance"
    const val DOCUMENTS = "documents"

    /** Never offered as a choice; only used as a fallback. */
    const val UNCATEGORIZED = "uncategorized"

    val displayNamesVi = mapOf(
        ENTERTAINMENT to "Giải trí",
        AI_SOFTWARE to "AI và phần mềm",
        CLOUD to "Lưu trữ đám mây",
        TELECOM to "Viễn thông và Internet",
        HOME_BILLS to "Hóa đơn nhà",
        LOANS to "Vay và trả góp",
        INSURANCE to "Bảo hiểm",
        DOCUMENTS to "Giấy tờ và thủ tục",
        UNCATEGORIZED to "Chưa phân loại",
    )

    /** Order shown in the spend breakdown. Excludes the fallback row. */
    val ordered = listOf(
        ENTERTAINMENT, AI_SOFTWARE, CLOUD, TELECOM,
        HOME_BILLS, LOANS, INSURANCE, DOCUMENTS,
    )
}

/**
 * Lookup over the bundled entries.
 *
 * Matching is deliberately forgiving because the user is typing on a phone:
 * case-insensitive, diacritic-insensitive, prefix before substring.
 */
class ServiceCatalog(private val entries: List<CatalogEntry>) {

    fun all(): List<CatalogEntry> = entries

    fun byId(id: String): CatalogEntry? = entries.firstOrNull { it.id == id }

    /**
     * Type-ahead suggestions. Exact name matches first, then prefix matches, then
     * substring matches, so typing "net" surfaces Netflix before Vietnamobile.
     */
    fun search(query: String, limit: Int = 8): List<CatalogEntry> {
        val q = query.normalize()
        if (q.isEmpty()) return emptyList()

        return entries
            .mapNotNull { entry ->
                val score = entry.score(q) ?: return@mapNotNull null
                entry to score
            }
            .sortedWith(compareBy({ it.second }, { it.first.name }))
            .take(limit)
            .map { it.first }
    }

    /** Lower is better. Null means no match at all. */
    private fun CatalogEntry.score(q: String): Int? {
        val haystacks = (listOf(name) + aliases).map { it.normalize() }
        return when {
            haystacks.any { it == q } -> 0
            haystacks.any { it.startsWith(q) } -> 1
            haystacks.any { it.contains(q) } -> 2
            else -> null
        }
    }

    companion object {
        /** Strips diacritics and case so "viettel" matches "Viettel". */
        private fun String.normalize(): String = lowercase()
            .replace(Regex("[àáạảãâầấậẩẫăằắặẳẵ]"), "a")
            .replace(Regex("[èéẹẻẽêềếệểễ]"), "e")
            .replace(Regex("[ìíịỉĩ]"), "i")
            .replace(Regex("[òóọỏõôồốộổỗơờớợởỡ]"), "o")
            .replace(Regex("[ùúụủũưừứựửữ]"), "u")
            .replace(Regex("[ỳýỵỷỹ]"), "y")
            .replace("đ", "d")
            .trim()
    }
}
