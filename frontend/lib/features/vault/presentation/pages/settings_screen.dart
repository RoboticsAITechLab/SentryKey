import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/biometric_storage_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/sentry_text_field.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../data/models/secret_entry.dart';
import '../bloc/vault_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;

  final _biometricService = sl<BiometricStorageService>();
  final _cloudSyncService = sl<CloudSyncService>();

  bool _isGoogleSignedIn = false;
  GoogleSignInAccount? _googleUser;
  bool _isSyncing = false;
  String _lastSyncTime = 'Never';

  // Honey-pot Decoy profiles list state
  Map<String, String> _decoyProfiles = {};
  bool _isShoulderSurfingEnabled = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    _animationController.forward();
    _checkBiometricStatus();
    _checkCloudSyncStatus();
    _loadDecoyProfiles();
    _loadShoulderSurfingStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadShoulderSurfingStatus() async {
    final storage = const FlutterSecureStorage();
    final status = await storage.read(key: 'is_shoulder_surfing_enabled') ?? 'false';
    if (mounted) {
      setState(() {
        _isShoulderSurfingEnabled = status == 'true';
      });
    }
  }

  Future<void> _toggleShoulderSurfing(bool value) async {
    final storage = const FlutterSecureStorage();
    await storage.write(key: 'is_shoulder_surfing_enabled', value: value.toString());
    if (mounted) {
      setState(() {
        _isShoulderSurfingEnabled = value;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Shoulder Surfing Protector Enabled!' : 'Shoulder Surfing Protector Disabled'),
        backgroundColor: value ? Colors.greenAccent : Colors.grey,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadDecoyProfiles() async {
    final result = await sl<AuthRepository>().getDecoyProfiles();
    result.fold(
      (failure) => null,
      (profiles) {
        if (mounted) {
          setState(() {
            _decoyProfiles = profiles;
          });
        }
      },
    );
  }

  Future<void> _checkCloudSyncStatus() async {
    final signedIn = await _cloudSyncService.isSignedIn();
    final storage = const FlutterSecureStorage();
    final lastSync = await storage.read(key: 'last_vault_sync_time') ?? 'Never';
    if (mounted) {
      setState(() {
        _isGoogleSignedIn = signedIn;
        _googleUser = _cloudSyncService.currentUser;
        _lastSyncTime = lastSync;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSyncing = true);
    final user = await _cloudSyncService.signIn();
    if (user != null) {
      await _checkCloudSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to Google Account: ${user.email}'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In Failed'),
            backgroundColor: Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _handleGoogleSignOut() async {
    setState(() => _isSyncing = true);
    await _cloudSyncService.signOut();
    await _checkCloudSyncStatus();
    setState(() => _isSyncing = false);
  }

  Future<void> _handleCloudBackup() async {
    setState(() => _isSyncing = true);
    final result = await _cloudSyncService.backupToCloud();
    if (result.success) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day}/${now.month}/${now.year}';
      final storage = const FlutterSecureStorage();
      await storage.write(key: 'last_vault_sync_time', value: timeStr);
      await _checkCloudSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _handleCloudRestore() async {
    setState(() => _isSyncing = true);
    final backups = await _cloudSyncService.getBackupHistory();
    setState(() => _isSyncing = false);

    if (backups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active backups found on Google Drive.'),
            backgroundColor: Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    String? selectedBackupId;
    if (mounted) {
      selectedBackupId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
          ),
          title: Text(
            'Select Backup Version',
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, idx) {
                final b = backups[idx];
                return ListTile(
                  title: Text(
                    b.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Updated: ${b.date.day}/${b.date.month}/${b.date.year}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                  trailing: const Icon(Icons.restore_rounded, color: AppColors.primary, size: 20),
                  onTap: () => Navigator.pop(ctx, b.id),
                );
              },
            ),
          ),
        ),
      );
    }

    if (selectedBackupId == null) return;

    setState(() => _isSyncing = true);
    final result = await _cloudSyncService.restoreFromCloud(backupId: selectedBackupId);
    setState(() => _isSyncing = false);

    if (mounted) {
      if (result.success) {
        context.read<VaultBloc>().add(const LoadVault());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleManageCloudBackups() async {
    setState(() => _isSyncing = true);
    final backups = await _cloudSyncService.getBackupHistory();
    setState(() => _isSyncing = false);

    if (backups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active backups found on Google Drive.'),
            backgroundColor: Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => _ManageBackupsDialog(backups: backups, cloudSyncService: _cloudSyncService),
      );
    }
  }

  Future<void> _checkBiometricStatus() async {
    try {
      final isSupported = await _biometricService.isBiometricAvailable();
      final isEnabled = await _biometricService.hasStoredMasterPassword();
      if (mounted) {
        setState(() {
          _isBiometricSupported = isSupported;
          _isBiometricEnabled = isEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onToggleBiometric(bool value) async {
    if (value) {
      final password = await _showPasswordPrompt(
        title: 'Confirm Master Password',
        desc: 'Please enter your master password to enable Biometric Authentication.',
      );
      if (password != null && password.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          await _biometricService.enableBiometricUnlock(password);
          await _checkBiometricStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometrics linked and enabled!'),
                backgroundColor: Colors.greenAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to enable biometrics: $e'),
                backgroundColor: const Color(0xFFFF4D4D),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() => _isLoading = true);
      try {
        await _biometricService.disableBiometricUnlock();
        await _checkBiometricStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication disabled.'),
              backgroundColor: Colors.grey,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to disable biometrics: $e'),
              backgroundColor: const Color(0xFFFF4D4D),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onSetupPanicMode() async {
    final password = await _showPasswordPrompt(
      title: 'Setup Default Decoy PIN',
      desc: 'Enter a secondary password. Using this at login will open an empty decoy vault.',
      buttonText: 'Save PIN',
    );
    if (password != null && password.isNotEmpty) {
      final result = await sl<AuthRepository>().setupPanicMode(password);
      if (mounted) {
        result.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: const Color(0xFFFF4D4D),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Default decoy PIN enabled!'),
                backgroundColor: Colors.greenAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      }
    }
  }

  // Multi Honey-pot profile setups
  Future<void> _onSetupDecoyProfile() async {
    final nameController = TextEditingController();
    final pinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        title: Text(
          'Add Honey-pot Decoy PIN',
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Decoy Name (e.g. Office, Family)',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Secret Decoy PIN',
                hintStyle: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Profile', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty && pinController.text.isNotEmpty) {
      final setupRes = await sl<AuthRepository>().setupDecoyProfile(pinController.text, nameController.text);
      setupRes.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: const Color(0xFFFF4D4D),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Decoy Profile "${nameController.text}" configured successfully!'),
              backgroundColor: Colors.greenAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadDecoyProfiles();
        },
      );
    }
  }

  Future<void> _onDeleteDecoy(String profileName) async {
    final res = await sl<AuthRepository>().deleteDecoyProfile(profileName);
    res.fold(
      (failure) => null,
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decoy "$profileName" deleted.'), behavior: SnackBarBehavior.floating),
        );
        _loadDecoyProfiles();
      },
    );
  }

  // --- FEATURE 2: OFFLINE PAPER CRYPTOGRAM Card Generator ---
  Future<void> _generatePaperCryptogram() async {
    setState(() => _isSyncing = true);
    final secretsRes = await sl<VaultRepository>().getSecrets();
    setState(() => _isSyncing = false);

    secretsRes.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load secrets: ${failure.message}'), backgroundColor: const Color(0xFFFF4D4D)),
      ),
      (secrets) async {
        if (secrets.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your vault is empty. Add secrets first!'), behavior: SnackBarBehavior.floating),
          );
          return;
        }

        final list = secrets.map((e) => {
          'id': e.id,
          'cat': e.category,
          'data': e.data,
          'fav': e.isFavorite ? 1 : 0,
          'ts': e.timestamp.toIso8601String(),
        }).toList();

        final compactJson = jsonEncode(list);
        final encrypted = sl<EncryptionService>().encryptData(compactJson);
        final cryptogramPayload = 'SENTRY-CRYPTOGRAM-V1:$encrypted';

        // Render visual Print preview Card Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Physical Cryptogram Card',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Beautiful Neon Card Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SENTRYKEY PAPER KEY',
                              style: GoogleFonts.spaceGrotesk(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                            const Icon(Icons.shield_outlined, color: Colors.white30, size: 16),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Dense Visual Fake QR Box representation
                        Center(
                          child: Container(
                            width: 130,
                            height: 130,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, size: 110, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'RESTORE INSTRUCTIONS:',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Keep this printed card safe in a physical safe. Import this cryptogram payload in your new device to restore offline.',
                          style: TextStyle(color: Colors.white70, fontSize: 9, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Secure Encrypted Payload:',
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        cryptogramPayload,
                        style: GoogleFonts.shareTechMono(color: Colors.white60, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cryptogramPayload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cryptogram copied to clipboard!'), behavior: SnackBarBehavior.floating),
                  );
                },
                child: const Text('Copy Payload', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restoreFromPaperCryptogram() async {
    final payloadController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        title: Text(
          'Restore Offline Cryptogram',
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste your printed SentryKey Cryptogram String below:',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: payloadController,
              maxLines: 6,
              style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'SENTRY-CRYPTOGRAM-V1:...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                fillColor: Colors.black12,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Data', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true && payloadController.text.isNotEmpty) {
      final input = payloadController.text.trim();
      if (!input.startsWith('SENTRY-CRYPTOGRAM-V1:')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid cryptogram tag format!'), backgroundColor: Color(0xFFFF4D4D), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      setState(() => _isSyncing = true);
      try {
        final encryptedPayload = input.replaceFirst('SENTRY-CRYPTOGRAM-V1:', '');
        final decryptedJson = sl<EncryptionService>().decryptData(encryptedPayload);
        final List<dynamic> decoded = jsonDecode(decryptedJson);

        int count = 0;
        for (final item in decoded) {
          final entry = SecretEntry(
            id: item['id'] as String,
            category: item['cat'] as String,
            data: Map<String, dynamic>.from(item['data'] as Map),
            isFavorite: (item['fav'] as int) == 1,
            timestamp: DateTime.parse(item['ts'] as String),
          );

          await sl<VaultRepository>().addSecret(entry);
          count++;
        }

        context.read<VaultBloc>().add(const LoadVault());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully merged $count secrets offline!'), backgroundColor: Colors.greenAccent, behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decrypt cryptogram: $e'), backgroundColor: const Color(0xFFFF4D4D), behavior: SnackBarBehavior.floating),
        );
      } finally {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<String?> _showPasswordPrompt({
    String title = 'Confirm Master Password',
    String desc = 'Please enter your master password.',
    String buttonText = 'Enable',
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary.withOpacity(0.15)),
          ),
          title: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SentryTextField(
                controller: controller,
                hint: 'Master Password',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cyber Ambient neon lights
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF4D4D).withOpacity(0.03),
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back Button and Title Area
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                                  onPressed: () => Navigator.pop(context),
                                  splashRadius: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Security Control',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // --- FEATURE 6: Autofill Setup ---
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF38BDF8).withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.password_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 26,
                                  ),
                                ),
                                title: const Text(
                                  'SentryKey Autofill',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Set as system password autofill',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8).withOpacity(0.1),
                                    foregroundColor: const Color(0xFF38BDF8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    const MethodChannel('com.example.sentrykey/autofill').invokeMethod('requestAutofillSetup');
                                  },
                                  child: const Text('Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Segment Header: Visual Security
                            Text(
                              'Device Controls',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Biometrics settings Card
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.fingerprint_rounded,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                                title: const Text(
                                  'Biometric Unlock',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  _isBiometricSupported ? 'Use Fingerprint or FaceID' : 'Not supported on this device',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                ),
                                trailing: Switch(
                                  value: _isBiometricEnabled,
                                  onChanged: _isBiometricSupported ? _onToggleBiometric : null,
                                  activeColor: AppColors.primary,
                                  activeTrackColor: AppColors.primary.withOpacity(0.25),
                                  inactiveThumbColor: Colors.white38,
                                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // --- FEATURE 3: Anti-Shoulder Surfing Protector toggle ---
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF00E676).withOpacity(0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF00E676).withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.visibility_off_rounded,
                                    color: Color(0xFF00E676),
                                    size: 26,
                                  ),
                                ),
                                title: const Text(
                                  'Metro Privacy Shield',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Blurs secrets and unmasks only when press-and-holding.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                ),
                                trailing: Switch(
                                  value: _isShoulderSurfingEnabled,
                                  onChanged: _toggleShoulderSurfing,
                                  activeColor: const Color(0xFF00E676),
                                  activeTrackColor: const Color(0xFF00E676).withOpacity(0.25),
                                  inactiveThumbColor: Colors.white38,
                                  inactiveTrackColor: Colors.white.withOpacity(0.08),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- FEATURE 1: HONEY-POT DECOY VAULTS MANAGER ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Honey-Pot Decoys',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF4D4D),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFF4D4D)),
                                  onPressed: _onSetupDecoyProfile,
                                  tooltip: 'Add Decoy Profile',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Primary Duress setup card
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF4D4D).withOpacity(0.2),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                onTap: _onSetupPanicMode,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF4D4D).withOpacity(0.1),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4D4D), size: 20),
                                ),
                                title: const Text('Default Decoy PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: const Text('Standard empty profiles launcher.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                                trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white24),
                              ),
                            ),

                            // Decoy profiles listing
                            if (_decoyProfiles.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No custom Honey-pot PINs configured.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _decoyProfiles.length,
                                itemBuilder: (context, index) {
                                  final key = _decoyProfiles.keys.elementAt(index);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: ListTile(
                                      title: Text(key.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Decoy Profile Active', style: TextStyle(color: Colors.white24, fontSize: 10)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white30, size: 18),
                                        onPressed: () => _onDeleteDecoy(key),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 32),

                            // --- DEAD MAN'S SWITCH ---
                            Text(
                              'Emergency Protocol',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF4D4D),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFFF4D4D).withOpacity(0.15),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                onTap: _showDeadMansSwitchDialog,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFF4D4D).withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.timer_off_rounded,
                                    color: Color(0xFFFF4D4D),
                                    size: 26,
                                  ),
                                ),
                                title: const Text(
                                  'Dead Man\'s Switch',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Wipe vault if inactive for months',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                ),
                                trailing: const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white38),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // --- FEATURE 2: OFFLINE PRINTABLE CRYPTOGRAM ---
                            Text(
                              'Offline Paper Backup',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00E5FF),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF00E5FF).withOpacity(0.18),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    onTap: _generatePaperCryptogram,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                                      ),
                                      child: const Icon(Icons.print_rounded, color: Color(0xFF00E5FF), size: 22),
                                    ),
                                    title: const Text('Generate Paper Cryptogram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: const Text('Export secure printed credentials.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(color: Colors.white.withOpacity(0.06), height: 1),
                                  const SizedBox(height: 8),
                                  ListTile(
                                    onTap: _restoreFromPaperCryptogram,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary.withOpacity(0.1),
                                      ),
                                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                                    ),
                                    title: const Text('Restore from Cryptogram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: const Text('Scan paper backup to restore data offline.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Cloud Sync Segment Header
                            Text(
                              'Cloud Backup',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Google Drive Sync Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.18),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isGoogleSignedIn ? 'Google Drive Linked' : 'Google Drive Off',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _isGoogleSignedIn ? _googleUser?.email ?? '' : 'Back up your encrypted secrets securely',
                                              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      _isSyncing
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                                            )
                                          : ElevatedButton(
                                              onPressed: _isGoogleSignedIn ? _handleGoogleSignOut : _handleGoogleSignIn,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _isGoogleSignedIn ? Colors.white.withOpacity(0.07) : AppColors.primary,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                              ),
                                              child: Text(
                                                _isGoogleSignedIn ? 'Disconnect' : 'Connect',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isGoogleSignedIn ? Colors.white70 : Colors.white),
                                              ),
                                            ),
                                    ],
                                  ),
                                  if (_isGoogleSignedIn) ...[
                                    const SizedBox(height: 20),
                                    Divider(color: Colors.white.withOpacity(0.06), height: 1),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Last Synced', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                _lastSyncTime,
                                                style: TextStyle(color: AppColors.primary.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Row(
                                          children: [
                                            _isSyncing
                                                ? const GlowingSyncSpinner(icon: Icons.cloud_upload_rounded, color: Colors.greenAccent)
                                                : IconButton(
                                                    icon: const Icon(Icons.cloud_upload_rounded, color: Colors.greenAccent),
                                                    onPressed: _handleCloudBackup,
                                                    tooltip: 'Sync Backup Now',
                                                  ),
                                            const SizedBox(width: 8),
                                            _isSyncing
                                                ? const GlowingSyncSpinner(icon: Icons.cloud_download_rounded, color: AppColors.primary)
                                                : IconButton(
                                                    icon: const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
                                                    onPressed: _handleCloudRestore,
                                                    tooltip: 'Restore Vault',
                                                  ),
                                            const SizedBox(width: 8),
                                            _isSyncing
                                                ? const GlowingSyncSpinner(icon: Icons.storage_rounded, color: Colors.orangeAccent)
                                                : IconButton(
                                                    icon: const Icon(Icons.storage_rounded, color: Colors.orangeAccent),
                                                    onPressed: _handleManageCloudBackups,
                                                    tooltip: 'Manage Cloud Data',
                                                  ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDeadMansSwitchDialog() async {
    const storage = FlutterSecureStorage();
    String? currentDays = await storage.read(key: 'dead_man_switch_days');
    int initialValue = currentDays != null ? (int.parse(currentDays) ~/ 30) : 0;
    if (initialValue == 0) initialValue = 3; // default to 3 months
    
    bool isEnabled = currentDays != null;
    int selectedMonths = initialValue;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.timer_off_rounded, color: Color(0xFFFF4D4D), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Dead Man\'s Switch',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'If you do not open SentryKey for a specified number of months, your vault will be permanently wiped to protect your secrets.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enable Switch', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Switch(
                      value: isEnabled,
                      onChanged: (v) {
                        setModalState(() => isEnabled = v);
                      },
                      activeColor: const Color(0xFFFF4D4D),
                    ),
                  ],
                ),
                
                if (isEnabled) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Inactivity Period', style: TextStyle(color: Colors.white, fontSize: 14)),
                      Text('$selectedMonths Months', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFFF4D4D), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: selectedMonths.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    activeColor: const Color(0xFFFF4D4D),
                    onChanged: (val) {
                      setModalState(() => selectedMonths = val.toInt());
                    },
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEnabled ? const Color(0xFFFF4D4D) : Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (isEnabled) {
                        await storage.write(key: 'dead_man_switch_days', value: (selectedMonths * 30).toString());
                        final currentLogin = await storage.read(key: 'last_login_date');
                        if (currentLogin == null) {
                          await storage.write(key: 'last_login_date', value: DateTime.now().toIso8601String());
                        }
                      } else {
                        await storage.delete(key: 'dead_man_switch_days');
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEnabled ? 'Dead Man\'s Switch Activated' : 'Dead Man\'s Switch Disabled'), backgroundColor: isEnabled ? const Color(0xFFFF4D4D) : Colors.grey),
                      );
                    },
                    child: Text('Save Configuration', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GlowingSyncSpinner extends StatefulWidget {
  final IconData icon;
  final Color color;
  const GlowingSyncSpinner({super.key, required this.icon, required this.color});

  @override
  State<GlowingSyncSpinner> createState() => _GlowingSyncSpinnerState();
}

class _GlowingSyncSpinnerState extends State<GlowingSyncSpinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: widget.color, size: 22),
      ),
    );
  }
}

