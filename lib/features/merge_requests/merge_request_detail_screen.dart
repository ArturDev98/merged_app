import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/merge_request_detail.dart';
import '../../core/models/merge_request_summary.dart';
import '../../core/providers.dart';
import '../../shared/merge_request_labels.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';

/// Detalle de un merge request.
///
/// Es el único sitio donde se puede mostrar el pipeline: la lista de la API no
/// devuelve `head_pipeline`.
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
    final scheme = theme.colorScheme;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mr.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        icon: mrStateIcon(mr),
                        label: mrStateLabel(mr),
                        color: mrStateColor(mr, scheme),
                      ),
                      _Chip(
                        icon: Icons.call_split,
                        label: '${mr.sourceBranch} → ${mr.targetBranch}',
                        color: scheme.outline,
                      ),
                      if (mr.userNotesCount > 0)
                        _Chip(
                          icon: Icons.mode_comment_outlined,
                          label: '${mr.userNotesCount} comentarios',
                          color: scheme.outline,
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
    final scheme = theme.colorScheme;
    final pipeline = detail.headPipeline;
    final mergeStatus = mergeStatusLabel(detail.detailedMergeStatus);
    final description = detail.description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pipeline != null)
          ListTile(
            leading: Icon(
              pipelineIcon(pipeline.status),
              color: pipelineColor(pipeline.status, scheme),
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
                ? const Icon(Icons.open_in_new, size: 18)
                : null,
            onTap: pipeline.webUrl != null
                ? () => openInGitlab(context, pipeline.webUrl)
                : null,
          )
        else
          // Distinguir "sin CI" de "no lo sabemos" evita que el usuario piense
          // que la app no lo está mostrando.
          ListTile(
            leading: Icon(Icons.remove_circle_outline, color: scheme.outline),
            title: const Text('Sin pipeline'),
            subtitle: const Text(
              'Este merge request no tiene ninguna ejecución de CI.',
            ),
          ),
        if (mergeStatus != null)
          ListTile(
            leading: Icon(Icons.rule, color: scheme.outline),
            title: Text(mergeStatus),
          ),
        if (detail.upvotes > 0 || detail.downvotes > 0)
          ListTile(
            leading: Icon(Icons.thumbs_up_down_outlined, color: scheme.outline),
            title: Text('${detail.upvotes} 👍 · ${detail.downvotes} 👎'),
          ),
        if (description != null && description.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Descripción', style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(description, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
