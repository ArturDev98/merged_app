import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/pending_work.dart';
import '../../core/providers.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../merge_requests/merge_requests_screen.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';

/// La lista que hay detrás de la campana.
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendientes'),
        actions: [
          IconButton(
            tooltip: 'Ver merge requests a revisar',
            icon: const Icon(Icons.merge_type),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const MergeRequestsScreen(initialScope: MrScope.reviewing),
              ),
            ),
          ),
        ],
      ),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(pendingWorkProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.check_circle_outline,
                title: 'Nada pendiente',
                message: 'Nadie está esperando por ti ahora mismo.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pendingWorkProvider.future),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _PendingTile(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.item});

  final PendingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_iconFor(item.kind), color: _colorFor(item.kind, theme)),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.reason} · ${relativeTime(item.at)}'),
      // Solo lectura: la acción real ocurre en GitLab.
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => openInGitlab(context, item.webUrl),
    );
  }

  static IconData _iconFor(PendingKind kind) => switch (kind) {
    PendingKind.todo => Icons.notifications_active_outlined,
    PendingKind.reviewRequest => Icons.rate_review_outlined,
    PendingKind.assigned => Icons.assignment_ind_outlined,
  };

  static Color _colorFor(PendingKind kind, ThemeData theme) => switch (kind) {
    PendingKind.todo => theme.colorScheme.error,
    PendingKind.reviewRequest => theme.colorScheme.primary,
    PendingKind.assigned => theme.colorScheme.tertiary,
  };
}
