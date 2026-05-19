part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

/// Fired on app start to determine the initial auth state.
class AppStarted extends AuthEvent {
  const AppStarted();
}

/// Fired when the user submits the sign-up form.
class SignUpRequested extends AuthEvent {
  final String masterPassword;

  const SignUpRequested({required this.masterPassword});

  @override
  List<Object> get props => [masterPassword];
}

/// Fired when the user submits the login form.
class LoginRequested extends AuthEvent {
  final String masterPassword;

  const LoginRequested({required this.masterPassword});

  @override
  List<Object> get props => [masterPassword];
}

/// Fired when the user requests to reset the master password (deletes the vault).
class ResetRequested extends AuthEvent {
  const ResetRequested();
}

/// ---------------------------------------------------------
/// Advanced Biometric Events
/// ---------------------------------------------------------

/// Fired automatically to check if the current device supports biometrics.
class CheckBiometricAvailability extends AuthEvent {
  const CheckBiometricAvailability();
}

/// Fired when the user opts-in to enable biometric unlock.
/// We pass the plain text master password so it can be securely
/// stored in the hardware-backed keystore.
class EnableBiometricRequested extends AuthEvent {
  final String masterPassword;

  const EnableBiometricRequested({required this.masterPassword});

  @override
  List<Object> get props => [masterPassword];
}

/// Fired when the user taps the 'Unlock with Biometrics' button.
class LoginWithBiometricRequested extends AuthEvent {
  const LoginWithBiometricRequested();
}
