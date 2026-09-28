import 'gitlab_user.dart';

/// Pendiente de `/todos`: aprobaciones, menciones, pipelines rotos. Vacío en
/// la cuenta de desarrollo, pero es lo más lleno para un revisor.
class TodoItem {
  const TodoItem({
    required this.id,
    required this.actionName,
    required this.targetType,
    required this.body,
    required this.createdAt,
    this.targetUrl,
    this.author,
    this.projectName,
  });

  final int id;

  /// "assigned", "mentioned", "approval_required", "build_failed",
  /// "directly_addressed", "unmergeable"…
  final String actionName;

  /// "MergeRequest", "Issue", "Commit"…
  final String targetType;

  final String body;
  final DateTime? createdAt;
  final String? targetUrl;
  final GitlabUser? author;
  final String? projectName;

  bool get isMergeRequest => targetType == 'MergeRequest';

  /// Un mismo MR llega como todo de aprobación y en `reviews_for_me`: sin
  /// esta clave, la campana lo contaría dos veces.
  String? get dedupeKey => targetUrl?.split('#').first;

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'] as int,
    actionName: json['action_name'] as String? ?? '',
    targetType: json['target_type'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    targetUrl: json['target_url'] as String?,
    author: json['author'] is Map<String, dynamic>
        ? GitlabUser.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    projectName: json['project'] is Map<String, dynamic>
        ? (json['project'] as Map<String, dynamic>)['name_with_namespace']
              as String?
        : null,
  );
}
