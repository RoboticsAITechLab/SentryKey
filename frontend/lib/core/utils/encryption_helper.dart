import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  // Static salt/key for now, to be made modular for a dynamic key later.
  // Must be 32 characters for AES-256.
  static const String _staticKeyString = 'SentryKeyStaticMasterKey32Bytes!';
  
  static final encrypt.Key _key = encrypt.Key.fromUtf8(_staticKeyString);
  // Static IV for now, typically this should be random per encryption and stored alongside the ciphertext
  static final encrypt.IV _iv = encrypt.IV.fromLength(16);
  static final encrypt.Encrypter _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  /// Encrypts a plain string into a Base64 encoded string.
  static String encryptString(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts an encrypted Base64 string back to plain text.
  static String decryptString(String encryptedBase64) {
    final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
}
