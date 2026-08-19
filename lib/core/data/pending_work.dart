import '../models/merge_request_summary.dart';
import '../models/todo_item.dart';

/// Por qué algo está esperando al usuario.
enum PendingKind {
  /// Pendiente explícito de GitLab: mención, aprobación requerida, pipeline
  /// roto…
  todo,

  /// MR abierto donde el usuario figura como reviewer.
  reviewRequest,

  /// MR abierto asignado al usuario.
  assigned,
}

/// Un elemento de la campana, ya normalizado venga de donde venga.
class PendingItem {
  const PendingItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.reason,
    this.webUrl,
    this.at,
  });

  /// Clave de deduplicación (la URL normalizada del objeto de GitLab).
  final String key;
  final PendingKind kind;
  final String title;

  /// Texto corto que explica por qué aparece aquí.
  final String reason;

  final String? webUrl;
  final DateTime? at;
}

/// Normaliza una URL de GitLab para poder compararla entre fuentes.
///
/// Los todos apuntan al ancla del comentario
/// (`…/merge_requests/12#note_99`) mientras que el MR expone la URL limpia.
/// Sin recortar el fragmento, el mismo MR contaría dos veces.
String? normalizeGitlabUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  var normalized = url.split('#').first.split('?').first;
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.isEmpty ? null : normalized;
}

/// Funde las tres fuentes en la lista que alimenta la campana.
///
/// Un mismo MR llega a la vez como todo de tipo `approval_required` y en
/// `reviews_for_me`; sin deduplicar, el contador mentiría. Cuando algo aparece
/// por varias vías gana el todo, porque es el único que explica el motivo.
///
/// Deliberadamente NO recibe los MRs propios: esos son trabajo en curso, no
/// algo que bloquee al usuario, y van al resumen por separado.
List<PendingItem> mergePendingWork({
  required List<TodoItem> todos,
  required List<MergeRequestSummary> reviewing,
  required List<MergeRequestSummary> assigned,
}) {
  final byKey = <String, PendingItem>{};

  void add(PendingItem item) {
    // El primero en llegar manda: se recorren las fuentes por prioridad.
    byKey.putIfAbsent(item.key, () => item);
  }

  for (final todo in todos) {
    final key = normalizeGitlabUrl(todo.targetUrl) ?? 'todo:${todo.id}';
    add(
      PendingItem(
        key: key,
        kind: PendingKind.todo,
        title: todo.body,
        reason: _todoReason(todo.actionName),
        webUrl: todo.targetUrl,
        at: todo.createdAt,
      ),
    );
  }

  for (final mr in reviewing) {
    final key = normalizeGitlabUrl(mr.webUrl) ?? 'mr:${mr.id}';
    add(
      PendingItem(
        key: key,
        kind: PendingKind.reviewRequest,
        title: mr.title,
        reason: 'Te toca revisarlo',
        webUrl: mr.webUrl,
        at: mr.updatedAt,
      ),
    );
  }

  for (final mr in assigned) {
    final key = normalizeGitlabUrl(mr.webUrl) ?? 'mr:${mr.id}';
    add(
      PendingItem(
        key: key,
        kind: PendingKind.assigned,
        title: mr.title,
        reason: 'Asignado a ti',
        webUrl: mr.webUrl,
        at: mr.updatedAt,
      ),
    );
  }

  final items = byKey.values.toList();
  // Lo más reciente arriba; lo que no trae fecha, al final.
  items.sort((a, b) {
    if (a.at == null && b.at == null) return 0;
    if (a.at == null) return 1;
    if (b.at == null) return -1;
    return b.at!.compareTo(a.at!);
  });
  return items;
}

String _todoReason(String actionName) => switch (actionName) {
  'assigned' => 'Te lo asignaron',
  'review_requested' => 'Te pidieron revisión',
  'approval_required' => 'Requiere tu aprobación',
  'mentioned' || 'directly_addressed' => 'Te mencionaron',
  'build_failed' => 'El pipeline falló',
  'unmergeable' => 'No se puede fusionar',
  'merge_train_removed' => 'Salió del merge train',
  _ => 'Pendiente',
};
