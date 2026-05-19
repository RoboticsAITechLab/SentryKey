import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

/// Abstract contract for all authentication operations.
/// The data layer provides the concrete implementation.
abstract class AuthRepository {
  /// Registers the user by hashing and securely storing the master password.
  /// Returns [true] on success.
  Future<Either<Failure, bool>> signUp(String masterPassword);

  /// Verifies the master password and unlocks the encrypted vault.
  /// Calls [DatabaseService.initDatabase] on success.
  /// Returns [true] on success.
  Future<Either<Failure, bool>> login(String masterPassword);

  /// Checks if the user has already registered a master password.
  Future<Either<Failure, bool>> isUserRegistered();

  /// Resets the master password and deletes all saved data.
  Future<Either<Failure, bool>> resetMasterPassword();

  /// Sets up a secondary panic/duress password.
  Future<Either<Failure, bool>> setupPanicMode(String panicPassword);
}
