import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

import 'core/services/biometric_storage_service.dart';
import 'core/services/database_service.dart';
import 'core/services/encryption_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/vault/data/repositories/vault_repository_impl.dart';
import 'features/vault/domain/repositories/vault_repository.dart';
import 'features/vault/presentation/bloc/vault_bloc.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Call this once in [main()] before [runApp()].
Future<void> initDependencies() async {
  // ─── External / Infrastructure ─────────────────────────────────────────────

  sl.registerLazySingleton(() => const FlutterSecureStorage(
        aOptions: AndroidOptions(),
      ));
  sl.registerLazySingleton(() => LocalAuthentication());
  sl.registerLazySingleton(() => BiometricStorageService(sl(), sl()));
  sl.registerLazySingleton<DatabaseService>(() => DatabaseService());
  sl.registerLazySingleton<EncryptionService>(() => EncryptionService());
  sl.registerLazySingleton<CloudSyncService>(() => CloudSyncService());

  // ─── Auth Feature ───────────────────────────────────────────────────────────

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      secureStorage: sl<FlutterSecureStorage>(),
      databaseService: sl<DatabaseService>(),
      encryptionService: sl<EncryptionService>(),
    ),
  );

  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      authRepository: sl<AuthRepository>(),
      biometricService: sl<BiometricStorageService>(),
    ),
  );

  // ─── Vault Feature ──────────────────────────────────────────────────────────

  sl.registerLazySingleton<VaultRepository>(
    () => VaultRepositoryImpl(
      sl<DatabaseService>(),
      sl<EncryptionService>(),
    ),
  );

  sl.registerFactory<VaultBloc>(
    () => VaultBloc(vaultRepository: sl<VaultRepository>()),
  );

}
