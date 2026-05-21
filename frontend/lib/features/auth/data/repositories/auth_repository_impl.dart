import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/utils/auth_session.dart';
import '../../../../core/utils/hash_helper.dart';
import '../../domain/repositories/auth_repository.dart';

/// Secure storage keys — centralized to avoid magic strings.
class _StorageKeys {
  static const String passwordHash = 'master_password_hash';
  static const String isRegistered = 'is_user_registered';
  static const String panicPasswordHash = 'panic_password_hash';
  static const String decoyProfilesKey = 'decoy_profiles_map';
}

class AuthRepositoryImpl implements AuthRepository {
  final FlutterSecureStorage _secureStorage;
  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;

  const AuthRepositoryImpl({
    required FlutterSecureStorage secureStorage,
    required DatabaseService databaseService,
    required EncryptionService encryptionService,
  })  : _secureStorage = secureStorage,
        _databaseService = databaseService,
        _encryptionService = encryptionService;

  @override
  Future<Either<Failure, bool>> signUp(String masterPassword) async {
    try {
      final passwordHash = HashHelper.hashPassword(masterPassword);

      // Store hash and registration flag in secure storage.
      await _secureStorage.write(
        key: _StorageKeys.passwordHash,
        value: passwordHash,
      );
      await _secureStorage.write(
        key: _StorageKeys.isRegistered,
        value: 'true',
      );

      // Open the encrypted vault with the master password as the SQLCipher key.
      await _databaseService.initDatabase(masterPassword);
      _encryptionService.init(masterPassword);

      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Sign up failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> login(String masterPassword) async {
    try {
      final storedHash = await _secureStorage.read(
        key: _StorageKeys.passwordHash,
      );
      
      final panicHash = await _secureStorage.read(
        key: _StorageKeys.panicPasswordHash,
      );

      if (storedHash == null) {
        return const Left(AuthFailure('No master password found. Please sign up first.'));
      }

      final isValid = HashHelper.verifyPassword(masterPassword, storedHash);
      bool isPanic = panicHash != null && HashHelper.verifyPassword(masterPassword, panicHash);
      String duressProfile = 'default';

      if (!isValid && !isPanic) {
        // Scan custom multi decoy profiles mapping
        final String? decoyJson = await _secureStorage.read(key: _StorageKeys.decoyProfilesKey);
        if (decoyJson != null) {
          final Map<String, dynamic> profiles = Map<String, dynamic>.from(jsonDecode(decoyJson));
          for (final entry in profiles.entries) {
            final profileHash = entry.value as String;
            if (HashHelper.verifyPassword(masterPassword, profileHash)) {
              isPanic = true;
              duressProfile = entry.key;
              break;
            }
          }
        }
      }

      if (!isValid && !isPanic) {
        return const Left(AuthFailure('Incorrect master password.'));
      }

      // Unlock the appropriate primary or Honey-pot decoy database
      AuthSession.isDuressMode = isPanic;
      AuthSession.activeDuressProfile = duressProfile;
      await _databaseService.initDatabase(masterPassword, isDuress: isPanic);
      _encryptionService.init(masterPassword);

      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Login failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isUserRegistered() async {
    try {
      final value = await _secureStorage.read(key: _StorageKeys.isRegistered);
      return Right(value == 'true');
    } catch (e) {
      return Left(StorageFailure('Could not read registration status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> resetMasterPassword() async {
    try {
      await _secureStorage.delete(key: _StorageKeys.passwordHash);
      await _secureStorage.delete(key: _StorageKeys.isRegistered);
      await _secureStorage.delete(key: _StorageKeys.decoyProfilesKey);

      await _databaseService.deleteDatabaseFile();

      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Failed to reset master password: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> setupPanicMode(String panicPassword) async {
    try {
      final hash = HashHelper.hashPassword(panicPassword);
      await _secureStorage.write(key: _StorageKeys.panicPasswordHash, value: hash);
      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Failed to setup panic mode: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> setupDecoyProfile(String pin, String profileName) async {
    try {
      final String? existingJson = await _secureStorage.read(key: _StorageKeys.decoyProfilesKey);
      Map<String, dynamic> profiles = {};
      if (existingJson != null) {
        profiles = Map<String, dynamic>.from(jsonDecode(existingJson));
      }
      final hash = HashHelper.hashPassword(pin);
      profiles[profileName.toLowerCase().trim()] = hash;
      await _secureStorage.write(key: _StorageKeys.decoyProfilesKey, value: jsonEncode(profiles));
      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Failed to setup decoy profile: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> getDecoyProfiles() async {
    try {
      final String? existingJson = await _secureStorage.read(key: _StorageKeys.decoyProfilesKey);
      if (existingJson == null) {
        return const Right({});
      }
      final rawMap = Map<String, dynamic>.from(jsonDecode(existingJson));
      final Map<String, String> result = {};
      rawMap.forEach((key, value) {
        result[key] = 'Decoy Profile Active';
      });
      return Right(result);
    } catch (e) {
      return Left(StorageFailure('Failed to fetch decoy profiles: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteDecoyProfile(String profileName) async {
    try {
      final String? existingJson = await _secureStorage.read(key: _StorageKeys.decoyProfilesKey);
      if (existingJson != null) {
        final Map<String, dynamic> profiles = Map<String, dynamic>.from(jsonDecode(existingJson));
        profiles.remove(profileName.toLowerCase().trim());
        await _secureStorage.write(key: _StorageKeys.decoyProfilesKey, value: jsonEncode(profiles));
      }
      return const Right(true);
    } catch (e) {
      return Left(AuthFailure('Failed to delete decoy profile: ${e.toString()}'));
    }
  }
}
