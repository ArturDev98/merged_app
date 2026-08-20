import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_failure.dart';
import '../../core/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  AuthFailure? _failure;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final auth = ref.read(authServiceProvider);
    final ok = await auth.login();
    if (!mounted) return;

    if (ok) {
      // Recalcular la sesión es lo que hace que el gate cambie a la home.
      ref.invalidate(sessionProvider);
    } else {
      setState(() {
        _loading = false;
        _failure = auth.lastFailure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = _failure;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.merge_rounded,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Merged', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Tu GitLab, resumido',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 40),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: Text(
                      failure != null && failure.canRetry
                          ? 'Intentar de nuevo'
                          : 'Iniciar sesión con GitLab',
                    ),
                  ),
                if (failure != null && !_loading) ...[
                  const SizedBox(height: 28),
                  _FailureCard(failure: failure),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presenta un fallo de login sin volcar la excepción encima del usuario.
///
/// Cancelar se muestra en tono neutro y no en rojo: cerrar el navegador es una
/// decisión del usuario, no un error de la app.
class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure});

  final AuthFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final accent = switch (failure.kind) {
      AuthFailureKind.cancelled => scheme.outline,
      AuthFailureKind.network => scheme.tertiary,
      _ => scheme.error,
    };
    final icon = switch (failure.kind) {
      AuthFailureKind.cancelled => Icons.info_outline,
      AuthFailureKind.network => Icons.wifi_off_rounded,
      AuthFailureKind.rejected => Icons.gpp_maybe_outlined,
      AuthFailureKind.unknown => Icons.error_outline,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 32),
          const SizedBox(height: 10),
          Text(
            failure.title,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            failure.message,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            textAlign: TextAlign.center,
          ),
          if (failure.detail != null)
            // El texto técnico sigue disponible, pero plegado: sin él no hay
            // forma de diagnosticar desde un teléfono.
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Detalle técnico',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SelectableText(
                      failure.detail!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: scheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
