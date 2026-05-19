import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../pages/login_screen.dart';
import '../pages/signup_screen.dart';
import '../../../vault/presentation/pages/vault_home_screen.dart';

/// Root widget that decides which screen to show based on [AuthState].
/// Add this as the home of MaterialApp after providing [AuthBloc].
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Trigger the registration check on startup.
    context.read<AuthBloc>().add(const AppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildForState(state),
        );
      },
    );
  }

  Widget _buildForState(AuthState state) {
    return switch (state) {
      AuthInitial() || AuthLoading() => _LoadingScreen(key: const ValueKey('loading')),
      NewUser()                      => const SignUpScreen(key: ValueKey('signup')),
      ExistingUser()                 => const LoginScreen(key: ValueKey('login')),
      Authenticated()                => const VaultHomeScreen(key: ValueKey('vault')),
      AuthError()                    => const LoginScreen(key: ValueKey('login-error')),
      _                              => _LoadingScreen(key: const ValueKey('fallback')),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
