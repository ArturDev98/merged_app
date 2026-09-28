import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/merge_request_detail.dart';
import '../../core/models/merge_request_summary.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/diff_view.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';

/// Detalle de un merge request. Único sitio con el pipeline: la lista de la
/// API no trae `head_pipeline`.
class MergeRequestDetailScreen extends ConsumerWidget {
  const MergeRequestDetailScreen({super.key, required this.mr});

  /// El resumen que ya traía la lista, para poder pintar algo mientras carga
  /// el detalle en vez de dejar la pantalla en blanco.
  final MergeRequestSummary mr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref_ = (projectId: mr.projectId, iid: mr.iid);
    final detail = ref.watch(mergeRequestDetailProvider(ref_));
    final theme = Theme.of(context);
    final colors = MergedColors.of(context);
    final project = ref.watch(projectsByIdProvider)[mr.projectId];

    return Scaffold(
      appBar: AppBar(
        title: Text('!${mr.iid}'),
        actions: [
          IconButton(
            tooltip: 'Abrir en GitLab',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openInGitlab(context, mr.webUrl),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mergeRequestDetailProvider(ref_)),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (project != null)
                    Text(
                      project.nameWithNamespace,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(mr.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TonePill(
                        icon: mrStateIcon(mr),
                        label: mrStateLabel(mr),
                        tone: mrStateTone(mr, colors),
                      ),
                      TonePill(
                        icon: Icons.call_split,
                        label: '${mr.sourceBranch} → ${mr.targetBranch}',
                        tone: colors.neutral,
                      ),
                      if (mr.userNotesCount > 0)
                        TonePill(
                          icon: Icons.mode_comment_outlined,
                          label: mr.userNotesCount == 1
                              ? '1 comentario'
                              : '${mr.userNotesCount} comentarios',
                          tone: colors.neutral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // El pipeline y el diagnóstico de fusión solo existen en el
            // detalle, así que tienen su propio bloque de carga.
            detail.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(mergeRequestDetailProvider(ref_)),
              ),
              data: (data) => _DetailBody(detail: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final MergeRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MergedColors.of(context);
    final pipeline = detail.headPipeline;
    final mergeStatus = mergeStatusLabel(detail.detailedMergeStatus);
    final description = detail.description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pipeline != null)
          ListTile(
            leading: ToneIcon(
              icon: pipelineIcon(pipeline.status),
              tone: pipelineTone(pipeline.status, colors),
            ),
            title: Text(pipelineLabel(pipeline.status)),
            subtitle: Text(
              [
                if (pipeline.ref != null) pipeline.ref!,
                if (pipeline.updatedAt != null)
                  relativeTime(pipeline.updatedAt),
              ].join(' · '),
            ),
            trailing: pipeline.webUrl != null
                ? Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: theme.colorScheme.outline,
                  )
                : null,
            onTap: pipeline.webUrl != null
                ? () => openInGitlab(context, pipeline.webUrl)
                : null,
          )
        else
          // Distinguir "sin CI" de "no lo sabemos" evita que el usuario piense
          // que la app no lo está mostrando.
          ListTile(
            leading: ToneIcon(
              icon: Icons.remove_circle_outline,
              tone: colors.neutral,
            ),
            title: const Text('Sin pipeline'),
            subtitle: const Text(
              'Este merge request no tiene ninguna ejecución de CI.',
            ),
          ),
        if (mergeStatus != null)
          ListTile(
            leading: ToneIcon(
              icon: Icons.rule,
              tone: mergeStatusTone(detail.detailedMergeStatus, colors),
            ),
            title: Text(mergeStatus),
          ),
        if (detail.upvotes > 0 || detail.downvotes > 0)
          ListTile(
            leading: ToneIcon(
              icon: Icons.thumbs_up_down_outlined,
              tone: colors.neutral,
            ),
            title: Text('${detail.upvotes} 👍 · ${detail.downvotes} 👎'),
          ),
        if (description != null && description.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Descripción', style: theme.textTheme.titleSmall),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(description, style: theme.textTheme.bodyMedium),
          ),
        ],
        _Changes(detail: detail),
      ],
    );
  }
}

// Lo que la API sirve en una página; con más, un móvil ya no es el sitio.
const _maxFilesInApp = 30;

class _Changes extends ConsumerWidget {
  const _Changes({required this.detail});

  final MergeRequestDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = detail.changedFiles;
    final mr = detail.summary;
    final diffsUrl = mr.webUrl == null ? null : '${mr.webUrl}/diffs';
    // Sin dato (MR recién creado, GitLab aún calcula) o sin cambios: nada.
    if (count == null || count == 0) return const SizedBox.shrink();

    if (count > _maxFilesInApp) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archivos cambiados · ${detail.changesCount}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Son demasiados para revisarlos aquí.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => openInGitlab(context, diffsUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ver los cambios en GitLab'),
            ),
          ],
        ),
      );
    }

    final key = (projectId: mr.projectId, iid: mr.iid);
    return ref
        .watch(mergeRequestDiffsProvider(key))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(mergeRequestDiffsProvider(key)),
          ),
          data: (page) => FileDiffList(
            files: page.items,
            webUrl: diffsUrl,
            incomplete: page.hasMore,
          ),
        );
  }
}
