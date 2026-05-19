import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/biometric_storage_service.dart';
import '../../../../core/services/cloud_sync_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/sentry_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;

  final _biometricService = sl<BiometricStorageService>();
  final _cloudSyncService = sl<CloudSyncService>();

  bool _isGoogleSignedIn = false;
  GoogleSignInAccount? _googleUser;
  bool _isSyncing = false;
  String _lastSyncTime = 'Never';

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
    _checkCloudSyncStatus();
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
          SnackBar(content: Text('Connected: ${user.email}'), backgroundColor: Colors.greenAccent),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication Failed'), backgroundColor: Color(0xFFFF4D4D)),
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
    final success = await _cloudSyncService.backupToCloud();
    if (success) {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day}/${now.month}/${now.year}';
      final storage = const FlutterSecureStorage();
      await storage.write(key: 'last_vault_sync_time', value: timeStr);
      await _checkCloudSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault backup successfully uploaded!'), backgroundColor: Colors.greenAccent),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup failed. Check connection.'), backgroundColor: Color(0xFFFF4D4D)),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  Future<void> _handleCloudRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restore Vault?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will overwrite your local database and sandboxed files with your latest Google Drive backup. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: Color(0xFFFF4D4D))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSyncing = true);
      final success = await _cloudSyncService.restoreFromCloud();
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault successfully restored! Reloading app...'), backgroundColor: Colors.greenAccent),
          );
        }
        context.read<AuthBloc>().add(AppStarted());
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore failed. No active backup found.'), backgroundColor: Color(0xFFFF4D4D)),
          );
        }
      }
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _checkBiometricStatus() async {
    setState(() => _isLoading = true);
    final supported = await _biometricService.isBiometricAvailable();
    
    bool enabled = false;
    if (supported) {
      try {
        enabled = await _biometricService.hasStoredMasterPassword();
      } catch (e) {
        enabled = false;
      }
    }

    if (mounted) {
      setState(() {
        _isBiometricSupported = supported;
        _isBiometricEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  void _onToggleBiometric(bool value) async {
    if (value) {
      final password = await _showPasswordPrompt();
      if (password != null && password.isNotEmpty) {
        if (mounted) {
          context.read<AuthBloc>().add(EnableBiometricRequested(masterPassword: password));
          setState(() => _isLoading = true);
          await Future.delayed(const Duration(milliseconds: 1500));
          await _checkBiometricStatus();
        }
      }
    } else {
      // Disable biometrics
      await _biometricService.disableBiometricUnlock();
      await _checkBiometricStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric Authentication Disabled'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _onSetupPanicMode() async {
    final password = await _showPasswordPrompt(
      title: 'Setup Panic PIN',
      desc: 'Enter a secondary password. Using this at login will open a fake, empty vault.',
      buttonText: 'Save PIN',
    );
    if (password != null && password.isNotEmpty) {
      final result = await sl<AuthRepository>().setupPanicMode(password);
      if (mounted) {
        result.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: const Color(0xFFFF4D4D))),
          (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Panic Mode enabled successfully!'), backgroundColor: Colors.greenAccent)),
        );
      }
    }
  }

  Future<String?> _showPasswordPrompt({
    String title = 'Confirm Master Password',
    String desc = 'Please enter your master password to enable Biometric Authentication.',
    String buttonText = 'Enable',
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
          ),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                desc,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SentryTextField(
                controller: controller,
                hint: 'Password / PIN',
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(buttonText, style: const TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is BiometricSetupSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric Authentication Enabled!'),
                backgroundColor: Colors.greenAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _checkBiometricStatus();
          } else if (state is BiometricAuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFFF4D4D),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _checkBiometricStatus();
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFFF4D4D),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _checkBiometricStatus();
          }
        },
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: const Text(
                          'Biometric Unlock',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _isBiometricSupported
                              ? 'Use Fingerprint or FaceID'
                              : 'Not supported on this device',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Switch(
                          value: _isBiometricEnabled,
                          onChanged: _isBiometricSupported ? _onToggleBiometric : null,
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withOpacity(0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF4D4D).withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF4D4D).withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: _onSetupPanicMode,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF4D4D).withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFFF4D4D),
                          ),
                        ),
                        title: const Text(
                          'Setup Panic PIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Creates a fake empty vault on duress login.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Cloud Backup',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
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
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
                                        backgroundColor: _isGoogleSignedIn ? Colors.white10 : AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        _isGoogleSignedIn ? 'Disconnect' : 'Connect',
                                        style: TextStyle(color: _isGoogleSignedIn ? Colors.white70 : Colors.white, fontSize: 13),
                                      ),
                                    ),
                            ],
                          ),
                          if (_isGoogleSignedIn) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Last Synced', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(_lastSyncTime, style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.cloud_upload_rounded, color: Colors.greenAccent),
                                      onPressed: _handleCloudBackup,
                                      tooltip: 'Sync Backup Now',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
                                      onPressed: _handleCloudRestore,
                                      tooltip: 'Restore Vault',
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
    );
  }
}
