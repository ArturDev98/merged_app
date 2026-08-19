import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/providers.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';

/// Detalle de un push, con sus commits reales.
///
/// Los eventos solo traen el título del último commit; la lista completa se
/// pide aquí con `compare`, una sola llamada y solo al abrir.
class PushDetailScreen extends ConsumerWidget {
  const PushDetailScreen({
    super.key,
    required this.event,
    required this.projectName,
  });

  final ActivityEvent event;
  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = event.pushData;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(projectName)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  push?.ref ?? '(sin rama)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.actionName} · ${relativeTime(event.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (push == null || !push.canExpandCommits)
            EmptyView(
              icon: Icons.commit_outlined,
              title: 'Sin detalle de commits',
              message: push?.isDegraded ?? true
                  // GitLab recorta los pushes que superan su límite de
                  // actividad; no es un fallo nuestro y conviene decirlo.
                  ? 'GitLab entregó este push sin el detalle de sus commits.'
                  : 'Este evento no incluye un rango de commits.',
            )
          else
            _CommitList(
              push: (
                projectId: event.projectId,
                from: push.commitFrom!,
                to: push.commitTo!,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommitList extends ConsumerWidget {
  const _CommitList({required this.push});

  final PushRef push;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commits = ref.watch(pushCommitsProvider(push));

    return commits.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(pushCommitsProvider(push)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            icon: Icons.commit_outlined,
            title: 'Sin commits nuevos',
            message: 'La comparación no devolvió commits.',
          );
        }
        return Column(
          children: [
            for (final commit in list)
              ListTile(
                leading: const Icon(Icons.commit, size: 20),
                title: Text(
                  commit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${commit.shortId} · ${commit.authorName} · '
                  '${relativeTime(commit.createdAt)}',
                ),
                onTap: commit.webUrl == null
                    ? null
                    : () => openInGitlab(context, commit.webUrl),
              ),
          ],
        );
      },
    );
  }
}
