// Secure, keychain-backed storage for Shamir shares and other sensitive
// wallet data.
//
// On macOS this writes to the user's Keychain via Security.framework.
// On iOS it uses the Keychain too.
// On Android it uses EncryptedSharedPreferences backed by the Android Keystore.
//
// IMPORTANT: This deliberately does NOT use SharedPreferences.
// SharedPreferences writes plaintext XML/JSON to disk, which bypasses all
// of the Rust-layer Argon2id+AEAD encryption. Any previous use of
// SharedPreferences for share storage was a critical vulnerability.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // One shared instance — FlutterSecureStorage is stateless (all I/O goes to
  // the OS keychain directly), so sharing is safe and avoids repeated setup.
  static const _storage = FlutterSecureStorage(
    // macOS options: kSecAttrAccessibleWhenUnlockedThisDeviceOnly ensures
    // the data is not included in iCloud Keychain sync and cannot be read
    // while the device is locked.
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    // iOS: same access level — not backed up to iCloud, not readable locked.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    // Android: use the Keystore-backed EncryptedSharedPreferences.
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keyBackupShares = 'wallet_backup_shares_v2';

  /// Save backup share strings (base64 blobs from the Rust FFI) to the
  /// OS keychain. Stored as newline-delimited to avoid splitting on spaces
  /// (base64 output never contains newlines).
  static Future<void> saveBackupShares(List<String> shares) async {
    final value = shares.join('\n');
    await _storage.write(key: _keyBackupShares, value: value);
  }

  /// Retrieve backup shares from the OS keychain.
  static Future<List<String>> getBackupShares() async {
    final value = await _storage.read(key: _keyBackupShares);
    if (value == null || value.isEmpty) return [];
    return value.split('\n').where((s) => s.trim().isNotEmpty).toList();
  }

  /// Remove backup shares from the OS keychain. Call after a wallet is
  /// deleted or when share backup is no longer needed.
  static Future<void> clearBackupShares() async {
    await _storage.delete(key: _keyBackupShares);
  }
}
