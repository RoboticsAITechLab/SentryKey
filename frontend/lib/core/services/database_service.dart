import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../utils/auth_session.dart';

class DatabaseService {
  static Database? _database;
  static String? _activeMasterKey;

  /// Returns the current active master password key in memory.
  String? get activeMasterKey => _activeMasterKey;

  Future<Database> get database async {
    if (_database != null) return _database!;
    throw Exception('Database not initialized. Call initDatabase first.');
  }

  /// Initializes the SQLCipher database with the provided masterKey,
  /// dynamically isolating the Honey-pot decoy profiles if active.
  Future<void> initDatabase(String masterKey, {bool isDuress = false}) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _activeMasterKey = masterKey;

    final databasesPath = await getDatabasesPath();
    final String dbName;
    if (isDuress) {
      final profile = AuthSession.activeDuressProfile;
      dbName = profile == 'default' ? 'sentrykey_vault_duress.db' : 'sentrykey_vault_duress_$profile.db';
    } else {
      dbName = 'sentrykey_vault.db';
    }
    
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
    _activeMasterKey = null;

    await deleteDatabase(path);
  }

  /// Safely closes the active SQLCipher database connection.
  Future<void> closeDatabase({bool clearKey = true}) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    if (clearKey) {
      _activeMasterKey = null;
    }
  }
}
