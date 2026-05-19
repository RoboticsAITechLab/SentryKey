import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/glow_button.dart';
import '../widgets/sentry_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _hasError = false;
  bool _isBiometricAvailable = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Check hardware availability dynamically on start
    context.read<AuthBloc>().add(const CheckBiometricAvailability());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onUnlockVault(BuildContext context) {
    setState(() => _hasError = false);

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginRequested(masterPassword: _passwordController.text.trim()),
          );
      // Note: EnableBiometricRequested can be prompted later in VaultHomeScreen
    } else {
      setState(() => _hasError = true);
    }
  }

  void _onResetVault(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Vault?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Resetting your master password will permanently delete all your saved passwords. Are you sure you want to continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const ResetRequested());
            },
            child: const Text('Reset', style: TextStyle(color: Color(0xFFFF4D4D))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is BiometricStatusChecked) {
            setState(() => _isBiometricAvailable = state.isAvailable);
          } else if (state is BiometricAuthFailure) {
            setState(() => _hasError = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFFF4D4D),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is AuthError) {
            setState(() => _hasError = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFFF4D4D),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is BiometricAuthSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vault securely unlocked via Biometrics.'),
                backgroundColor: Colors.greenAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Stack(
            children: [
              // Ambient background glows
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.05),
                  ),
                ),
              ),

              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),

                          // Logo + Heading
                          Center(
                            child: Column(
                              children: [
                                // Glowing shield icon
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.surface,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.shield_rounded,
                                    size: 36,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Welcome Back',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your master password\nor use biometrics to unlock.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.45),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 2),

                          // Password Field
                          SentryTextField(
                            controller: _passwordController,
                            hint: 'Master Password',
                            obscureText: true,
                            hasError: _hasError,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password cannot be empty';
                              }
                              if (v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),

                          // Error state hint
                          if (_hasError) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFFF4D4D),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Authentication failed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFFF4D4D).withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Spacer(flex: 2),

                          // CTA Button
                          GlowButton(
                            label: 'Unlock Vault',
                            isLoading: isLoading,
                            onPressed: isLoading ? null : () => _onUnlockVault(context),
                          ),

                          // Biometric Auth Glassmorphic Button
                          if (_isBiometricAvailable) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: InkWell(
                                onTap: isLoading 
                                    ? null 
                                    : () => context.read<AuthBloc>().add(const LoginWithBiometricRequested()),
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.surface,
                                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.15),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 32,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const Spacer(flex: 2),

                          Center(
                            child: TextButton(
                              onPressed: isLoading ? null : () => _onResetVault(context),
                              child: Text(
                                'Forgot Password? / Reset Vault',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
