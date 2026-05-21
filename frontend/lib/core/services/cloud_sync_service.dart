import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../injection_container.dart';
import 'encryption_service.dart';
import 'database_service.dart';
import '../utils/auth_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

enum SyncErrorType {
  none,
  noInternet,
  notSignedIn,
  authExpired,
  apiLimit,
  noBackupFound,
  fileLock,
  encryptionError,
  unknown,
}

class DriveBackupInfo {
  final String id;
  final String name;
  final DateTime date;
  final int sizeBytes;

  DriveBackupInfo({
    required this.id,
    required this.name,
    required this.date,
    required this.sizeBytes,
  });
}

class SyncResult {
  final bool success;
  final String message;
  final SyncErrorType errorType;

  SyncResult({
    required this.success,
    required this.message,
    this.errorType = SyncErrorType.none,
  });

  factory SyncResult.success(String message) => SyncResult(
        success: true,
        message: message,
        errorType: SyncErrorType.none,
      );

  factory SyncResult.failure(String message, SyncErrorType errorType) => SyncResult(
        success: false,
        message: message,
        errorType: errorType,
      );
}

class CloudSyncService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  final EncryptionService _encryptionService = sl<EncryptionService>();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Google Sign-Out failed: $e');
    }
  }

  Future<bool> isSignedIn() async {
    try {
      final signedIn = await _googleSignIn.isSignedIn();
      if (signedIn) {
        _currentUser = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
        return _currentUser != null;
      }
      return false;
    } catch (e) {
      debugPrint('isSignedIn check failed: $e');
      return false;
    }
  }

  /// Helper to check internet access by looking up google.com or dns.google
  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('dns.google')
            .timeout(const Duration(seconds: 4));
        return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Helper to get the user, refreshing silently if necessary to prevent token expiration
  Future<GoogleSignInAccount?> _getOrRefreshUser() async {
    if (_googleSignIn.currentUser != null) {
      try {
        final user = await _googleSignIn.signInSilently();
        if (user != null) {
          _currentUser = user;
          return user;
        }
      } catch (e) {
        debugPrint('Silent sign-in failed, falling back to current user: $e');
      }
      _currentUser = _googleSignIn.currentUser;
      return _currentUser;
    }

    try {
      final user = await _googleSignIn.signInSilently();
      if (user != null) {
        _currentUser = user;
        return user;
      }
    } catch (e) {
      debugPrint('Silent sign-in from null failed: $e');
    }

    return null;
  }

  /// Helper to execute network operations with exponential backoff retry logic
  Future<T> _retry<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        final delay = Duration(seconds: attempts * 2);
        debugPrint('Network operation failed (attempt $attempts/$maxAttempts). Retrying in ${delay.inSeconds} seconds... Error: $e');
        await Future.delayed(delay);
      }
    }
  }

  /// Fetches the list of all historic backups stored in the Google Drive AppData folder.
  Future<List<DriveBackupInfo>> getBackupHistory() async {
    try {
      final hasInternet = await _hasInternetAccess();
      if (!hasInternet) return [];

      final user = await _getOrRefreshUser();
      if (user == null) return [];

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return [];

      final driveApi = drive.DriveApi(httpClient);
      
      final fileList = await _retry<drive.FileList>(() async {
        return await driveApi.files.list(
          q: "name contains 'sentrykey_backup'",
          spaces: 'appDataFolder',
        );
      });

      if (fileList.files == null) return [];

      final List<DriveBackupInfo> backups = [];
      for (final f in fileList.files!) {
        final name = f.name ?? '';
        final id = f.id ?? '';
        final size = int.tryParse(f.size ?? '0') ?? 0;
        final createdTime = f.createdTime ?? DateTime.now();

        if (name.startsWith('sentrykey_backup') && name.endsWith('.enc')) {
          DateTime date = createdTime;
          // Extract exact timestamp from filename if available
          final match = RegExp(r'sentrykey_backup_(\d+)\.enc').firstMatch(name);
          if (match != null) {
            final ms = int.tryParse(match.group(1) ?? '');
            if (ms != null) {
              date = DateTime.fromMillisecondsSinceEpoch(ms);
            }
          }
          backups.add(DriveBackupInfo(id: id, name: name, date: date, sizeBytes: size));
        }
      }

      // Sort chronological descending (latest backup first)
      backups.sort((a, b) => b.date.compareTo(a.date));
      return backups;
    } catch (e) {
      debugPrint('Failed to fetch backup history: $e');
      return [];
    }
  }

  /// Keeps the backup storage footprint clean by maintaining only the last 3 backups.
  Future<void> _pruneOldBackups(drive.DriveApi driveApi) async {
    try {
      final fileList = await driveApi.files.list(
        q: "name contains 'sentrykey_backup'",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) return;

      final List<drive.File> backups = [];
      for (final f in fileList.files!) {
        final name = f.name ?? '';
        if (name.startsWith('sentrykey_backup') && name.endsWith('.enc')) {
          backups.add(f);
        }
      }

      if (backups.length <= 3) return;

      // Sort chronological ascending (oldest first)
      backups.sort((a, b) {
        final aName = a.name ?? '';
        final bName = b.name ?? '';
        return aName.compareTo(bName);
      });

      final numToDelete = backups.length - 3;
      for (int i = 0; i < numToDelete; i++) {
        final id = backups[i].id!;
        await driveApi.files.delete(id);
        debugPrint('Pruned oldest backup version from Drive AppData: ${backups[i].name}');
      }
    } catch (e) {
      debugPrint('Failed to prune old backups: $e');
    }
  }

  Future<SyncResult> backupToCloud() async {
    try {
      // 1. Check internet connection
      final hasInternet = await _hasInternetAccess();
      if (!hasInternet) {
        return SyncResult.failure(
          'No internet connection. Please check your network and try again.',
          SyncErrorType.noInternet,
        );
      }

      // 2. Ensure signed in and refresh credentials
      final user = await _getOrRefreshUser();
      if (user == null) {
        return SyncResult.failure(
          'Google Account not connected or session expired. Please reconnect.',
          SyncErrorType.notSignedIn,
        );
      }

      // 3. Get authenticated client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure(
          'Failed to authenticate with Google Services. Please sign out and sign in again.',
          SyncErrorType.authExpired,
        );
      }

      final driveApi = drive.DriveApi(httpClient);
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      // 4. Zipping database and files safely
      final zipFile = File(p.join(tempDir.path, 'vault_backup.zip'));
      if (zipFile.existsSync()) {
        try {
          zipFile.deleteSync();
        } catch (_) {}
      }

      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);

      // SQLCipher Databases Backup
      final dbPath = await getDatabasesPath();
      final dbService = sl<DatabaseService>();
      final isPanic = AuthSession.isDuressMode;

      // Discover and dynamically pack all databases matching sentrykey_vault*.db
      final activeDbName = isPanic 
          ? (AuthSession.activeDuressProfile == 'default' ? 'sentrykey_vault_duress.db' : 'sentrykey_vault_duress_${AuthSession.activeDuressProfile}.db')
          : 'sentrykey_vault.db';

      final dbDir = Directory(dbPath);
      if (dbDir.existsSync()) {
        for (final entity in dbDir.listSync()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            if (fileName.startsWith('sentrykey_vault') && fileName.endsWith('.db')) {
              if (fileName == activeDbName) {
                // Perform transactional safe VACUUM INTO for the active db
                final tempActiveDbPath = p.join(tempDir.path, fileName);
                final tempActiveDbFile = File(tempActiveDbPath);
                if (tempActiveDbFile.existsSync()) {
                  try { tempActiveDbFile.deleteSync(); } catch (_) {}
                }
                try {
                  final activeDbConnection = await dbService.database;
                  await activeDbConnection.execute("VACUUM INTO '$tempActiveDbPath'");
                  if (tempActiveDbFile.existsSync()) {
                    encoder.addFile(tempActiveDbFile);
                    debugPrint('Transactional safe copy of active database $fileName created via VACUUM INTO.');
                  }
                } catch (e) {
                  debugPrint('VACUUM INTO failed for $fileName, falling back to direct copy: $e');
                  encoder.addFile(entity);
                }
              } else {
                // Inactive database, safe to copy directly
                encoder.addFile(entity);
              }
            }
          }
        }
      }

      // Discover and pack all folders starting with sentry_vault_files
      if (appDir.existsSync()) {
        for (final entity in appDir.listSync()) {
          if (entity is Directory) {
            final dirName = p.basename(entity.path);
            if (dirName.startsWith('sentry_vault_files')) {
              encoder.addDirectory(entity);
            }
          }
        }
      }

      // Discover all custom decoy profiles and dynamically write their metadata files to ZIP
      final decoyRes = await sl<AuthRepository>().getDecoyProfiles();
      final List<String> metadataKeys = ['vault_files_metadata', 'vault_files_metadata_duress'];
      decoyRes.fold(
        (_) => null,
        (profiles) {
          for (final key in profiles.keys) {
            metadataKeys.add('vault_files_metadata_duress_$key');
          }
        }
      );

      final List<File> tempMetadataFiles = [];
      for (final key in metadataKeys) {
        final val = await _secureStorage.read(key: key) ?? '[]';
        final file = File(p.join(tempDir.path, '$key.json'));
        file.writeAsStringSync(val);
        encoder.addFile(file);
        tempMetadataFiles.add(file);
      }

      encoder.close();

      // Clean up temp metadata files immediately
      for (final f in tempMetadataFiles) {
        try { if (f.existsSync()) f.deleteSync(); } catch (_) {}
      }
      // Clean up active temp db copies
      if (dbDir.existsSync()) {
        for (final entity in dbDir.listSync()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final tempF = File(p.join(tempDir.path, fileName));
            try { if (tempF.existsSync()) tempF.deleteSync(); } catch (_) {}
          }
        }
      }

      // 5. Encrypting the Zip archive
      if (!zipFile.existsSync()) {
        return SyncResult.failure(
          'Failed to build local backup archive.',
          SyncErrorType.unknown,
        );
      }

      final zipBytes = zipFile.readAsBytesSync();
      if (zipBytes.isEmpty) {
        return SyncResult.failure(
          'Backup archive is empty. Nothing to back up.',
          SyncErrorType.unknown,
        );
      }

      final base64Zip = base64Encode(zipBytes);
      final encryptedData = _encryptionService.encryptData(base64Zip);

      // Save encrypted file locally first
      final encFile = File(p.join(tempDir.path, 'sentrykey_backup.enc'));
      encFile.writeAsStringSync(encryptedData);

      // 6. Upload to Google Drive AppData folder with dynamic timestamp name and robust retry logic
      final media = drive.Media(encFile.openRead(), encFile.lengthSync());
      final String timestampedName = 'sentrykey_backup_${DateTime.now().millisecondsSinceEpoch}.enc';
      
      final driveFile = drive.File()
        ..name = timestampedName
        ..parents = ['appDataFolder'];

      final SyncResult uploadResult = await _retry<SyncResult>(() async {
        final uploaded = await driveApi.files.create(driveFile, uploadMedia: media);
        debugPrint('Backup successfully uploaded to Google Drive as: ${uploaded.name}');
        
        // Auto-prune old backups to keep exactly 3 historic backups
        await _pruneOldBackups(driveApi);

        return SyncResult.success('Vault backup successfully uploaded to Google Drive!');
      });

      // Clean up local temp files
      try {
        if (encFile.existsSync()) encFile.deleteSync();
        if (zipFile.existsSync()) zipFile.deleteSync();
      } catch (_) {}

      return uploadResult;
    } catch (e) {
      debugPrint('Cloud backup failed: $e');
      if (e is SocketException || e is HttpException || e.toString().contains('connection')) {
        return SyncResult.failure(
          'Network connection lost. Please check your signal and try again.',
          SyncErrorType.noInternet,
        );
      }
      return SyncResult.failure(
        'Cloud backup failed: ${e.toString()}',
        SyncErrorType.unknown,
      );
    }
  }

  /// Performs an intelligent programmatic two-way merge of backup database secrets
  /// into the active database, utilizing a newer-timestamp-wins conflict resolution strategy.
  Future<void> _mergeDatabase({
    required File backupDbFile,
    required Database localDb,
    required String password,
  }) async {
    final tempPath = p.join(backupDbFile.parent.path, 'temp_merge.db');
    final tempFile = File(tempPath);
    if (tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
      } catch (_) {}
    }
    
    // Copy backup database bytes to temporary location
    await backupDbFile.copy(tempPath);

    Database? tempDb;
    try {
      tempDb = await openDatabase(tempPath, password: password);
      final List<Map<String, dynamic>> backupSecrets = await tempDb.query('secrets');
      
      for (final backupSecret in backupSecrets) {
        final String id = backupSecret['id'] as String;
        final String category = backupSecret['category'] as String;
        final String encryptedData = backupSecret['encrypted_data'] as String;
        final int isFavorite = backupSecret['is_favorite'] as int;
        final String timestampStr = backupSecret['timestamp'] as String;

        // Check if the secret exists locally
        final List<Map<String, dynamic>> localMatch = await localDb.query(
          'secrets',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (localMatch.isEmpty) {
          // New secret found in backup: insert it locally!
          await localDb.insert('secrets', {
            'id': id,
            'category': category,
            'encrypted_data': encryptedData,
            'is_favorite': isFavorite,
            'timestamp': timestampStr,
          });
        } else {
          // Conflict: compare timestamps!
          final String localTimestampStr = localMatch.first['timestamp'] as String;
          try {
            final DateTime backupTime = DateTime.parse(timestampStr);
            final DateTime localTime = DateTime.parse(localTimestampStr);

            if (backupTime.isAfter(localTime)) {
              // Backup record is newer: update the local entry!
              await localDb.update(
                'secrets',
                {
                  'category': category,
                  'encrypted_data': encryptedData,
                  'is_favorite': isFavorite,
                  'timestamp': timestampStr,
                },
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          } catch (_) {
            // Fallback: update if parsing fails
            await localDb.update(
              'secrets',
              {
                'category': category,
                'encrypted_data': encryptedData,
                'is_favorite': isFavorite,
                'timestamp': timestampStr,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    } finally {
      if (tempDb != null && tempDb.isOpen) {
        await tempDb.close();
      }
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Safely merges backup secure file metadata into local secure storage metadata list,
  /// extracting missing files from the ZIP archive and dynamically configuring absolute paths.
  Future<void> _mergeFileMetadata({
    required String localKey,
    required String backupJsonStr,
    required Directory appDir,
    required Archive archive,
    required String fileFolderPrefix,
  }) async {
    final localJsonStr = await _secureStorage.read(key: localKey) ?? '[]';
    
    List<dynamic> localList = [];
    try {
      localList = jsonDecode(localJsonStr) as List<dynamic>;
    } catch (_) {}

    List<dynamic> backupList = [];
    try {
      backupList = jsonDecode(backupJsonStr) as List<dynamic>;
    } catch (_) {}

    final Map<String, dynamic> localMap = {
      for (var item in localList) item['id'].toString(): item
    };

    for (final backupItem in backupList) {
      final String id = backupItem['id'].toString();
      final String name = backupItem['name'].toString();
      final String relativePath = backupItem['path'].toString();
      final int sizeBytes = backupItem['sizeBytes'] as int;
      final String dateAddedStr = backupItem['dateAdded'].toString();
      final String extension = backupItem['extension'].toString();

      if (!localMap.containsKey(id)) {
        final String baseFilename = p.basename(relativePath);
        final String zipFilePath = '$fileFolderPrefix$baseFilename';
        
        final zipEntry = archive.findFile(zipFilePath);
        if (zipEntry != null && zipEntry.isFile) {
          final fileData = zipEntry.content as List<int>;
          
          final localFilesDir = Directory(p.join(appDir.path, fileFolderPrefix));
          if (!localFilesDir.existsSync()) {
            await localFilesDir.create(recursive: true);
          }
          
          // Construct the path dynamically (adapting if application path changed on new device)
          final localFilePath = p.join(localFilesDir.path, baseFilename);
          final localFile = File(localFilePath);
          await localFile.writeAsBytes(fileData, flush: true);

          localList.add({
            'id': id,
            'name': name,
            'path': localFilePath,
            'sizeBytes': sizeBytes,
            'dateAdded': dateAddedStr,
            'extension': extension,
          });
        }
      }
    }

    final String mergedJsonStr = jsonEncode(localList);
    await _secureStorage.write(key: localKey, value: mergedJsonStr);
  }

  Future<SyncResult> restoreFromCloud({String? backupId}) async {
    try {
      // 1. Check internet connection
      final hasInternet = await _hasInternetAccess();
      if (!hasInternet) {
        return SyncResult.failure(
          'No internet connection. Please check your network and try again.',
          SyncErrorType.noInternet,
        );
      }

      // 2. Ensure signed in and refresh credentials
      final user = await _getOrRefreshUser();
      if (user == null) {
        return SyncResult.failure(
          'Google Account not connected or session expired. Please reconnect.',
          SyncErrorType.notSignedIn,
        );
      }

      // 3. Get authenticated client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure(
          'Failed to authenticate with Google Services. Please sign out and sign in again.',
          SyncErrorType.authExpired,
        );
      }

      final driveApi = drive.DriveApi(httpClient);

      // 4. Locate the specific target backup ID or fallback to the latest backup
      String targetBackupId;
      if (backupId != null && backupId.isNotEmpty) {
        targetBackupId = backupId;
      } else {
        final fileList = await _retry<drive.FileList>(() async {
          return await driveApi.files.list(
            q: "name contains 'sentrykey_backup'",
            spaces: 'appDataFolder',
          );
        });

        if (fileList.files == null || fileList.files!.isEmpty) {
          debugPrint('No backup found on Google Drive.');
          return SyncResult.failure(
            'No backup found on Google Drive. Please create a backup first.',
            SyncErrorType.noBackupFound,
          );
        }

        final List<drive.File> backups = [];
        for (final f in fileList.files!) {
          final name = f.name ?? '';
          if (name.startsWith('sentrykey_backup') && name.endsWith('.enc')) {
            backups.add(f);
          }
        }

        if (backups.isEmpty) {
          return SyncResult.failure(
            'No backup found on Google Drive. Please create a backup first.',
            SyncErrorType.noBackupFound,
          );
        }

        // Sort descending (latest name/timestamp first)
        backups.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
        targetBackupId = backups.first.id!;
      }

      // 5. Download the encrypted file with robust retry logic
      final drive.Media media = await _retry<drive.Media>(() async {
        return await driveApi.files.get(
          targetBackupId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
      });

      final tempDir = await getTemporaryDirectory();
      final downloadFile = File(p.join(tempDir.path, 'downloaded_backup.enc'));
      if (downloadFile.existsSync()) {
        try {
          downloadFile.deleteSync();
        } catch (_) {}
      }
      
      final iosSink = downloadFile.openWrite();
      await media.stream.pipe(iosSink);
      await iosSink.close();

      // 6. Decrypt the backup
      if (!downloadFile.existsSync()) {
        return SyncResult.failure(
          'Failed to write the downloaded backup file locally.',
          SyncErrorType.unknown,
        );
      }

      final encryptedData = downloadFile.readAsStringSync();
      if (encryptedData.isEmpty) {
        return SyncResult.failure(
          'Downloaded backup file is empty.',
          SyncErrorType.encryptionError,
        );
      }

      String decryptedBase64;
      try {
        decryptedBase64 = _encryptionService.decryptData(encryptedData);
      } catch (e) {
        return SyncResult.failure(
          'Decryption failed. The master key does not match this backup.',
          SyncErrorType.encryptionError,
        );
      }

      final zipBytes = base64Decode(decryptedBase64);
      final zipFile = File(p.join(tempDir.path, 'restored_backup.zip'));
      zipFile.writeAsBytesSync(zipBytes);

      // 7. Extract Zip File safely
      final bytes = zipFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = await getDatabasesPath();

      // Discover, unpack database files and metadata strings from zip dynamically
      final Map<String, File> backupDbFiles = {};
      final Map<String, String> backupMetadataStrings = {};

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          
          if (filename.startsWith('sentrykey_vault') && filename.endsWith('.db')) {
            final backupFile = File(p.join(tempDir.path, 'backup_$filename'));
            await backupFile.writeAsBytes(data, flush: true);
            backupDbFiles[filename] = backupFile;
          } else if (filename.endsWith('.json') && filename.startsWith('vault_files_metadata')) {
            final keyName = filename.replaceFirst('.json', '');
            backupMetadataStrings[keyName] = utf8.decode(data);
          }
        }
      }

      // 8. Programmatic Non-Destructive Two-Way Sync / Merge
      final dbService = sl<DatabaseService>();
      final localDb = await dbService.database;
      final String? activePassword = dbService.activeMasterKey;

      if (activePassword == null) {
        return SyncResult.failure(
          'Failed to retrieve active session master key. Please restart the app.',
          SyncErrorType.authExpired,
        );
      }

      // Merge files and metadata dynamically
      for (final entry in backupMetadataStrings.entries) {
        final key = entry.key;
        final val = entry.value;
        
        final String folderPrefix;
        if (key == 'vault_files_metadata') {
          folderPrefix = 'sentry_vault_files/';
        } else if (key == 'vault_files_metadata_duress') {
          folderPrefix = 'sentry_vault_files_duress/';
        } else {
          final suffix = key.replaceFirst('vault_files_metadata_duress_', '');
          folderPrefix = 'sentry_vault_files_duress_$suffix/';
        }

        await _mergeFileMetadata(
          localKey: key,
          backupJsonStr: val,
          appDir: appDir,
          archive: archive,
          fileFolderPrefix: folderPrefix,
        );
      }

      // Merge databases dynamically
      final activeDbName = AuthSession.isDuressMode 
          ? (AuthSession.activeDuressProfile == 'default' ? 'sentrykey_vault_duress.db' : 'sentrykey_vault_duress_${AuthSession.activeDuressProfile}.db')
          : 'sentrykey_vault.db';

      for (final entry in backupDbFiles.entries) {
        final dbName = entry.key;
        final backupDbFile = entry.value;

        if (dbName == activeDbName) {
          // A. Active Database: merge programmatically
          try {
            await _mergeDatabase(
              backupDbFile: backupDbFile,
              localDb: localDb,
              password: activePassword,
            );
          } catch (e) {
            debugPrint('Failed to merge active database $dbName: $e');
            return SyncResult.failure(
              'Failed to merge the active vault database. Ensure your master key matches the backup.',
              SyncErrorType.encryptionError,
            );
          }
        } else {
          // B. Inactive Database: overwrite directly
          final targetDb = File(p.join(dbPath, dbName));
          if (targetDb.existsSync()) {
            try { targetDb.deleteSync(); } catch (_) {}
          }
          await backupDbFile.copy(targetDb.path);
        }
      }

      // Cleanup temporary backup files
      try {
        for (final f in backupDbFiles.values) {
          if (f.existsSync()) f.deleteSync();
        }
        if (downloadFile.existsSync()) downloadFile.deleteSync();
        if (zipFile.existsSync()) zipFile.deleteSync();
      } catch (_) {}

      return SyncResult.success('Vault backup merged successfully! No local data was lost.');
    } catch (e) {
      debugPrint('Cloud restore failed: $e');
      if (e is SocketException || e is HttpException || e.toString().contains('connection')) {
        return SyncResult.failure(
          'Network connection lost. Please check your signal and try again.',
          SyncErrorType.noInternet,
        );
      }
      return SyncResult.failure(
        'Cloud restore failed: ${e.toString()}',
        SyncErrorType.unknown,
      );
    }
  }

  /// Deletes a specific backup from Google Drive.
  Future<SyncResult> deleteBackupFromCloud(String backupId) async {
    try {
      final hasInternet = await _hasInternetAccess();
      if (!hasInternet) {
        return SyncResult.failure(
          'No internet connection. Please check your network and try again.',
          SyncErrorType.noInternet,
        );
      }

      final user = await _getOrRefreshUser();
      if (user == null) {
        return SyncResult.failure(
          'Google Account not connected or session expired. Please reconnect.',
          SyncErrorType.notSignedIn,
        );
      }

      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        return SyncResult.failure(
          'Failed to authenticate with Google Services. Please sign out and sign in again.',
          SyncErrorType.authExpired,
        );
      }

      final driveApi = drive.DriveApi(httpClient);
      
      await _retry(() async {
        await driveApi.files.delete(backupId);
      });

      return SyncResult.success('Backup deleted successfully.');
    } catch (e) {
      debugPrint('Cloud backup deletion failed: $e');
      if (e is SocketException || e is HttpException || e.toString().contains('connection')) {
        return SyncResult.failure(
          'Network connection lost. Please check your signal and try again.',
          SyncErrorType.noInternet,
        );
      }
      return SyncResult.failure(
        'Cloud backup deletion failed: ${e.toString()}',
        SyncErrorType.unknown,
      );
    }
  }
}
