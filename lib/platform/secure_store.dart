import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore-backed storage for the one secret this app holds: the user's own
/// OpenAI API key. Keychain on iOS, Android Keystore on Android.
///
/// The key is the user's property and their liability. It never leaves the
/// device except in the `Authorization` header of a request to OpenAI, it is
/// never written to the backup file, and it is never logged.
class SecureStore {
  static const String _apiKeyKey = 'openai_api_key';

  final FlutterSecureStorage _storage;

  SecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              // Readable after the first unlock, and never migrated to another
              // device by an encrypted backup. The app has no server-side copy
              // of this key, so a restored backup on a new phone must ask for
              // it again rather than silently carrying a credential across.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            // Android has no accessibility flag to match the iOS one; the
            // same guarantee is bought in two other places. The wrapping key
            // lives in the hardware keystore and cannot be exported, so a
            // ciphertext restored onto another phone is undecryptable there.
            // `resetOnError` then clears it instead of throwing, which is what
            // turns "undecryptable" into "the app asks for the key again".
            // Auto-backup is told to skip the file as well, in
            // res/xml/backup_rules.xml, so the ciphertext does not travel at
            // all rather than travelling and failing.
            aOptions: AndroidOptions(resetOnError: true),
          );

  Future<String?> readApiKey() => _storage.read(key: _apiKeyKey);

  /// Writing an empty value deletes the entry rather than storing a blank,
  /// so "cleared" and "never set" are the same state downstream.
  Future<void> writeApiKey(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _storage.delete(key: _apiKeyKey);
    }
    return _storage.write(key: _apiKeyKey, value: trimmed);
  }

  Future<bool> hasApiKey() async {
    final key = await readApiKey();
    return key != null && key.isNotEmpty;
  }
}

/// Shape check only. A key that looks right can still be revoked, so this
/// never claims the key works: it only catches the paste that grabbed the
/// wrong clipboard entry, before spending a request to find out.
bool looksLikeOpenAiKey(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('sk-') && trimmed.length >= 20;
}
