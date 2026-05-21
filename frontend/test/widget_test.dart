import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_key/core/utils/hash_helper.dart';
import 'package:sentry_key/core/services/encryption_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('SentryKey Cryptographic Suite Tests', () {
    setUp(() {
      // Mock initial secure storage values before each test run
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('HashHelper - PBKDF2-HMAC-SHA256 600k Hashing & Verification', () async {
      const password = 'EnterpriseSecureMasterPassword2026@!';
      
      // Hash password
      final hash = await HashHelper.hashPassword(password);
      expect(hash, isNotEmpty);
      expect(hash.length, equals(64)); // Hex string for 32-byte hash
      
      // Verify correct password
      final isValid = await HashHelper.verifyPassword(password, hash);
      expect(isValid, isTrue);

      // Verify incorrect password
      final isWrongValid = await HashHelper.verifyPassword('WrongMasterPassword123', hash);
      expect(isWrongValid, isFalse);
    });

    test('EncryptionService - AES-256-GCM Encryption & Decryption Integrity', () async {
      final encryptionService = EncryptionService();
      const masterPassword = 'MyVaultPassword_99!';
      
      // Initialize service (derives key via PBKDF2-HMAC-SHA256 600k iterations)
      await encryptionService.init(masterPassword);

      const secretPayload = '{"url": "https://bank.com", "username": "admin", "password": "123"}';
      
      // Encrypt data
      final encryptedPayload = encryptionService.encryptData(secretPayload);
      expect(encryptedPayload, isNotEmpty);
      expect(encryptedPayload.contains(':'), isTrue); // Has IV and ciphertext parts separator

      // Decrypt data
      final decryptedPayload = encryptionService.decryptData(encryptedPayload);
      expect(decryptedPayload, equals(secretPayload));

      // Test Integrity - modifying the ciphertext must throw an exception (AEAD property)
      final parts = encryptedPayload.split(':');
      final corruptedCiphertext = parts[1].substring(0, parts[1].length - 4) + 'AAAA';
      final corruptedPayload = '${parts[0]}:$corruptedCiphertext';

      expect(() => encryptionService.decryptData(corruptedPayload), throwsException);
    });
  });
}
