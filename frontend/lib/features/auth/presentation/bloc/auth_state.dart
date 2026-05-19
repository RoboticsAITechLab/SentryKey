part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

/// Initial state — the app is deciding what to show.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A background operation is in progress (login, sign-up, biometric auth).
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No master password has been set — show the Sign Up screen.
class NewUser extends AuthState {
  const NewUser();
}

/// A master password exists but the vault is locked — show the Login screen.
class ExistingUser extends AuthState {
  const ExistingUser();
}

/// Master password verified — the vault is unlocked.
class Authenticated extends AuthState {
  const Authenticated();
}

/// An operation failed (wrong password, storage error, etc.).
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object> get props => [message];
}

/// ---------------------------------------------------------
/// Advanced Biometric States
/// ---------------------------------------------------------

/// Emitted after checking if biometrics are available on the device.
/// The UI listens to this state to show/hide the biometric login button.
class BiometricStatusChecked extends AuthState {
  final bool isAvailable;

  const BiometricStatusChecked({required this.isAvailable});

  @override
  List<Object> get props => [isAvailable];
}

/// Emitted when biometric authentication succeeds, yielding the stored key
/// to unlock the database successfully.
class BiometricAuthSuccess extends AuthState {
  const BiometricAuthSuccess();
}

/// Emitted when biometric authentication fails or is cancelled.
class BiometricAuthFailure extends AuthState {
  final String message;

  const BiometricAuthFailure({required this.message});

  @override
  List<Object> get props => [message];
}

/// Emitted when the user successfully stores their master password
/// in the hardware-backed keystore for future biometric unlock.
class BiometricSetupSuccess extends AuthState {
  const BiometricSetupSuccess();
}
