import 'package:equatable/equatable.dart';

class VaultFile extends Equatable {
  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime dateAdded;
  final String extension;

  const VaultFile({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.dateAdded,
    required this.extension,
  });

  @override
  List<Object?> get props => [id, name, path, sizeBytes, dateAdded, extension];
}
