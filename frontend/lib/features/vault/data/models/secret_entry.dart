import 'dart:convert';
import 'package:equatable/equatable.dart';

class SecretEntry extends Equatable {
  final String id;
  final String category; // 'Password', 'Bank', 'ID Card', 'Secure Note'
  final Map<String, dynamic> data; // The dynamic fields
  final bool isFavorite;
  final DateTime timestamp;

  const SecretEntry({
    required this.id,
    required this.category,
    required this.data,
    this.isFavorite = false,
    required this.timestamp,
  });

  /// Converts the secret into a map for database storage.
  /// The `data` map should be encrypted before calling this if it's for DB insertion.
  Map<String, dynamic> toMap(String encryptedData) {
    return {
      'id': id,
      'category': category,
      'encrypted_data': encryptedData,
      'is_favorite': isFavorite ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates a SecretEntry from a database row.
  /// Requires the `data` string to be decrypted first.
  factory SecretEntry.fromMap(Map<String, dynamic> map, String decryptedDataJson) {
    return SecretEntry(
      id: map['id'] as String,
      category: map['category'] as String,
      data: json.decode(decryptedDataJson) as Map<String, dynamic>,
      isFavorite: (map['is_favorite'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [id, category, data, isFavorite, timestamp];
}
