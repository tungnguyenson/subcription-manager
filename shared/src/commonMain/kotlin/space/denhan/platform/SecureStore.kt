package space.denhan.platform

/**
 * Storage for the one secret this app holds: the user's own OpenAI API key.
 *
 * That key bills the user's card directly, so it is treated like a payment
 * credential, not like a setting. On iOS this means the Keychain with
 * `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: without an explicit
 * accessibility attribute the item rides encrypted device backups and restores
 * onto a replacement phone, which is wrong for a billing credential.
 *
 * See product-spec.md sections 8.8 and 11.1.
 */
expect class SecureStore {
    fun put(key: String, value: String)
    fun get(key: String): String?
    fun remove(key: String)
}

object SecureKeys {
    const val OPENAI_API_KEY = "openai_api_key"
}
