part of 'vault_bloc.dart';

abstract class VaultEvent extends Equatable {
  const VaultEvent();

  @override
  List<Object?> get props => [];
}

/// Triggered when the vault screen is opened — loads all passwords.
class LoadVault extends VaultEvent {
  const LoadVault();
}

/// Triggered when the user submits the "Add Password" form.
class AddEntry extends VaultEvent {
  final SecretEntry secret;

  const AddEntry(this.secret);

  @override
  List<Object?> get props => [secret];
}

/// Triggered when the user taps Delete on a password card.
class DeleteEntry extends VaultEvent {
  final String id;

  const DeleteEntry({required this.id});

  @override
  List<Object?> get props => [id];
}
