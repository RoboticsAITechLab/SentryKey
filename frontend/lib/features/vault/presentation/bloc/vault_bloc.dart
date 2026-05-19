import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/secret_entry.dart';
import '../../domain/repositories/vault_repository.dart';

part 'vault_event.dart';
part 'vault_state.dart';

class VaultBloc extends Bloc<VaultEvent, VaultState> {
  final VaultRepository _vaultRepository;

  VaultBloc({required VaultRepository vaultRepository})
      : _vaultRepository = vaultRepository,
        super(const VaultInitial()) {
    on<LoadVault>(_onLoadVault);
    on<AddEntry>(_onAddEntry);
    on<DeleteEntry>(_onDeleteEntry);
  }

  /// Fetches all decrypted secrets from the repository.
  Future<void> _onLoadVault(
    LoadVault event,
    Emitter<VaultState> emit,
  ) async {
    emit(const VaultLoading());
    final result = await _vaultRepository.getSecrets();
    result.fold(
      (failure) => emit(VaultError(message: failure.message)),
      (secrets) => emit(VaultLoaded(passwords: secrets)),
    );
  }

  /// Saves a new entry and refreshes the list on success.
  Future<void> _onAddEntry(
    AddEntry event,
    Emitter<VaultState> emit,
  ) async {
    final result = await _vaultRepository.addSecret(event.secret);
    result.fold(
      (failure) => emit(VaultError(message: failure.message)),
      (_) => add(const LoadVault()), // refresh list after add
    );
  }

  /// Deletes an entry by ID and refreshes the list on success.
  Future<void> _onDeleteEntry(
    DeleteEntry event,
    Emitter<VaultState> emit,
  ) async {
    final result = await _vaultRepository.deleteSecret(event.id);
    result.fold(
      (failure) => emit(VaultError(message: failure.message)),
      (_) => add(const LoadVault()), // refresh list after delete
    );
  }
}

