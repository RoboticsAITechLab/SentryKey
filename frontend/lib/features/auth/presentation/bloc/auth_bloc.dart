import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/biometric_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final BiometricStorageService _biometricService;

  AuthBloc({
    required AuthRepository authRepository,
    required BiometricStorageService biometricService,
  })  : _authRepository = authRepository,
        _biometricService = biometricService,
        super(const AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SignUpRequested>(_onSignUpRequested);
    on<LoginRequested>(_onLoginRequested);
    on<ResetRequested>(_onResetRequested);
    
    // Biometric Events
    on<CheckBiometricAvailability>(_onCheckBiometricAvailability);
    on<EnableBiometricRequested>(_onEnableBiometricRequested);
    on<LoginWithBiometricRequested>(_onLoginWithBiometricRequested);
  }

  /// On app start, check if a master password already exists.
  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _authRepository.isUserRegistered();

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (isRegistered) => isRegistered
          ? emit(const ExistingUser()) // Has password → show login
          : emit(const NewUser()),     // No password  → show sign-up
    );
  }

  /// Handles new user registration flow.
  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _authRepository.signUp(event.masterPassword);

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(const Authenticated()),
    );
  }

  /// Handles existing user login flow.
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _authRepository.login(event.masterPassword);

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(const Authenticated()),
    );
  }

  /// Handles resetting the master password.
  Future<void> _onResetRequested(
    ResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _authRepository.resetMasterPassword();

    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (_) => emit(const NewUser()), // Reset successful, go back to sign-up
    );
  }

  /// ---------------------------------------------------------
  /// Advanced Biometric Logic
  /// ---------------------------------------------------------

  /// Determines if the device supports biometric auth and broadcasts status.
  Future<void> _onCheckBiometricAvailability(
    CheckBiometricAvailability event,
    Emitter<AuthState> emit,
  ) async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    // Yield the status for UI listeners, then revert to the base visual state
    emit(BiometricStatusChecked(isAvailable: isAvailable));
    emit(const ExistingUser());
  }

  /// Stores the verified master password securely in the Keystore/Keychain.
  Future<void> _onEnableBiometricRequested(
    EnableBiometricRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // 1. Re-verify the provided master password before saving it
      final verifyResult = await _authRepository.login(event.masterPassword);

      if (verifyResult.isLeft()) {
        final failureMessage = verifyResult.fold((l) => l.message, (r) => 'Unknown error');
        emit(BiometricAuthFailure(message: 'Verification failed: $failureMessage'));
        emit(const Authenticated()); // Keep user in the authenticated dashboard
        return;
      }

      // 2. Attempt to securely store the key via native biometric prompt
      await _biometricService.enableBiometricUnlock(event.masterPassword);
      
      emit(const BiometricSetupSuccess());
      emit(const Authenticated()); // Proceed securely
    } catch (e) {
      emit(BiometricAuthFailure(message: 'Enable Biometrics Error: ${e.toString()}'));
      emit(const Authenticated()); // Keeps UI from getting stuck if enable fails
    }
  }

  /// Handles hardware-backed biometric unlock to fetch the stored DB key.
  Future<void> _onLoginWithBiometricRequested(
    LoginWithBiometricRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final storedKey = await _biometricService.unlockWithBiometrics();
      
      if (storedKey != null) {
        // Authenticate database using the securely retrieved hardware-backed key
        final result = await _authRepository.login(storedKey);
        
        result.fold(
          (failure) {
            emit(BiometricAuthFailure(message: failure.message));
            emit(const ExistingUser());
          },
          (_) {
            emit(const BiometricAuthSuccess());
            emit(const Authenticated());
          },
        );
      } else {
        emit(const BiometricAuthFailure(
          message: 'Biometric setup not found. Please login with your Master Password first to enable it.',
        ));
        emit(const ExistingUser());
      }
    } catch (e) {
      emit(BiometricAuthFailure(message: e.toString()));
      emit(const ExistingUser());
    }
  }
}
