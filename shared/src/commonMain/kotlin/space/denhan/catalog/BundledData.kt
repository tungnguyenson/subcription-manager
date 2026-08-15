package space.denhan.catalog

import kotlinx.serialization.json.Json

/**
 * Parsing for the bundled service catalog.
 *
 * Ships inside the binary so the app works with no network, and is shaped so a
 * newer copy can override it at runtime without an App Store release.
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
}
