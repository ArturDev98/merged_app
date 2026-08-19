import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
          const SizedBox(height: 12),
          Text(
            'No se pudieron cargar los datos',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(
              'Ver detalle',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
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
