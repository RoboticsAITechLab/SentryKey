import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;

/// Handles double-layer encryption (AES-256 CBC) for sensitive vault data.
class EncryptionService {
  // Hardcoded salt for the PBKDF2 derivation of the vault key.
  // In a fully production app, this salt could be generated per user and stored.
  static final Uint8List _salt = Uint8List.fromList(utf8.encode('SentryKey_Vault_Salt_2024!'));
  
  encrypt.Key? _derivedKey;

  /// Initializes the encryption service by deriving the 256-bit AES key
  /// from the user's master password using PBKDF2.
  void init(String masterPassword) {
    _derivedKey = _deriveKey(masterPassword);
  }

  /// Clears the derived key from memory when the vault is locked.
  void clearKey() {
    _derivedKey = null;
  }

  /// Derives a 256-bit (32-byte) key from the master password using PBKDF2-HMAC-SHA256.
  encrypt.Key _deriveKey(String password) {
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(_salt, 10000, 32)); // 10,000 iterations, 32 bytes (256 bits)
    
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final keyBytes = derivator.process(passwordBytes);
    return encrypt.Key(keyBytes);
  }

  /// Encrypts plain text using AES-256-CBC.
  /// Throws if the service is not initialized.
  String encryptData(String plainText) {
    if (_derivedKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }

    final iv = encrypt.IV.fromSecureRandom(16); // 16 bytes for AES block size
    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    // Prepend the IV to the ciphertext so we can decrypt it later.
    // Format: base64(iv):base64(ciphertext)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts AES-256-CBC ciphertext.
  /// Expects the format 'base64(iv):base64(ciphertext)'.
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

    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));

    return encrypter.decrypt(encryptedData, iv: iv);
  }
}
