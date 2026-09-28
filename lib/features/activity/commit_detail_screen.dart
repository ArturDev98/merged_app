import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/repo_commit.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/diff_view.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';

/// Un commit con su mensaje completo y sus archivos cambiados.
class CommitDetailScreen extends ConsumerWidget {
  const CommitDetailScreen({
    super.key,
    required this.projectId,
    required this.commit,
    this.projectName,
  });

  final int projectId;
  final RepoCommit commit;
  final String? projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = (projectId: projectId, sha: commit.id);
    final diff = ref.watch(commitDiffProvider(key));

    // El título ya va arriba: del mensaje solo interesa lo que viene después.
    final body = (commit.message ?? '').split('\n').skip(1).join('\n').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          commit.shortId,
          style: const TextStyle(fontFamily: monoFontFamily),
        ),
        actions: [
          if (commit.webUrl != null)
            IconButton(
              tooltip: 'Abrir en GitLab',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openInGitlab(context, commit.webUrl),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (projectName != null)
                  Text(
                    projectName!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(commit.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '${commit.authorName} · ${relativeTime(commit.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          diff.view(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(commitDiffProvider(key)),
            ),
            data: (page) => page.items.isEmpty
                ? const EmptyView(
                    icon: Icons.difference_outlined,
                    title: 'Sin archivos cambiados',
                    message: 'Este commit no modifica ningún archivo.',
                  )
                : FileDiffList(
                    files: page.items,
                    webUrl: commit.webUrl,
                    incomplete: page.hasMore,
                  ),
          ),
        ],
      ),
    );
  }
}
