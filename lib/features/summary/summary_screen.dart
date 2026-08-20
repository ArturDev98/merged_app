import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/providers.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../activity/push_detail_screen.dart';
import '../pending/pending_screen.dart';
import '../projects/projects_screen.dart';

/// Home: el informe personal, con la actividad como cuerpo.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merged'),
        actions: [
          const _PendingBell(),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              ref.invalidate(sessionProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activitySummaryProvider);
          ref.invalidate(pendingWorkProvider);
          ref.invalidate(myOpenMergeRequestsProvider);
          ref.invalidate(projectsProvider);
          await ref.read(activityFeedProvider.notifier).refresh();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 400) {
              ref.read(activityFeedProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _UserHeader()),
              const SliverToBoxAdapter(child: _Counters()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Actividad',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              ..._feedSlivers(context, ref, feed),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ActivityFeedState> feed,
  ) {
    if (feed.isLoading && !feed.hasValue) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (feed.hasError && !feed.hasValue) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorView(
              error: feed.error!,
              onRetry: () => ref.invalidate(activityFeedProvider),
            ),
          ),
        ),
      ];
    }

    final state = feed.valueOrNull;
    if (state == null) return const [];

    if (state.events.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyView(
              icon: Icons.history,
              title: 'Sin actividad reciente',
              message: 'Cuando hagas push a algún proyecto, aparecerá aquí.',
            ),
          ),
        ),
      ];
    }

    return [
      SliverList.separated(
        itemCount: state.events.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) =>
            _ActivityTile(event: state.events[index]),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: state.loadingMore
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : state.hasMore
                ? const SizedBox.shrink()
                : Text(
                    'No hay más actividad',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }
}

/// Campana con contador.
///
/// Responde a "¿me están esperando?". A diferencia de la convención habitual,
/// **el cero se muestra**: ocultar el badge dejaría al usuario sin saber si no
/// tiene nada pendiente o si simplemente aún no ha cargado.
class _PendingBell extends ConsumerWidget {
  const _PendingBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkProvider);
    final scheme = Theme.of(context).colorScheme;

    final Widget icon;
    if (pending.isLoading && !pending.hasValue) {
      icon = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (pending.hasError && !pending.hasValue) {
      icon = Icon(Icons.notifications_off_outlined, color: scheme.error);
    } else {
      final count = pending.valueOrNull?.length ?? 0;
      final quiet = count == 0;
      icon = Badge(
        label: Text('$count'),
        backgroundColor: quiet ? scheme.outlineVariant : scheme.error,
        textColor: quiet ? scheme.onSurfaceVariant : scheme.onError,
        child: Icon(
          quiet
              ? Icons.notifications_none_outlined
              : Icons.notifications_active,
          color: quiet ? scheme.outline : scheme.onSurface,
        ),
      );
    }

    return IconButton(
      tooltip: 'Pendientes',
      icon: icon,
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PendingScreen())),
    );
  }
}

class _UserHeader extends ConsumerWidget {
  const _UserHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user?.avatarUrl != null
                ? NetworkImage(user!.avatarUrl!)
                : null,
            child: user?.avatarUrl == null
                ? const Icon(Icons.person_outline)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Cargando…',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user != null)
                  Text(
                    '@${user.username}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
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

class _Counters extends ConsumerWidget {
  const _Counters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activitySummaryProvider);
    final myMrs = ref.watch(myOpenMergeRequestsProvider);
    final projects = ref.watch(projectsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatCard(
            label: 'Commits',
            hint: 'en tus pushes · 30 d',
            value: activity.valueOrNull?.commits,
            loading: activity.isLoading,
          ),
          _StatCard(
            label: 'Pushes',
            hint: '30 días',
            value: activity.valueOrNull?.pushes,
            loading: activity.isLoading,
          ),
          _StatCard(
            label: 'Ramas creadas',
            hint: '30 días',
            value: activity.valueOrNull?.branchesCreated,
            loading: activity.isLoading,
          ),
          _StatCard(
            label: 'MRs abiertos',
            hint: 'tuyos',
            value: myMrs.valueOrNull?.length,
            loading: myMrs.isLoading,
          ),
          _StatCard(
            label: 'Proyectos',
            value: projects.valueOrNull?.length,
            loading: projects.isLoading,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProjectsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.loading,
    this.hint,
    this.onTap,
  });

  final String label;
  final int? value;
  final bool loading;
  final String? hint;

  /// Las tarjetas con destino son la vía de entrada a cada sección.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 116,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              const SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value?.toString() ?? '—',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
            Text(label, style: theme.textTheme.bodySmall),
            if (hint != null)
              Text(
                hint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsByIdProvider);
    // Los eventos solo traen project_id: el nombre sale del índice local.
    final project = projects[event.projectId];
    // Se usa el nombre corto, no name_with_namespace: el grupo ocupaba la línea
    // entera y dejaba fuera la rama y el número de commits, que es lo que
    // aporta información. El nombre completo se ve en el detalle.
    final projectName = project?.name ?? 'Proyecto ${event.projectId}';
    final projectFullName =
        project?.nameWithNamespace ?? 'Proyecto ${event.projectId}';

    final push = event.pushData;
    final title = push?.commitTitle ?? event.targetTitle ?? event.actionName;

    final commitSuffix = (push != null && push.commitCount > 0)
        ? ' · ${push.commitCount} commits'
        : '';
    final subtitle = push != null
        ? '$projectName · ${push.ref}$commitSuffix'
        : projectName;

    return ListTile(
      leading: Icon(_iconFor(event), size: 22),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        relativeTime(event.createdAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      // Solo los pushes tienen detalle que enseñar.
      onTap: event.isPush
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PushDetailScreen(
                  event: event,
                  projectName: projectFullName,
                ),
              ),
            )
          : null,
    );
  }

  static IconData _iconFor(ActivityEvent event) {
    final push = event.pushData;
    if (push == null) return Icons.bolt_outlined;
    if (push.createsBranch) return Icons.call_split;
    if (push.action == PushAction.removed) return Icons.delete_outline;
    return Icons.arrow_upward;
  }
}
