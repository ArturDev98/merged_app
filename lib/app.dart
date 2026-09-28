import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
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
      // Solo español en la v0.1 (ver PLAN.md).
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const _AuthGate(),
    );
  }
}

/// Login o home según haya sesión; invalidar `sessionProvider` conmuta la
/// pantalla, al entrar y al cerrar sesión.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    // Una consulta con la sesión revocada devuelve al login: AuthService borra
    // los tokens, pero sin esto nadie recalcula la sesión.
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
