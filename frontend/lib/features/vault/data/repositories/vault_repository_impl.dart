import 'dart:convert';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/encryption_service.dart';
import '../../domain/repositories/vault_repository.dart';
import '../models/secret_entry.dart';

class VaultRepositoryImpl implements VaultRepository {
  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;

  VaultRepositoryImpl(this._databaseService, this._encryptionService);

  @override
  Future<Either<Failure, bool>> addSecret(SecretEntry secret) async {
    try {
      final db = await _databaseService.database;

      // 1. Serialize dynamic data to JSON string
      final jsonString = json.encode(secret.data);

      // 2. Encrypt the JSON string using AES-256
      final encryptedString = _encryptionService.encryptData(jsonString);

      // 3. Perform a safe, intelligent non-destructive merge (newer timestamp wins)
      final existing = await db.query('secrets', where: 'id = ?', whereArgs: [secret.id]);
      if (existing.isNotEmpty) {
        final existingTs = DateTime.parse(existing.first['timestamp'] as String);
        if (secret.timestamp.isAfter(existingTs)) {
          await db.update(
            'secrets', 
            secret.toMap(encryptedString), 
            where: 'id = ?', 
            whereArgs: [secret.id],
          );
        }
      } else {
        await db.insert('secrets', secret.toMap(encryptedString));
      }

      return const Right(true);
    } catch (e) {
      return Left(StorageFailure('Failed to add secret: \${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SecretEntry>>> getSecrets() async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query('secrets', orderBy: 'timestamp DESC');

      final secrets = <SecretEntry>[];

      for (final map in maps) {
        // 1. Extract encrypted data
        final encryptedString = map['encrypted_data'] as String;

        // 2. Decrypt AES-256 to get JSON string
        final decryptedString = _encryptionService.decryptData(encryptedString);

        // 3. Build SecretEntry
        secrets.add(SecretEntry.fromMap(map, decryptedString));
      }

      return Right(secrets);
    } catch (e) {
      return Left(StorageFailure('Failed to fetch secrets: \${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteSecret(String id) async {
    try {
      final db = await _databaseService.database;
      await db.delete('secrets', where: 'id = ?', whereArgs: [id]);
      return const Right(true);
    } catch (e) {
      return Left(StorageFailure('Failed to delete secret: \${e.toString()}'));
    }
  }
}
