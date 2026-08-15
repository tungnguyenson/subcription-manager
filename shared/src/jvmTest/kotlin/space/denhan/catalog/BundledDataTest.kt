package space.denhan.catalog

import space.denhan.domain.Kind
import space.denhan.domain.Stakes
import space.denhan.domain.Stake
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Guards the two bundled JSON files. These are data, not code, so nothing else
 * would catch a typo in them until it reached a user.
 */
class BundledDataTest {

    private fun resource(name: String): String =
        checkNotNull(javaClass.classLoader.getResourceAsStream(name)) { "missing $name" }
            .readBytes().decodeToString()

    private val catalog by lazy { BundledData.parseCatalog(resource("services.json")) }

    // ---- service catalog ----

    @Test
    fun `the catalog parses and is large enough to be useful`() {
        assertTrue(catalog.entries.size >= 60, "got ${catalog.entries.size}")
    }

    @Test
    fun `entry ids are unique`() {
        val ids = catalog.entries.map { it.id }
        assertEquals(ids.size, ids.toSet().size, "duplicate ids: ${ids.groupBy { it }.filter { it.value.size > 1 }.keys}")
    }

    @Test
    fun `every entry uses a real category`() {
        val known = Categories.ordered.toSet() + Categories.UNCATEGORIZED
        catalog.entries.forEach {
            assertTrue(it.categoryId in known, "${it.id} has unknown category '${it.categoryId}'")
        }
    }

    @Test
    fun `every category has a Vietnamese label`() {
        Categories.ordered.forEach {
            assertNotNull(Categories.displayNamesVi[it], "no label for $it")
        }
    }

    @Test
    fun `every category ships at least one entry so no picker row is dead`() {
        val used = catalog.entries.map { it.categoryId }.toSet()
        Categories.ordered.forEach { assertTrue(it in used, "category $it has no entries") }
    }

    // The count is the argument: 25 items over 8 categories averages ~3 each,
    // which is where a breakdown still aggregates something.
    @Test
    fun `there are exactly eight offerable categories`() {
        assertEquals(8, Categories.ordered.size)
        assertTrue(Categories.UNCATEGORIZED !in Categories.ordered, "the fallback is never offered")
    }

    @Test
    fun `an amount always comes with a currency`() {
        catalog.entries.forEach { entry ->
            if (entry.typicalAmountMinor != null) {
                assertNotNull(entry.currency, "${entry.id} has an amount but no currency")
            }
        }
    }

    // The 100x bug: a VND price written as if it had cents.
    @Test
    fun `VND prices are plausible whole dong, not cents`() {
        catalog.entries
            .filter { it.currency == "VND" }
            .forEach { entry ->
                val amount = entry.typicalAmountMinor!!
                assertTrue(amount >= 1000, "${entry.id} = $amount dong looks like it was divided by 100")
                assertTrue(amount < 100_000_000, "${entry.id} = $amount dong looks like it was multiplied by 100")
            }
    }

    @Test
    fun `USD prices are in cents and plausible`() {
        catalog.entries
            .filter { it.currency == "USD" }
            .forEach { entry ->
                val cents = entry.typicalAmountMinor!!
                assertTrue(cents in 99..50_000, "${entry.id} = $cents cents is out of range")
            }
    }

    // Netflix VN and iCloud with a VN Apple ID bill in dong, not dollars. Getting
    // this wrong would make the whole FX story look bigger than it is.
    @Test
    fun `Vietnam-billed services are priced in dong`() {
        listOf("netflix", "icloud", "youtube-premium").forEach { id ->
            assertEquals("VND", catalog.entries.first { it.id == id }.currency, "$id should bill in VND")
        }
    }

    @Test
    fun `the genuinely dollar-billed services are priced in dollars`() {
        listOf("claude", "chatgpt").forEach { id ->
            assertEquals("USD", catalog.entries.first { it.id == id }.currency, "$id should bill in USD")
        }
    }

    @Test
    fun `documents are never counted as spend`() {
        catalog.entries.filter { it.kind == Kind.DOCUMENT }.forEach {
            assertEquals(Stake.ASSET, Stakes.inferFrom(it.kind), "${it.id} must be unrecoverable-stake")
            assertEquals(Categories.DOCUMENTS, it.categoryId)
        }
    }

    @Test
    fun `prepaid entries carry the unrecoverable stake`() {
        val sims = catalog.entries.filter { it.kind == Kind.PREPAID }
        assertTrue(sims.size >= 4, "the four main carriers should be present")
        sims.forEach { assertEquals(Stake.ASSET, Stakes.inferFrom(it.kind)) }
    }

    @Test
    fun `cancel urls are https`() {
        catalog.entries.mapNotNull { it.cancelUrl }.forEach {
            assertTrue(it.startsWith("https://"), "insecure cancel url: $it")
        }
    }

    // ---- search ----

    @Test
    fun `typing a prefix surfaces the obvious match first`() {
        val catalogue = ServiceCatalog(catalog.entries)
        assertEquals("netflix", catalogue.search("net").first().id)
        assertEquals("claude", catalogue.search("claude").first().id)
    }

    @Test
    fun `search ignores case and Vietnamese diacritics`() {
        val catalogue = ServiceCatalog(catalog.entries)
        assertEquals("ho-chieu", catalogue.search("hộ chiếu").first().id)
        assertEquals("ho-chieu", catalogue.search("HO CHIEU").first().id)
        assertEquals("dien", catalogue.search("điện").first().id)
    }

    @Test
    fun `aliases match so common shorthand works`() {
        val catalogue = ServiceCatalog(catalog.entries)
        assertEquals("chatgpt", catalogue.search("openai").first().id)
        assertEquals("sim-mobifone", catalogue.search("mobi").first().id)
    }

    @Test
    fun `an empty query suggests nothing rather than everything`() {
        assertTrue(ServiceCatalog(catalog.entries).search("").isEmpty())
    }

    @Test
    fun `a nonsense query matches nothing`() {
        assertTrue(ServiceCatalog(catalog.entries).search("zzzqqq").isEmpty())
    }
}
