import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_wrapper.dart';
import 'features/vault/presentation/bloc/vault_bloc.dart';
import 'injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.initDependencies();
  runApp(const SentryKeyApp());
}

class SentryKeyApp extends StatelessWidget {
  const SentryKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>(),
        ),
        BlocProvider<VaultBloc>(
          create: (_) => di.sl<VaultBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'SentryKey',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthWrapper(),
      ),
    );
  }
}
