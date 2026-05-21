import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

/// Helper class for hashing and verifying master passwords and decoy pins.
/// Uses cryptographically secure dynamic salt stored in Secure Storage
/// and derives hashes using PBKDF2-HMAC-SHA256 with 600,000 iterations.
class HashHelper {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _saltKey = 'sentrykey_master_password_salt';
  static const int _iterations = 600000;
  static const int _derivedKeyLength = 32; // 32 bytes = 256 bits

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

  /// Hashes a plain-text master password using PBKDF2-HMAC-SHA256 with 600,000 iterations.
  static Future<String> hashPassword(String plainPassword) async {
    final salt = await _getOrGenerateSalt();
    
    // Initialize PointyCastle's PBKDF2 Key Derivator with HMAC-SHA-256
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, _iterations, _derivedKeyLength));

    final passwordBytes = Uint8List.fromList(utf8.encode(plainPassword));
    final derivedBytes = derivator.process(passwordBytes);

    return _toHex(derivedBytes);
  }

  /// Verifies a plain-text password against a previously stored hash.
  static Future<bool> verifyPassword(String plainPassword, String storedHash) async {
    final hashedInput = await hashPassword(plainPassword);
    return hashedInput == storedHash;
  }

  /// Helper to convert a byte array into its Hexadecimal string representation.
  static String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
