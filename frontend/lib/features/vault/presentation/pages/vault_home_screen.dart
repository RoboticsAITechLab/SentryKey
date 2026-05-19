import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../../../injection_container.dart';
import '../pages/add_secret_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'settings_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/vault_repository.dart';
import '../bloc/vault_bloc.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient top-right glow
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
                      // Logo
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
                          Text(
                            'Your vault is unlocked',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.accent.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      
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
                          );
                        },
                      ),
                      const SizedBox(width: 4),

                      // Lock / status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.accent.withOpacity(0.1),
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Secure',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Section heading / Tabs ──────────────────────────────────────
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

                // ── Password/Files list ────────────────────────────────────────
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
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: secrets.length,
                            itemBuilder: (context, i) => SecretCard(
                              entry: secrets[i],
                            ),
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
                // Reload vault after adding secret
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
