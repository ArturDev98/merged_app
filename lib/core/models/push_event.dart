import 'gitlab_user.dart';

/// Qué hizo el push: crear una referencia, empujar commits a una existente,
/// o borrarla.
enum PushAction { created, pushed, removed, unknown }

/// Un evento de `/events`.
///
/// Ojo: el payload trae `project_id` pero **no** el nombre del proyecto, así
/// que la UI necesita resolverlo contra la lista de proyectos.
class PushEvent {
  const PushEvent({
    required this.id,
    required this.projectId,
    required this.actionName,
    required this.createdAt,
    required this.author,
    this.pushData,
  });

  final int id;
  final int projectId;

  /// Texto tal cual lo da GitLab: "pushed to", "pushed new", "opened"…
  final String actionName;
  final DateTime createdAt;
  final GitlabUser? author;
  final PushData? pushData;

  bool get isPush => pushData != null;

  factory PushEvent.fromJson(Map<String, dynamic> json) => PushEvent(
    id: json['id'] as int,
    projectId: json['project_id'] as int? ?? 0,
    actionName: json['action_name'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    author: json['author'] is Map<String, dynamic>
        ? GitlabUser.fromJson(json['author'] as Map<String, dynamic>)
        : null,
    pushData: json['push_data'] is Map<String, dynamic>
        ? PushData.fromJson(json['push_data'] as Map<String, dynamic>)
        : null,
  );
}

class PushData {
  const PushData({
    required this.action,
    required this.refType,
    required this.ref,
    required this.commitCount,
    this.commitFrom,
    this.commitTo,
    this.commitTitle,
  });

  final PushAction action;

  /// "branch" o "tag".
  final String refType;

  /// Nombre de la rama o etiqueta.
  final String ref;

  /// Número de commits del push. GitLab lo manda a 0 en los pushes masivos
  /// que superan su límite de actividad, junto con los demás campos nulos.
  final int commitCount;

  final String? commitFrom;
  final String? commitTo;

  /// Título del **último** commit del push, no de todos.
  final String? commitTitle;

  bool get isBranch => refType == 'branch';

  /// Rama creada en este push. La pantalla de ramas se construye con esto,
  /// sin llamadas extra.
  bool get createsBranch => isBranch && action == PushAction.created;

  /// Un push masivo llega sin detalle de commits; la UI no debe prometer que
  /// puede expandirlo.
  bool get isDegraded => commitCount == 0 || commitTo == null;

  /// Los commits reales se piden con
  /// `/projects/:id/repository/compare?from=commitFrom&to=commitTo`.
  bool get canExpandCommits =>
      commitFrom != null && commitTo != null && !isDegraded;

  factory PushData.fromJson(Map<String, dynamic> json) => PushData(
    action: switch (json['action'] as String?) {
      'created' => PushAction.created,
      'pushed' => PushAction.pushed,
      'removed' => PushAction.removed,
      _ => PushAction.unknown,
    },
    refType: json['ref_type'] as String? ?? '',
    ref: json['ref'] as String? ?? '',
    commitCount: json['commit_count'] as int? ?? 0,
    commitFrom: json['commit_from'] as String?,
    commitTo: json['commit_to'] as String?,
    commitTitle: json['commit_title'] as String?,
  );
}
