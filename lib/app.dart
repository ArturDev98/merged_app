import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme_mode_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/summary/summary_screen.dart';
import 'shared/state_views.dart';

class MergedApp extends ConsumerWidget {
  const MergedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Merged',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ref.watch(themeModeProvider),
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

    // Si cualquier pantalla topa con una sesión revocada, el gate devuelve al
    // login solo. Antes el usuario se quedaba mirando un error sin salida:
    // AuthService ya había borrado los tokens, pero nadie recalculaba la sesión.
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (next) ref.invalidate(sessionProvider);
    });

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
