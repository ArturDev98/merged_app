import 'package:flutter/material.dart';

import '../core/models/activity_event.dart';

/// Traduce `action_name` de GitLab a una frase en primera persona.
///
/// La API devuelve etiquetas en inglés y pensadas para un feed en tercera
/// persona ("joined", "pushed to"). Sin traducirlas, un evento de alta en un
/// proyecto se mostraba con el nombre del proyecto repetido en el título y en
/// el subtítulo, sin decir en ningún momento qué había ocurrido.
String describeActivity(ActivityEvent event) {
  final push = event.pushData;
  if (push != null) {
    return switch (push.action) {
      PushAction.created => 'Creaste la rama',
      PushAction.removed => 'Borraste la rama',
      PushAction.pushed || PushAction.unknown => 'Hiciste push',
    };
  }

  final target = _targetLabel(event.targetType);
  return switch (event.actionName) {
    'joined' => 'Te uniste al proyecto',
    'left' => 'Saliste del proyecto',
    'opened' => target == null ? 'Abriste un elemento' : 'Abriste $target',
    'closed' => target == null ? 'Cerraste un elemento' : 'Cerraste $target',
    'accepted' => 'Se fusionó ${target ?? 'un merge request'}',
    'commented on' => 'Comentaste',
    'created' => 'Creaste el proyecto',
    'deleted' => 'Borraste algo',
    'updated' => 'Actualizaste algo',
    _ => event.actionName,
  };
}

String? _targetLabel(String? targetType) => switch (targetType) {
  'MergeRequest' => 'un merge request',
  'Issue' => 'una incidencia',
  'Milestone' => 'un hito',
  'Note' || 'DiffNote' || 'DiscussionNote' => 'un comentario',
  _ => null,
};

/// Icono acorde a lo que ocurrió.
IconData activityIcon(ActivityEvent event) {
  final push = event.pushData;
  if (push != null) {
    if (push.createsBranch) return Icons.call_split;
    if (push.action == PushAction.removed) return Icons.delete_outline;
    return Icons.arrow_upward;
  }

  return switch (event.actionName) {
    'joined' => Icons.group_add_outlined,
    'left' => Icons.logout,
    'opened' => Icons.merge_type,
    'closed' => Icons.cancel_outlined,
    'accepted' => Icons.merge,
    'commented on' => Icons.mode_comment_outlined,
    'created' => Icons.create_new_folder_outlined,
    _ => Icons.bolt_outlined,
  };
}
