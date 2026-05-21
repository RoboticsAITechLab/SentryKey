import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

/// Handles double-layer encryption (AES-256 GCM) for sensitive vault data.
class EncryptionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _saltKey = 'sentrykey_vault_encryption_salt';
  
  encrypt.Key? _derivedKey;

  /// Initializes the encryption service by deriving the 256-bit AES key
  /// from the user's master password using PBKDF2.
  Future<void> init(String masterPassword) async {
    _derivedKey = await _deriveKey(masterPassword);
  }

  /// Clears the derived key from memory when the vault is locked.
  void clearKey() {
    _derivedKey = null;
  }

  /// Generates a cryptographically secure 32-byte random salt.
  static Uint8List _generateSecureSalt() {
    final random = Random.secure();
    final values = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      values[i] = random.nextInt(256);
    }
    return values;
  }

  /// Retrieves the stored dynamic salt, or generates a new one on first launch.
  static Future<Uint8List> _getOrGenerateSalt() async {
    final storedSaltBase64 = await _storage.read(key: _saltKey);
    if (storedSaltBase64 != null && storedSaltBase64.isNotEmpty) {
      try {
        return base64Decode(storedSaltBase64);
      } catch (e) {
        // Fallback in case of corruption or decoding error
      }
    }

    // Generate a fresh secure salt and write it to secure storage
    final newSalt = _generateSecureSalt();
    await _storage.write(
      key: _saltKey,
      value: base64Encode(newSalt),
    );
    return newSalt;
  }

  /// Derives a 256-bit (32-byte) key from the master password using PBKDF2-HMAC-SHA256.
  Future<encrypt.Key> _deriveKey(String password) async {
    final salt = await _getOrGenerateSalt();
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, 600000, 32)); // 600,000 iterations, 32 bytes (256 bits)
    
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final keyBytes = derivator.process(passwordBytes);
    return encrypt.Key(keyBytes);
  }

  /// Encrypts plain text using AES-256-GCM.
  /// Throws if the service is not initialized.
  String encryptData(String plainText) {
    if (_derivedKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }

    final iv = encrypt.IV.fromSecureRandom(12); // 12 bytes for AES-GCM block size / nonce
    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.gcm));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Prepend the IV to the ciphertext so we can decrypt it later.
    // Format: base64(iv):base64(ciphertext+tag)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts AES-256-GCM ciphertext.
  /// Expects the format 'base64(iv):base64(ciphertext+tag)'.
  String decryptData(String encryptedString) {
    if (_derivedKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }

    final parts = encryptedString.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted string format.');
    }

    final iv = encrypt.IV.fromBase64(parts[0]);
    final encryptedData = encrypt.Encrypted.fromBase64(parts[1]);

    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.gcm));

    return encrypter.decrypt(encryptedData, iv: iv);
  }
}
