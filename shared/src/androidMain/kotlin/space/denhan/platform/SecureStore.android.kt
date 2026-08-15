package space.denhan.platform

/**
 * Android is not a shipping target yet. Left unimplemented on purpose rather
 * than backed by SharedPreferences, so nobody can ship an API key in plaintext
 * by accident. Replace with EncryptedSharedPreferences when Android ships.
 */
actual class SecureStore {
    actual fun put(key: String, value: String): Unit = TODO("Android target not implemented")
    actual fun get(key: String): String? = TODO("Android target not implemented")
    actual fun remove(key: String): Unit = TODO("Android target not implemented")
}
