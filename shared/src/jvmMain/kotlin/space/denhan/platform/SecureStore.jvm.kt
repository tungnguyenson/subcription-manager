package space.denhan.platform

/**
 * In-memory stand-in so domain and repository tests can run on the JVM.
 *
 * Deliberately not persisted anywhere: there is no JVM build of this app, and a
 * file-backed fake would invite someone to ship it.
 */
actual class SecureStore {
    private val values = mutableMapOf<String, String>()

    actual fun put(key: String, value: String) { values[key] = value }
    actual fun get(key: String): String? = values[key]
    actual fun remove(key: String) { values.remove(key) }
}
