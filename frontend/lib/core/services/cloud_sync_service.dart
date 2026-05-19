import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    final signedIn = await _googleSignIn.isSignedIn();
    if (signedIn) {
      _currentUser = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    }
    return signedIn;
  }

  Future<bool> backupToCloud() async {
    try {
      if (_currentUser == null) {
        final ok = await isSignedIn();
        if (!ok) return false;
      }

      final httpClient = (await _googleSignIn.authenticatedClient())!;
      final driveApi = drive.DriveApi(httpClient);

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      // 1. Zipping database and files
      final zipFile = File(p.join(tempDir.path, 'vault_backup.zip'));
      if (zipFile.existsSync()) zipFile.deleteSync();

      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);

      // Add SQLCipher Databases
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'sentrykey_vault.db'));
      if (dbFile.existsSync()) {
        encoder.addFile(dbFile);
      }
      
      // Duress Database if exists
      final duressDbFile = File(p.join(dbPath, 'sentrykey_vault_duress.db'));
      if (duressDbFile.existsSync()) {
        encoder.addFile(duressDbFile);
      }

      // Add Files folder (both normal and duress)
      final normalFilesDir = Directory(p.join(appDir.path, 'sentry_vault_files'));
      if (normalFilesDir.existsSync()) {
        encoder.addDirectory(normalFilesDir);
      }
      final duressFilesDir = Directory(p.join(appDir.path, 'sentry_vault_files_duress'));
      if (duressFilesDir.existsSync()) {
        encoder.addDirectory(duressFilesDir);
      }

      // Add Secure Storage metadata entries
      final metadataStr = await _secureStorage.read(key: 'vault_files_metadata') ?? '[]';
      final duressMetadataStr = await _secureStorage.read(key: 'vault_files_metadata_duress') ?? '[]';
      final metadataFile = File(p.join(tempDir.path, 'metadata.json'))..writeAsStringSync(metadataStr);
      final duressMetadataFile = File(p.join(tempDir.path, 'metadata_duress.json'))..writeAsStringSync(duressMetadataStr);
      
      encoder.addFile(metadataFile);
      encoder.addFile(duressMetadataFile);

      encoder.close();

      // 2. Encrypting the Zip archive
      final zipBytes = zipFile.readAsBytesSync();
      final base64Zip = base64Encode(zipBytes);
      final encryptedData = _encryptionService.encryptData(base64Zip);

      // Save encrypted file locally first
      final encFile = File(p.join(tempDir.path, 'sentrykey_backup.enc'))..writeAsStringSync(encryptedData);

      // Cleanup temp metadata files
      if (metadataFile.existsSync()) metadataFile.deleteSync();
      if (duressMetadataFile.existsSync()) duressMetadataFile.deleteSync();

      // 3. Upload to Google Drive AppData folder
      final media = drive.Media(encFile.openRead(), encFile.lengthSync());
      
      // Find if backup already exists
      final fileList = await driveApi.files.list(
        q: "name = 'sentrykey_backup.enc'",
        spaces: 'appDataFolder',
      );

      final driveFile = drive.File()
        ..name = 'sentrykey_backup.enc'
        ..parents = ['appDataFolder'];

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Overwrite existing backup
        final existingId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, existingId, uploadMedia: media);
        debugPrint('Backup successfully updated on Google Drive.');
      } else {
        // Create new backup
        await driveApi.files.create(driveFile, uploadMedia: media);
        debugPrint('New backup successfully created on Google Drive.');
      }

      // Clean up local temp encrypted file
      if (encFile.existsSync()) encFile.deleteSync();
      if (zipFile.existsSync()) zipFile.deleteSync();

      return true;
    } catch (e) {
      debugPrint('Cloud backup failed: $e');
      return false;
    }
  }

  Future<bool> restoreFromCloud() async {
    try {
      if (_currentUser == null) {
        final ok = await isSignedIn();
        if (!ok) return false;
      }

      final httpClient = (await _googleSignIn.authenticatedClient())!;
      final driveApi = drive.DriveApi(httpClient);

      // 1. Locate the backup file in Google Drive AppData
      final fileList = await driveApi.files.list(
        q: "name = 'sentrykey_backup.enc'",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('No backup found on Google Drive.');
        return false;
      }

      final backupId = fileList.files!.first.id!;

      // 2. Download the encrypted file
      final drive.Media media = await driveApi.files.get(
        backupId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final tempDir = await getTemporaryDirectory();
      final downloadFile = File(p.join(tempDir.path, 'downloaded_backup.enc'));
      
      final iosSink = downloadFile.openWrite();
      await media.stream.pipe(iosSink);
      await iosSink.close();

      // 3. Decrypt the backup
      final encryptedData = downloadFile.readAsStringSync();
      final decryptedBase64 = _encryptionService.decryptData(encryptedData);
      final zipBytes = base64Decode(decryptedBase64);

      final zipFile = File(p.join(tempDir.path, 'restored_backup.zip'))..writeAsBytesSync(zipBytes);

      // 4. Extract Zip File
      final bytes = zipFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = await getDatabasesPath();

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          
          if (filename == 'sentrykey_vault.db' || filename == 'sentrykey_vault_duress.db') {
            final f = File(p.join(dbPath, filename));
            await f.writeAsBytes(data, flush: true);
          } else if (filename == 'metadata.json') {
            final val = utf8.decode(data);
            await _secureStorage.write(key: 'vault_files_metadata', value: val);
          } else if (filename == 'metadata_duress.json') {
            final val = utf8.decode(data);
            await _secureStorage.write(key: 'vault_files_metadata_duress', value: val);
          } else if (filename.startsWith('sentry_vault_files/') || filename.startsWith('sentry_vault_files_duress/')) {
            final f = File(p.join(appDir.path, filename));
            if (!f.parent.existsSync()) {
              await f.parent.create(recursive: true);
            }
            await f.writeAsBytes(data, flush: true);
          }
        }
      }

      // Cleanup
      if (downloadFile.existsSync()) downloadFile.deleteSync();
      if (zipFile.existsSync()) zipFile.deleteSync();

      return true;
    } catch (e) {
      debugPrint('Cloud restore failed: $e');
      return false;
    }
  }
}
