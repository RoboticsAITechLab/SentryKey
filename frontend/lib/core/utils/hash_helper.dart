import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashHelper {
  // Static salt — to be replaced with a user-specific dynamic salt in production.
  // This ensures that even identical passwords produce different hashes.
  static const String _salt = r'SentryKey$2024@SecureSaltValue!';

  /// Hashes a plain-text master password using SHA-256 with a salt.
  /// Never store the original plain text — only this hash is saved.
  static String hashPassword(String plainPassword) {
    final saltedInput = '$_salt:$plainPassword';
    final bytes = utf8.encode(saltedInput);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a plain-text password against a previously stored hash.
  static bool verifyPassword(String plainPassword, String storedHash) {
    final hashedInput = hashPassword(plainPassword);
    return hashedInput == storedHash;
  }
}
