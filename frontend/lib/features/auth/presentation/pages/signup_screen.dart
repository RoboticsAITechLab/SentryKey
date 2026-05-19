import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/glow_button.dart';
import '../widgets/sentry_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hasError = false;
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
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSetupVault(BuildContext context) {
    setState(() => _hasError = false);

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            SignUpRequested(masterPassword: _passwordController.text.trim()),
          );
    } else {
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            setState(() => _hasError = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFFF4D4D),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Stack(
            children: [
              // Ambient background glow
              Positioned(
                top: -120,
                left: -80,
                child: _AmbientBlob(color: AppColors.primary.withOpacity(0.08)),
              ),
              Positioned(
                bottom: -100,
                right: -60,
                child: _AmbientBlob(color: AppColors.accent.withOpacity(0.06)),
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
                                _SentryLogo(),
                                const SizedBox(height: 28),
                                Text(
                                  'Create Your Vault',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Set a master password to secure\nall your credentials.',
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

                          // Master Password Field
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
                                return 'Must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Field
                          SentryTextField(
                            controller: _confirmController,
                            hint: 'Confirm Password',
                            obscureText: true,
                            hasError: _hasError,
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          // Password strength hint
                          _PasswordStrengthHint(
                            password: _passwordController.text,
                          ),

                          const Spacer(flex: 3),

                          // CTA Button
                          GlowButton(
                            label: 'Setup Vault',
                            isLoading: isLoading,
                            onPressed:
                                isLoading ? null : () => _onSetupVault(context),
                          ),

                          const SizedBox(height: 32),
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

// ─── Supporting Widgets ──────────────────────────────────────────────────────

class _SentryLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final Color color;
  const _AmbientBlob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _PasswordStrengthHint extends StatelessWidget {
  final String password;
  const _PasswordStrengthHint({required this.password});

  (String, Color) get _strength {
    if (password.length >= 16) return ('Strong', AppColors.accent);
    if (password.length >= 8) return ('Good', AppColors.primary);
    if (password.isNotEmpty) return ('Weak', const Color(0xFFFF4D4D));
    return ('', Colors.transparent);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _strength;
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            'Strength: $label',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
