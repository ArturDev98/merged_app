import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_event.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/activity_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';

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

    // En una creación de rama GitLab no manda commit_from: antes de ese push no
    // existía nada con lo que comparar. Se usa la rama por defecto del proyecto
    // como base, que da justo los commits que la rama introduce.
    final defaultBranch = ref
        .watch(projectsByIdProvider)[event.projectId]
        ?.defaultBranch;
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
            _CommitList(
              push: (
                projectId: event.projectId,
                from: base,
                to: push.commitTo!,
              ),
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
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      TextSpan(
                        text:
                            ' · ${commit.authorName} · '
                            '${relativeTime(commit.createdAt)}',
                      ),
                    ],
                  ),
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
