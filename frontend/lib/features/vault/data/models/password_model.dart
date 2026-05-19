import '../../domain/entities/password_entity.dart';

/// Data Transfer Object — maps between DB rows and domain entities.
/// Encryption/decryption happens OUTSIDE this class (in the repository).
class PasswordModel extends PasswordEntity {
  const PasswordModel({
    required super.id,
    required super.title,
    required super.username,
    required super.password,
    super.url,
    required super.createdAt,
  });

  /// Converts a raw SQLite map row into a [PasswordModel].
  /// NOTE: The [password] field here is still encrypted — the repository
  /// is responsible for decrypting it before exposing to the domain.
  factory PasswordModel.fromMap(Map<String, dynamic> map) {
    return PasswordModel(
      id: map['id'] as String,
      title: map['title'] as String,
      username: map['username'] as String,
      password: map['password'] as String, // encrypted at this stage
      url: map['url'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Converts to a DB-ready map.
  /// NOTE: The [password] field here must already be encrypted before calling.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password, // must be encrypted by caller
      'url': url,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
