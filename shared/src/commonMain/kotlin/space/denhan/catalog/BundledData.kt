package space.denhan.catalog

import kotlinx.serialization.json.Json

/**
 * Parsing for the two bundled JSON files.
 *
 * Both ship inside the binary so the app works with no network, and both are
 * shaped so a newer copy can override them at runtime: carrier syntax and
 * package prices go stale faster than an App Store review cycle.
 */
object BundledData {

    /**
     * Lenient on unknown keys so a config written by a newer build does not make
     * an older build refuse to start. Strict on missing required fields, because
     * a half-parsed carrier entry is worse than none.
     */
    val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    fun parseCatalog(raw: String): CatalogBundle = json.decodeFromString(raw)

    fun parseCarriers(raw: String): CarrierConfigBundle = json.decodeFromString(raw)
}
