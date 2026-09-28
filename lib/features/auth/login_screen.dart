import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_failure.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/tone_icon.dart';

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
    final colors = MergedColors.of(context);
    final failure = _failure;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: colors.header,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MergedMark(size: 128, color: colors.onHeader),
                    const SizedBox(height: 8),
                    Text(
                      'Merged',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colors.onHeader,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu GitLab, resumido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onHeaderMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (_loading)
                      CircularProgressIndicator(color: colors.onHeader)
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.onHeader,
                          foregroundColor: colors.header,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _login,
                        icon: const Icon(Icons.login),
                        label: Text(
                          failure != null && failure.canRetry
                              ? 'Intentar de nuevo'
                              : 'Iniciar sesión con GitLab',
                        ),
                      ),
                    if (failure != null && !_loading) ...[
                      const SizedBox(height: 24),
                      _FailureCard(failure: failure),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'Solo lectura · se conecta directamente con gitlab.com',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onHeaderMuted,
                      ),
                    ),
                  ],
                ),
              ),
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
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
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
