import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../../injection_container.dart';
import '../pages/add_secret_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'settings_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/vault_repository.dart';
import '../bloc/vault_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/add_password_sheet.dart';
import '../widgets/secret_card.dart';
import '../widgets/vault_files_view.dart';
import '../widgets/add_file_sheet.dart';
import '../widgets/virtual_credit_card.dart';
import 'vault_health_screen.dart';

class VaultHomeScreen extends StatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  State<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends State<VaultHomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<VaultFilesViewState> _filesKey = GlobalKey<VaultFilesViewState>();

  static const _autofillChannel = MethodChannel('com.example.sentrykey/autofill');

  // Anti-Shoulder Surfing states
  bool _isShoulderSurfingActive = false;
  bool _isCurrentlyPeeking = false;
  final _secureStorage = const FlutterSecureStorage();

  // Flip-to-lock state
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  bool _isLocked = false;

  void _syncAutofillCache(List<dynamic> passwords) async {
    try {
      final logins = passwords.where((e) => e.category == 'Password').map((e) {
        final data = e.data;
        return {
          'website': data['website'] ?? data['url'] ?? '',
          'username': data['username'] ?? data['email'] ?? '',
          'password': data['password'] ?? '',
        };
      }).toList();

      final jsonStr = jsonEncode(logins);
      await _autofillChannel.invokeMethod('updateAutofillCache', {'cacheJson': jsonStr});
    } catch (e) {
      debugPrint('Autofill cache sync failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<VaultBloc>().add(const LoadVault());
    _loadShoulderSurfingPreference();
    _initFlipToLock();
  }

  void _initFlipToLock() {
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // If z is highly negative (e.g., < -8.5), the phone is placed face down.
      if (event.z < -8.5 && !_isLocked) {
        _lockApp();
      }
    });
  }

  void _lockApp() {
    if (_isLocked) return;
    _isLocked = true;
    _accelSubscription?.cancel();
    if (mounted) {
      context.read<AuthBloc>().add(const AppStarted());
    }
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadShoulderSurfingPreference() async {
    final status = await _secureStorage.read(key: 'is_shoulder_surfing_enabled') ?? 'false';
    if (mounted) {
      setState(() {
        _isShoulderSurfingActive = status == 'true';
      });
    }
  }

  Future<void> _toggleShoulderSurfing() async {
    final newStatus = !_isShoulderSurfingActive;
    await _secureStorage.write(key: 'is_shoulder_surfing_enabled', value: newStatus.toString());
    if (mounted) {
      setState(() {
        _isShoulderSurfingActive = newStatus;
        _isCurrentlyPeeking = false; // reset peeking
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newStatus ? 'Metro Privacy Shield Enabled!' : 'Metro Privacy Shield Disabled'),
        backgroundColor: newStatus ? const Color(0xFF00E676) : Colors.grey,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Cyber Ambient top-right neon light
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AppBar area ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      // SentryKey Shield Logo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SentryKey',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Secure • Unlocked',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Quick Toggle for Metro Privacy Shield (Eye Icon)
                      IconButton(
                        icon: Icon(
                          _isShoulderSurfingActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: _isShoulderSurfingActive ? const Color(0xFF00E676) : Colors.white.withOpacity(0.7),
                        ),
                        onPressed: _toggleShoulderSurfing,
                        tooltip: 'Metro Privacy Shield',
                      ),
                      
                      // Health Dashboard Button
                      BlocBuilder<VaultBloc, VaultState>(
                        builder: (context, state) {
                          return IconButton(
                            icon: Icon(Icons.health_and_safety_outlined, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {
                              if (state is VaultLoaded) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => VaultHealthScreen(entries: state.passwords)),
                                );
                              }
                            },
                          );
                        }
                      ),
                      
                      // Settings Button
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: Colors.white.withOpacity(0.7)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ).then((_) {
                            // Reload preference and database when returning from settings
                            _loadShoulderSurfingPreference();
                            context.read<VaultBloc>().add(const LoadVault());
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section tabs ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 0),
                        child: Text(
                          'Secrets',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _selectedIndex == 0 ? Colors.white : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 1),
                        child: Text(
                          'Cards',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _selectedIndex == 1 ? Colors.white : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 2),
                        child: Text(
                          'Files',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _selectedIndex == 2 ? Colors.white : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Dynamic Content Container ─────────────────────────────────
                Expanded(
                  child: _selectedIndex == 2 ? VaultFilesView(key: _filesKey) : BlocConsumer<VaultBloc, VaultState>(
                    listener: (context, state) {
                      if (state is VaultError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.message),
                            backgroundColor: const Color(0xFFFF4D4D),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (state is VaultLoaded) {
                        _syncAutofillCache(state.passwords);
                      }
                    },
                    builder: (context, state) {
                      if (state is VaultLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        );
                      }

                      if (state is VaultLoaded) {
                        if (_selectedIndex == 0) {
                          final secrets = state.passwords.where((e) => e.category != 'Card').toList();
                          if (secrets.isEmpty) return const _EmptyVaultView(isCard: false);
                          
                          final listWidget = ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: secrets.length,
                            itemBuilder: (context, i) => SecretCard(
                              entry: secrets[i],
                            ),
                          );

                          // Overlay Metro Privacy Blur Shield if enabled
                          if (!_isShoulderSurfingActive) {
                            return listWidget;
                          }

                          return Stack(
                            children: [
                              listWidget,
                              if (!_isCurrentlyPeeking)
                                Positioned.fill(
                                  child: ClipRRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.55),
                                        child: Center(
                                          child: GestureDetector(
                                            onTapDown: (_) {
                                              setState(() {
                                                _isCurrentlyPeeking = true;
                                              });
                                            },
                                            onTapUp: (_) {
                                              setState(() {
                                                _isCurrentlyPeeking = false;
                                              });
                                            },
                                            onTapCancel: () {
                                              setState(() {
                                                _isCurrentlyPeeking = false;
                                              });
                                            },
                                            child: Container(
                                              width: 170,
                                              height: 170,
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.35), width: 1.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF00E676).withOpacity(0.15),
                                                    blurRadius: 28,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.fingerprint_rounded,
                                                    color: Color(0xFF00E676),
                                                    size: 56,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    'HOLD TO PEEK',
                                                    style: GoogleFonts.spaceGrotesk(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'ANTI-SNOOP ON',
                                                    style: TextStyle(
                                                      color: Colors.white30,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        } else if (_selectedIndex == 1) {
                          final cards = state.passwords.where((e) => e.category == 'Card').toList();
                          if (cards.isEmpty) return const _EmptyVaultView(isCard: true);
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: cards.length,
                            itemBuilder: (context, i) => VirtualCreditCard(
                              entry: cards[i],
                            ),
                          );
                        }
                      }

                      return const _EmptyVaultView(isCard: false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Floating Action Button ──────────────────────────────────────────
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF0077B6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.45),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            if (_selectedIndex == 0 || _selectedIndex == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSecretScreen(vaultRepository: sl<VaultRepository>()),
                ),
              ).then((_) {
                context.read<VaultBloc>().add(const LoadVault());
              });
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddFileSheet(
                  onFileSaved: (file) {
                    _filesKey.currentState?.addFileAndSave(file);
                  },
                ),
              );
            }
          },
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptyVaultView extends StatelessWidget {
  final bool isCard;

  const _EmptyVaultView({this.isCard = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              isCard ? Icons.credit_card_rounded : Icons.lock_outline_rounded,
              size: 40,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCard ? 'No cards added' : 'Your vault is empty',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCard ? 'Tap + to add a virtual card.' : 'Tap + to add your first secret.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
