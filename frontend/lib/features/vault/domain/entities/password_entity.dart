import 'package:equatable/equatable.dart';

/// Pure domain entity — no Flutter or database dependencies.
/// All fields here represent DECRYPTED, human-readable data.
class PasswordEntity extends Equatable {
  final String id;
  final String title;
  final String username;
  final String password; // Always plain text in the domain layer
  final String? url;
  final DateTime createdAt;

  const PasswordEntity({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, username, password, url, createdAt];
}
