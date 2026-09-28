/// Proyecto de GitLab, pedido con `simple=true` (la respuesta completa trae
/// 60+ campos). También nombra el `project_id` de los eventos.
class GitlabProject {
  const GitlabProject({
    required this.id,
    required this.name,
    required this.nameWithNamespace,
    required this.pathWithNamespace,
    this.description,
    this.avatarUrl,
    this.webUrl,
    this.defaultBranch,
    this.lastActivityAt,
  });

  final int id;
  final String name;
  final String nameWithNamespace;
  final String pathWithNamespace;
  final String? description;
  final String? avatarUrl;
  final String? webUrl;
  final String? defaultBranch;
  final DateTime? lastActivityAt;

  factory GitlabProject.fromJson(Map<String, dynamic> json) => GitlabProject(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    nameWithNamespace: json['name_with_namespace'] as String? ?? '',
    pathWithNamespace: json['path_with_namespace'] as String? ?? '',
    description: json['description'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    webUrl: json['web_url'] as String?,
    defaultBranch: json['default_branch'] as String?,
    lastActivityAt: DateTime.tryParse(
      json['last_activity_at'] as String? ?? '',
    ),
  );
}
