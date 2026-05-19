import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/secret_entry.dart';

abstract class VaultRepository {
  /// Adds a new secret to the vault.
  Future<Either<Failure, bool>> addSecret(SecretEntry secret);

  /// Retrieves all secrets from the vault.
  Future<Either<Failure, List<SecretEntry>>> getSecrets();

  /// Deletes a secret by its ID.
  Future<Either<Failure, bool>> deleteSecret(String id);
}
