import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart' as pc;
import '../utils/hash_helper.dart';

/// Handles double-layer encryption (AES-256 GCM) for sensitive vault data.
class EncryptionService {
  encrypt.Key? _derivedKey;

  /// Initializes the encryption service by deriving the 256-bit AES key
  /// from the user's master password using PBKDF2 with HashHelper's salt.
  Future<void> init(String masterPassword) async {
    _derivedKey = await _deriveKey(masterPassword);
  }

  /// Clears the derived key from memory when the vault is locked.
  void clearKey() {
    _derivedKey = null;
  }

  /// Derives a 256-bit (32-byte) key from the master password using PBKDF2-HMAC-SHA256
  /// and the dynamic salt obtained from HashHelper.
  Future<encrypt.Key> _deriveKey(String password) async {
    final salt = await HashHelper.getDynamicSalt();
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, 600000, 32)); // 600,000 iterations, 32 bytes (256 bits)
    
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final keyBytes = derivator.process(passwordBytes);
    return encrypt.Key(keyBytes);
  }

  /// Encrypts plain text using AES-256-GCM.
  /// Generates a unique 12-byte IV, prepends it to the raw ciphertext, and returns it as a Base64 string.
  /// Throws if the service is not initialized.
  String encryptData(String plainText) {
    if (_derivedKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }

    // 1. Generate a unique 12-byte Nonce (IV)
    final iv = encrypt.IV.fromSecureRandom(12);

    // 2. Initialize the AES-GCM-256 encrypter
    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.gcm));

    // 3. Encrypt the data to get the ciphertext bytes (including the GCM tag)
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // 4. Combine: 12-byte IV + Ciphertext bytes (with tag)
    final combinedBytes = Uint8List(12 + encrypted.bytes.length);
    combinedBytes.setRange(0, 12, iv.bytes);
    combinedBytes.setRange(12, combinedBytes.length, encrypted.bytes);

    // 5. Encode the complete combined payload into a clean Base64 string
    return base64.encode(combinedBytes);
  }

  /// Decrypts AES-256-GCM ciphertext from a combined Base64 payload.
  /// Expects the format 'base64(12-byte IV + ciphertext + tag)'.
  String decryptData(String encryptedString) {
    if (_derivedKey == null) {
      throw Exception('EncryptionService not initialized. Call init() first.');
    }

    // 1. Decode the Base64 string to get the combined bytes
    final combinedBytes = base64.decode(encryptedString);
    if (combinedBytes.length < 12) {
      throw const FormatException('Invalid encrypted payload: too short.');
    }

    // 2. Extract the first 12 bytes as the IV
    final ivBytes = combinedBytes.sublist(0, 12);
    final iv = encrypt.IV(ivBytes);

    // 3. Extract the remaining bytes as the ciphertext + tag
    final ciphertextBytes = combinedBytes.sublist(12);
    final encryptedData = encrypt.Encrypted(ciphertextBytes);

    // 4. Decrypt using AES-GCM-256
    final encrypter = encrypt.Encrypter(encrypt.AES(_derivedKey!, mode: encrypt.AESMode.gcm));

    return encrypter.decrypt(encryptedData, iv: iv);
  }
}
