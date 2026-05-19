import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    throw Exception('Database not initialized. Call initDatabase first.');
  }

  /// Initializes the SQLCipher database with the provided masterKey
  Future<void> initDatabase(String masterKey, {bool isDuress = false}) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final databasesPath = await getDatabasesPath();
    final dbName = isDuress ? 'sentrykey_vault_duress.db' : 'sentrykey_vault.db';
    final path = join(databasesPath, dbName);

    _database = await openDatabase(
      path,
      password: masterKey,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE secrets (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            encrypted_data TEXT NOT NULL,
            is_favorite INTEGER NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }
  /// Deletes the SQLCipher database file entirely.
  Future<void> deleteDatabaseFile() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'sentrykey_vault.db');

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    await deleteDatabase(path);
  }
}
