import 'package:flutter/material.dart';

import '../core/models/merge_request_summary.dart';

/// Los tres puntos de vista sobre los merge requests que ofrece la API.
enum MrScope { created, assigned, reviewing }

extension MrScopeX on MrScope {
  /// Valor del parámetro `scope` de `/merge_requests`.
  String get apiValue => switch (this) {
    MrScope.created => 'created_by_me',
    MrScope.assigned => 'assigned_to_me',
    MrScope.reviewing => 'reviews_for_me',
  };

  String get label => switch (this) {
    MrScope.created => 'Míos',
    MrScope.assigned => 'Asignados',
    MrScope.reviewing => 'A revisar',
  };

  /// Qué decir cuando no hay nada. En esta app el vacío es el estado normal de
  /// varias pestañas según el rol, así que merece un texto propio en cada una.
  String get emptyMessage => switch (this) {
    MrScope.created => 'No has abierto ningún merge request con este filtro.',
    MrScope.assigned => 'Nadie te ha asignado un merge request.',
    MrScope.reviewing => 'No te han pedido revisar ningún merge request.',
  };
}

/// Filtro de estado. GitLab acepta `opened`, `merged`, `closed` y `all`.
enum MrState { opened, merged, closed, all }

extension MrStateX on MrState {
  String get apiValue => name;

  String get label => switch (this) {
    MrState.opened => 'Abiertos',
    MrState.merged => 'Fusionados',
    MrState.closed => 'Cerrados',
    MrState.all => 'Todos',
  };
}

/// Texto legible del estado de un pipeline.
String pipelineLabel(String status) => switch (status) {
  'success' => 'Pipeline correcto',
  'failed' => 'Pipeline fallido',
  'running' => 'Pipeline en curso',
  'pending' || 'created' || 'waiting_for_resource' => 'Pipeline en espera',
  'canceled' || 'canceling' => 'Pipeline cancelado',
  'skipped' => 'Pipeline omitido',
  'manual' => 'Pipeline manual',
  'scheduled' => 'Pipeline programado',
  // Un estado que GitLab añada en el futuro se muestra tal cual, en lugar de
  // desaparecer bajo una etiqueta genérica.
  _ => 'Pipeline: $status',
};

IconData pipelineIcon(String status) => switch (status) {
  'success' => Icons.check_circle_outline,
  'failed' => Icons.cancel_outlined,
  'running' => Icons.autorenew,
  'pending' || 'created' || 'waiting_for_resource' => Icons.schedule,
  'canceled' || 'canceling' => Icons.block,
  'skipped' => Icons.skip_next_outlined,
  'manual' => Icons.pan_tool_outlined,
  _ => Icons.help_outline,
};

Color pipelineColor(String status, ColorScheme scheme) => switch (status) {
  'success' => Colors.green.shade700,
  'failed' => scheme.error,
  'running' || 'pending' || 'created' => Colors.orange.shade800,
  _ => scheme.outline,
};

/// Estado del propio merge request, no de su pipeline.
String mrStateLabel(MergeRequestSummary mr) => switch (mr.state) {
  'opened' => mr.draft ? 'Borrador' : 'Abierto',
  'merged' => 'Fusionado',
  'closed' => 'Cerrado',
  'locked' => 'Bloqueado',
  _ => mr.state,
};

IconData mrStateIcon(MergeRequestSummary mr) => switch (mr.state) {
  'opened' => mr.draft ? Icons.edit_note : Icons.merge_type,
  'merged' => Icons.merge,
  'closed' => Icons.cancel_outlined,
  'locked' => Icons.lock_outline,
  _ => Icons.help_outline,
};

Color mrStateColor(MergeRequestSummary mr, ColorScheme scheme) =>
    switch (mr.state) {
      'opened' => mr.draft ? scheme.outline : Colors.green.shade700,
      'merged' => Colors.purple.shade400,
      'closed' => scheme.error,
      _ => scheme.outline,
    };

/// Traduce el diagnóstico de fusión de GitLab.
///
/// Solo se traducen los casos que explican algo accionable; el resto se omite
/// en vez de mostrar una cadena interna como "checking".
String? mergeStatusLabel(String? detailedMergeStatus) =>
    switch (detailedMergeStatus) {
      'mergeable' => 'Listo para fusionar',
      'conflict' => 'Tiene conflictos',
      'ci_still_running' => 'Esperando al pipeline',
      'ci_must_pass' => 'El pipeline debe pasar',
      'not_approved' => 'Faltan aprobaciones',
      'draft_status' => 'Es un borrador',
      'discussions_not_resolved' => 'Hay comentarios sin resolver',
      'need_rebase' => 'Necesita rebase',
      'blocked_status' => 'Bloqueado por otro merge request',
      _ => null,
    };
