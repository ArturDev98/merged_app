import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';

/// Ramas creadas por el usuario en la ventana reciente.
///
/// No usa ningún endpoint propio: sale de los mismos eventos que alimentan los
/// contadores del resumen, filtrando los pushes que crean una rama.
class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(createdBranchesProvider);
    final dias = activityWindow.inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ramas creadas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Últimos $dias días',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      ),
      body: branches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(recentEventsProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.call_split,
                title: 'Sin ramas nuevas',
                message:
                    'No has creado ninguna rama en los últimos $dias días.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(recentEventsProvider),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(indent: 68),
              itemBuilder: (context, index) => _BranchTile(event: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _BranchTile extends ConsumerWidget {
  const _BranchTile({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final project = ref.watch(projectsByIdProvider)[event.projectId];
    final projectName = project?.name ?? 'Proyecto ${event.projectId}';
    final push = event.pushData!;

    // Los eventos no traen la URL de la rama; se compone con la del proyecto.
    // El nombre se codifica porque las ramas suelen llevar barras
    // (fix/login-biometrico) y romperían la ruta.
    final url = project?.webUrl != null
        ? '${project!.webUrl}/-/tree/${Uri.encodeComponent(push.ref)}'
        : null;

    return ListTile(
      leading: ToneIcon(
        icon: Icons.call_split,
        tone: MergedColors.of(context).amber,
      ),
      title: Text(push.ref, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [projectName, ?push.commitTitle].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            relativeTime(event.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (url != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.outline),
          ],
        ],
      ),
      onTap: () => openInGitlab(context, url),
    );
  }
}
