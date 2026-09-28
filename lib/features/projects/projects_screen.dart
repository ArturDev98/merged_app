import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/gitlab_project.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/open_in_gitlab.dart';
import '../../shared/relative_time.dart';
import '../../shared/state_views.dart';
import '../../shared/tone_icon.dart';

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
              separatorBuilder: (_, _) => const Divider(indent: 68),
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
      leading: project.avatarUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                project.avatarUrl!,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                // Avatar privado o sin red: mejor la inicial que un hueco.
                errorBuilder: (_, _, _) => _letter(context),
              ),
            )
          : _letter(context),
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
      trailing: Icon(
        Icons.open_in_new,
        size: 18,
        color: theme.colorScheme.outline,
      ),
      onTap: () => openInGitlab(context, project.webUrl),
    );
  }

  Widget _letter(BuildContext context) => ToneIcon.letter(
    letter: project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
    tone: MergedColors.of(context).blue,
  );
}
