import 'gitlab_user.dart';

/// Qué hizo el push: crear una referencia, empujar commits a una existente,
/// o borrarla.
enum PushAction { created, pushed, removed, unknown }

/// Un evento de `/events`.
///
/// No todos son pushes: el feed trae también `opened` (un MR abierto) y
/// `joined`. Por eso `pushData` es opcional y existe `isPush`.
///
/// Ojo: el payload trae `project_id` pero **no** el nombre del proyecto, así
/// que la UI necesita resolverlo contra la lista de proyectos.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.projectId,
    required this.actionName,
    required this.createdAt,
    required this.author,
    this.pushData,
    this.targetTitle,
    this.targetType,
  });

  final int id;
  final int projectId;

  /// Texto tal cual lo da GitLab: "pushed to", "pushed new", "opened"…
  final String actionName;
  final DateTime createdAt;
  final GitlabUser? author;
  final PushData? pushData;

  /// Título del objeto afectado en los eventos que no son push (el título del
  /// MR en un `opened`, por ejemplo).
  final String? targetTitle;

  /// "MergeRequest", "Issue"… Nulo en los pushes, que apuntan al proyecto.
  final String? targetType;

  bool get isPush => pushData != null;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
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
    targetTitle: json['target_title'] as String?,
    targetType: json['target_type'] as String?,
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

  /// Hay un destino con el que comparar. **No** implica que haya base: en las
  /// creaciones de rama (`pushed new`) GitLab manda `commit_from` nulo, porque
  /// antes de ese push no existía nada con lo que comparar.
  bool get hasTarget => commitTo != null && !isDegraded;

  /// Si hace falta suplir la base con la rama por defecto del proyecto.
  ///
  /// Era la causa de que un tercio del feed mostrara "sin detalle de commits":
  /// toda rama recién creada entraba por aquí.
  bool get needsBaseFallback => hasTarget && commitFrom == null;

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
