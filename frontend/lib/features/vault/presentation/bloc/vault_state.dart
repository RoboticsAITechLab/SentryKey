part of 'vault_bloc.dart';

abstract class VaultState extends Equatable {
  const VaultState();

  @override
  List<Object?> get props => [];
}

/// Initial state — vault has not been loaded yet.
class VaultInitial extends VaultState {
  const VaultInitial();
}

/// DB query is in progress.
class VaultLoading extends VaultState {
  const VaultLoading();
}

/// Successfully loaded (or refreshed) the password list.
class VaultLoaded extends VaultState {
  final List<SecretEntry> passwords;

  const VaultLoaded({required this.passwords});

  @override
  List<Object?> get props => [passwords];
}

/// A CRUD operation failed.
class VaultError extends VaultState {
  final String message;

  const VaultError({required this.message});

  @override
  List<Object?> get props => [message];
}