class _ManageBackupsDialog extends StatefulWidget {
  final List<DriveBackupInfo> backups;
  final CloudSyncService cloudSyncService;

  const _ManageBackupsDialog({required this.backups, required this.cloudSyncService});

  @override
  State<_ManageBackupsDialog> createState() => _ManageBackupsDialogState();
}

class _ManageBackupsDialogState extends State<_ManageBackupsDialog> {
  late List<DriveBackupInfo> _backups;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _backups = List.from(widget.backups);
  }

  Future<void> _deleteBackup(DriveBackupInfo backup) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
        ),
        title: Text('Delete Backup', style: GoogleFonts.spaceGrotesk(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this backup from Google Drive?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final result = await widget.cloudSyncService.deleteBackupFromCloud(backup.id);
    
    if (mounted) {
      if (result.success) {
        setState(() {
          _backups.removeWhere((b) => b.id == backup.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.greenAccent, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          const Icon(Icons.storage_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 8),
          Text(
            'Manage Cloud Data',
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : _backups.isEmpty
            ? const Center(child: Text('No backups left.', style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _backups.length,
                itemBuilder: (context, idx) {
                  final b = _backups[idx];
                  final sizeMb = (b.sizeBytes / (1024 * 1024)).toStringAsFixed(2);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        b.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Size: ${sizeMb}MB • ${b.date.day}/${b.date.month}/${b.date.year}',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                        ),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.1),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteBackup(b),
                          tooltip: 'Delete Backup',
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
