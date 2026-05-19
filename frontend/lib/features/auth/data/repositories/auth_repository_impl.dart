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
      // The plain password is NEVER written to disk.
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
      final isPanic = panicHash != null && HashHelper.verifyPassword(masterPassword, panicHash);

      if (!isValid && !isPanic) {
        return const Left(AuthFailure('Incorrect master password.'));
      }

      // Password is correct — unlock the encrypted vault or duress vault.
      AuthSession.isDuressMode = isPanic;
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
      // 1. Delete from secure storage
      await _secureStorage.delete(key: _StorageKeys.passwordHash);
      await _secureStorage.delete(key: _StorageKeys.isRegistered);

      // 2. Delete the actual database
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
      return Left(AuthFailure('Failed to setup panic mode: \${e.toString()}'));
    }
  }
}
