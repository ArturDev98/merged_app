import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/gitlab_client.dart';

/// Un error ya traducido a algo que se le puede enseñar a una persona.
class ErrorDescription {
  const ErrorDescription({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Traduce los fallos que la app puede producir de verdad.
  ///
  /// Sin esto, quedarse sin cobertura y que GitLab devuelva un 500 se veían
  /// exactamente igual: un volcado de `DioException`.
  factory ErrorDescription.from(Object error) {
    if (error is SessionExpiredException) {
      return const ErrorDescription(
        icon: Icons.lock_clock_outlined,
        title: 'Tu sesión expiró',
        message: 'Vuelve a iniciar sesión para seguir viendo tu GitLab.',
      );
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ErrorDescription(
            icon: Icons.wifi_off_rounded,
            title: 'Sin conexión',
            message:
                'No se pudo contactar con GitLab. Revisa tu internet e '
                'inténtalo de nuevo.',
          );
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status == 403) {
            return const ErrorDescription(
              icon: Icons.no_encryption_gmailerrorred_outlined,
              title: 'Sin permiso',
              message: 'Tu cuenta no tiene acceso a esta información.',
            );
          }
          if (status != null && status >= 500) {
            return const ErrorDescription(
              icon: Icons.cloud_off_outlined,
              title: 'GitLab no responde',
              message:
                  'El servidor tuvo un problema. Suele ser temporal: '
                  'inténtalo en un momento.',
            );
          }
        default:
          break;
      }
    }

    return const ErrorDescription(
      icon: Icons.error_outline,
      title: 'No se pudieron cargar los datos',
      message: 'Ocurrió un problema inesperado.',
    );
  }
}

/// Mensaje de error con reintento.
///
/// Muestra el detalle técnico plegado: sin él, un fallo de red y uno de
/// permisos se ven idénticos y no hay forma de diagnosticar desde el móvil.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final described = ErrorDescription.from(error);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(described.icon, size: 48, color: scheme.outline),
          const SizedBox(height: 14),
          Text(
            described.title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            described.message,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
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
                    '$error',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: scheme.outline,
                    ),
                    textAlign: TextAlign.center,
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

/// Estado vacío con nombre propio.
///
/// En esta app no es un caso borde: varias secciones estarán vacías a diario
/// según el rol del usuario, y un vacío mal resuelto se confunde con un fallo
/// de carga.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
