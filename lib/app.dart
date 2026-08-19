import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/summary/summary_screen.dart';
import 'shared/state_views.dart';

class MergedApp extends StatelessWidget {
  const MergedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merged',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

/// Decide entre login y home según haya sesión utilizable.
///
/// Invalidar `sessionProvider` es lo que hace conmutar la pantalla, tanto al
/// entrar como al cerrar sesión.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(sessionProvider),
          ),
        ),
      ),
      data: (loggedIn) =>
          loggedIn ? const SummaryScreen() : const LoginScreen(),
    );
  }
}
