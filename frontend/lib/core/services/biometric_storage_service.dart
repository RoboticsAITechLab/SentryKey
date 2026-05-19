import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// A secure storage service that handles hardware-backed biometric authentication
/// and securely stores the vault's master encryption key.
class BiometricStorageService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  /// The unique key used to store the derived master secret in the secure storage.
  static const String _keyMasterSecret = 'vault_master_secret';

  BiometricStorageService(this._secureStorage, this._localAuth);

  /// Android specific secure storage options.
  /// Note: encryptedSharedPreferences is enabled automatically by default
  /// in newer versions of flutter_secure_storage. We define empty options here
  /// to ensure future compatibility.
  AndroidOptions _getAndroidOptions() => const AndroidOptions();

  /// iOS specific secure storage options.
  /// We use `first_unlock_this_device` to ensure strict hardware isolation
  /// where the keychain item is only accessible after the device has been
  /// unlocked at least once and cannot be migrated to other devices.
  IOSOptions _getIOSOptions() => const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      );

  /// Checks if the device has biometric hardware available and if the user
  /// has actively enrolled any biometrics (like Fingerprint or Face ID).
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      // In case of any platform error while checking hardware capability,
      // safely fallback to false.
      return false;
    }
  }

  /// Triggers the native biometric prompt to authenticate the user.
  ///
  /// Throws standard platform exceptions transformed into user-friendly
  /// exception messages if the authentication fails due to lockout or missing enrollment.
  Future<bool> authenticateUser(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (e) {
      // We rely on standard string literal checks for native error codes
      // to avoid breaking changes if package-specific error enums are renamed or deprecated.
      if (e.code == 'NotEnrolled' || e.code == 'PasscodeNotSet') {
        throw Exception('Biometrics or device passcode are not set up on this device.');
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        throw Exception('Biometric authentication is locked due to too many attempts. Please use your master password.');
      } else if (e.code == 'NotAvailable') {
        throw Exception('Biometric hardware is not available on this device.');
      }
      
      // For any other unexpected platform errors, return false rather than crashing.
      return false;
    }
  }

  /// Securely saves the vault's master password to the hardware-backed keystore
  /// after the user successfully authenticates via biometrics.
  Future<void> enableBiometricUnlock(String masterPassword) async {
    final isAuthenticated = await authenticateUser('Authenticate to enable biometric unlock for your vault');
    
    if (isAuthenticated) {
      await _secureStorage.write(
        key: _keyMasterSecret,
        value: masterPassword,
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
    } else {
      throw Exception('Biometric authentication failed or was canceled.');
    }
  }

  /// Completely removes the master password from the secure keystore,
  /// thereby disabling biometric unlock capabilities.
  Future<void> disableBiometricUnlock() async {
    await _secureStorage.delete(
      key: _keyMasterSecret,
      iOptions: _getIOSOptions(),
      aOptions: _getAndroidOptions(),
    );
  }

  /// Checks if a master password is currently stored in the hardware keystore.
  Future<bool> hasStoredMasterPassword() async {
    return await _secureStorage.containsKey(
      key: _keyMasterSecret,
      iOptions: _getIOSOptions(),
      aOptions: _getAndroidOptions(),
    );
  }

  /// Retrieves the securely stored master password if the user successfully
  /// authenticates with their biometrics.
  ///
  /// Returns `null` if biometrics are not set up or the user is not authenticated.
  Future<String?> unlockWithBiometrics() async {
    final isEnrolled = await isBiometricAvailable();
    if (!isEnrolled) {
      throw Exception('Biometrics are not available or not enrolled on this device.');
    }

    // First check if a key actually exists in the keystore before prompting the user.
    final hasKey = await _secureStorage.containsKey(
      key: _keyMasterSecret,
      iOptions: _getIOSOptions(),
      aOptions: _getAndroidOptions(),
    );

    if (!hasKey) {
      return null;
    }

    // Prompt the user to authenticate using native UI
    final isAuthenticated = await authenticateUser('Authenticate to unlock SentryKey Vault');
    
    if (isAuthenticated) {
      return await _secureStorage.read(
        key: _keyMasterSecret,
        iOptions: _getIOSOptions(),
        aOptions: _getAndroidOptions(),
      );
    }
    
    return null;
  }
}
