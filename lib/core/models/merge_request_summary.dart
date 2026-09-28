import 'gitlab_user.dart';

/// Merge request tal como lo da la lista (`/merge_requests`), que no trae
/// `head_pipeline`: el pipeline solo puede mostrarse en el detalle.
class MergeRequestSummary {
  const MergeRequestSummary({
    required this.id,
    required this.iid,
    required this.projectId,
    required this.title,
    required this.state,
    required this.draft,
    required this.sourceBranch,
    required this.targetBranch,
    required this.createdAt,
    required this.updatedAt,
    required this.userNotesCount,
    this.author,
    this.webUrl,
    this.hasConflicts,
    this.mergeStatus,
  });

  final int id;

  /// El número visible (!450). Es el que se usa en la UI y en las rutas de la
  /// API por proyecto; `id` es global e interno.
  final int iid;

  final int projectId;
  final String title;

  /// "opened", "closed", "locked" o "merged".
  final String state;

  final bool draft;
  final String sourceBranch;
  final String targetBranch;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int userNotesCount;
  final GitlabUser? author;
  final String? webUrl;
  final bool? hasConflicts;
  final String? mergeStatus;

  bool get isOpen => state == 'opened';

  factory MergeRequestSummary.fromJson(
    Map<String, dynamic> json,
  ) => MergeRequestSummary(
    id: json['id'] as int,
    iid: json['iid'] as int? ?? 0,
    projectId: json['project_id'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    state: json['state'] as String? ?? '',
    // `work_in_progress` es el nombre antiguo del mismo dato; se consulta
    // como respaldo por si la instancia es vieja.
    draft: json['draft'] as bool? ?? json['work_in_progress'] as bool? ?? false,
    sourceBranch: json['source_branch'] as String? ?? '',
    targetBranch: json['target_branch'] as String? ?? '',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    userNotesCount: json['user_notes_count'] as int? ?? 0,
    author: json['author'] is Map<String, dynamic>
        ? GitlabUser.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    webUrl: json['web_url'] as String?,
    hasConflicts: json['has_conflicts'] as bool?,
    mergeStatus: json['merge_status'] as String?,
  );
}
