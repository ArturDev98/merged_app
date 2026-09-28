import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/activity_labels.dart';
import '../../shared/diff_view.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';
import 'commit_detail_screen.dart';

/// Detalle de un push: sus commits y archivos, pedidos con `compare` al
/// abrir (los eventos solo traen el título del último commit).
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

    // Al crear una rama GitLab no manda commit_from: se compara con la rama
    // por defecto, que da justo los commits que la rama introduce.
    final project = ref.watch(projectsByIdProvider)[event.projectId];
    final defaultBranch = project?.defaultBranch;
    final base = push?.commitFrom ?? defaultBranch;
    final canExpand = push != null && push.hasTarget && base != null;

    return Scaffold(
      appBar: AppBar(title: Text(projectName)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ToneIcon(
                      icon: activityIcon(event),
                      tone: activityTone(event, MergedColors.of(context)),
                      size: 44,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            push?.ref ?? '(sin rama)',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            '${describeActivity(event)} · '
                            '${relativeTime(event.createdAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canExpand && (push.needsBaseFallback))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Rama nueva · comparada con $base',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!canExpand)
            EmptyView(
              icon: Icons.commit_outlined,
              title: 'Sin detalle de commits',
              message: _whyNoDetail(push, defaultBranch),
            )
          else
            _PushChanges(
              push: (
                projectId: event.projectId,
                from: base,
                to: push.commitTo!,
              ),
              projectName: projectName,
              compareUrl: project?.webUrl == null
                  ? null
                  : '${project!.webUrl}/-/compare/$base...${push.commitTo}',
            ),
        ],
      ),
    );
  }

  static String _whyNoDetail(PushData? push, String? defaultBranch) {
    if (push == null) return 'Este evento no es un push.';
    if (push.isDegraded) {
      // GitLab recorta los pushes que superan su límite de actividad.
      return 'GitLab entregó este push sin el detalle de sus commits.';
    }
    if (defaultBranch == null) {
      return 'No se pudo determinar la rama por defecto del proyecto para '
          'comparar.';
    }
    return 'Este evento no incluye un rango de commits.';
  }
}

class _PushChanges extends ConsumerWidget {
  const _PushChanges({
    required this.push,
    required this.projectName,
    required this.compareUrl,
  });

  final PushRef push;
  final String projectName;
  final String? compareUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changes = ref.watch(pushChangesProvider(push));
    final theme = Theme.of(context);

    return changes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(pushChangesProvider(push)),
      ),
      data: (comparison) {
        if (comparison.commits.isEmpty && comparison.files.isEmpty) {
          return const EmptyView(
            icon: Icons.commit_outlined,
            title: 'Sin commits nuevos',
            message: 'La comparación no devolvió commits.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text('Commits', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 6),
                  Text(
                    '${comparison.commits.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final commit in comparison.commits)
              ListTile(
                leading: ToneIcon(
                  icon: Icons.commit,
                  tone: MergedColors.of(context).neutral,
                ),
                title: Text(
                  commit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: commit.shortId,
                        style: const TextStyle(fontFamily: monoFontFamily),
                      ),
                      TextSpan(
                        text:
                            ' · ${commit.authorName} · '
                            '${relativeTime(commit.createdAt)}',
                      ),
                    ],
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommitDetailScreen(
                      projectId: push.projectId,
                      commit: commit,
                      projectName: projectName,
                    ),
                  ),
                ),
              ),
            if (comparison.files.isNotEmpty)
              FileDiffList(
                files: comparison.files,
                webUrl: compareUrl,
                incomplete: comparison.truncated,
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
