import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/gitlab_project.dart';
import '../../core/providers.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';

/// Proyectos donde el usuario es miembro.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Proyectos')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(projectsProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.folder_off_outlined,
                title: 'Sin proyectos',
                message: 'No eres miembro de ningún proyecto en GitLab.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(projectsProvider.future),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ProjectTile(project: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final GitlabProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // El namespace (el grupo) se muestra aparte del nombre: juntos no caben en
    // una línea de móvil y lo que se pierde es siempre el nombre.
    final namespace = project.nameWithNamespace.contains('/')
        ? project.nameWithNamespace.split('/').first.trim()
        : null;

    final activity = project.lastActivityAt;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: project.avatarUrl != null
            ? NetworkImage(project.avatarUrl!)
            : null,
        child: project.avatarUrl == null
            ? Text(
                project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
              )
            : null,
      ),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          ?namespace,
          ?project.defaultBranch,
          if (activity != null) relativeTime(activity),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => openInGitlab(context, project.webUrl),
    );
  }
}
