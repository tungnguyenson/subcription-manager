package space.denhan.platform

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.value
import platform.CoreFoundation.CFDictionaryRef
import platform.CoreFoundation.CFTypeRefVar
import platform.Foundation.CFBridgingRelease
import platform.Foundation.CFBridgingRetain
import platform.Foundation.NSData
import platform.Foundation.NSMutableDictionary
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.create
import platform.Foundation.dataUsingEncoding
import platform.Security.SecItemAdd
import platform.Security.SecItemCopyMatching
import platform.Security.SecItemDelete
import platform.Security.SecItemUpdate
import platform.Security.errSecSuccess
import platform.Security.kSecAttrAccessible
import platform.Security.kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
import platform.Security.kSecAttrAccount
import platform.Security.kSecAttrService
import platform.Security.kSecClass
import platform.Security.kSecClassGenericPassword
import platform.Security.kSecMatchLimit
import platform.Security.kSecMatchLimitOne
import platform.Security.kSecReturnData
import platform.Security.kSecValueData

/**
 * Keychain-backed storage for the user's API key.
 *
 * Hand-rolled against platform.Security rather than using
 * multiplatform-settings' KeychainSettings, for one specific reason: that
 * class's plain constructor never sets `kSecAttrAccessible`, so items default
 * to riding encrypted device backups and restoring onto a replacement phone.
 * Wrong for a credential that charges the user's card. Here the accessibility
 * is pinned to `AfterFirstUnlockThisDeviceOnly`.
 *
 * KVault is not an alternative; last released October 2023, and an unmaintained
 * Keychain wrapper is not something to depend on.
 */
@OptIn(ExperimentalForeignApi::class)
actual class SecureStore(private val service: String = DEFAULT_SERVICE) {

    actual fun put(key: String, value: String) {
        val data = value.toNSData() ?: return

        // Update first: SecItemAdd returns errSecDuplicateItem if the account
        // already exists, so add-then-fallback would need the same branch anyway.
        val attributes = NSMutableDictionary().apply {
            setObject(data, forKey = kSecValueData.asKey())
        }

        val updated = withQuery(key) { query -> SecItemUpdate(query, attributes.asCFDictionary()) }
        if (updated == errSecSuccess) return

        val insert = queryDictionary(key).apply {
            setObject(data, forKey = kSecValueData.asKey())
            setObject(
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                forKey = kSecAttrAccessible.asKey(),
            )
        }
        val ref = CFBridgingRetain(insert) as CFDictionaryRef?
        try {
            SecItemAdd(ref, null)
        } finally {
            CFBridgingRelease(ref)
        }
    }

    actual fun get(key: String): String? {
        val dict = queryDictionary(key).apply {
            setObject(true, forKey = kSecReturnData.asKey())
            setObject(kSecMatchLimitOne, forKey = kSecMatchLimit.asKey())
        }
        val ref = CFBridgingRetain(dict) as CFDictionaryRef?

        return try {
            memScoped {
                val out = alloc<CFTypeRefVar>()
                if (SecItemCopyMatching(ref, out.ptr) != errSecSuccess) return@memScoped null
                (CFBridgingRelease(out.value) as? NSData)?.toKString()
            }
        } finally {
            CFBridgingRelease(ref)
        }
    }

    actual fun remove(key: String) {
        withQuery(key) { query -> SecItemDelete(query) }
    }

    private inline fun <T> withQuery(key: String, body: (CFDictionaryRef?) -> T): T {
        val ref = CFBridgingRetain(queryDictionary(key)) as CFDictionaryRef?
        return try {
            body(ref)
        } finally {
            CFBridgingRelease(ref)
        }
    }

    /** The three attributes that identify one stored item. */
    private fun queryDictionary(key: String) = NSMutableDictionary().apply {
        setObject(kSecClassGenericPassword, forKey = kSecClass.asKey())
        setObject(service, forKey = kSecAttrService.asKey())
        setObject(key, forKey = kSecAttrAccount.asKey())
    }

    private fun NSMutableDictionary.asCFDictionary(): CFDictionaryRef? =
        CFBridgingRetain(this) as CFDictionaryRef?

    private fun String.toNSData(): NSData? =
        (this as NSString).dataUsingEncoding(NSUTF8StringEncoding)

    private fun NSData.toKString(): String? =
        NSString.create(data = this, encoding = NSUTF8StringEncoding) as String?

    companion object {
        const val DEFAULT_SERVICE = "space.denhan"
    }
}

/**
 * Keychain constants arrive as CFStringRef; NSDictionary keys need an
 * NSCopying object.
 *
 * The CFRetain is load-bearing. CFBridgingRelease consumes a +1 reference, and
 * we do not own the kSec* globals, so bridging them directly would
 * over-release a process-wide constant. Retaining first makes the transfer
 * balanced.
 */
@OptIn(ExperimentalForeignApi::class)
private fun platform.CoreFoundation.CFStringRef?.asKey(): NSString =
    CFBridgingRelease(platform.CoreFoundation.CFRetain(this)) as NSString
