import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/models/merge_request_summary.dart';
import '../core/theme/app_theme.dart';

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

Tone pipelineTone(String status, MergedColors colors) => switch (status) {
  'success' => colors.green,
  'failed' => colors.red,
  'running' || 'pending' || 'created' || 'waiting_for_resource' => colors.amber,
  _ => colors.neutral,
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

Tone mrStateTone(MergeRequestSummary mr, MergedColors colors) =>
    switch (mr.state) {
      'opened' => mr.draft ? colors.neutral : colors.green,
      'merged' => colors.purple,
      'closed' => colors.red,
      _ => colors.neutral,
    };

/// Diagnóstico de fusión traducido. Solo los casos accionables; el resto
/// ("checking"…) se omite en vez de enseñar la cadena interna.
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

/// Verde si se puede fusionar, rojo si algo lo bloquea, ámbar si solo falta
/// tiempo o una persona.
Tone mergeStatusTone(String? detailedMergeStatus, MergedColors colors) =>
    switch (detailedMergeStatus) {
      'mergeable' => colors.green,
      'conflict' || 'need_rebase' || 'blocked_status' => colors.red,
      'ci_must_pass' => colors.red,
      _ => colors.amber,
    };

/// Qué decir cuando aprobar o quitar la aprobación falla, según lo que
/// responde GitLab.
String approvalErrorMessage(Object error, {required bool approving}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] == 'insufficient_scope') {
      return 'Tu sesión no tiene permiso para aprobar. Cierra sesión y vuelve '
          'a entrar.';
    }
    switch (error.response?.statusCode) {
      case 409:
        return 'El merge request cambió mientras lo mirabas. Recárgalo antes '
            'de aprobar.';
      case 401:
        return approving
            ? 'GitLab no te deja aprobarlo: puede que ya lo hayas aprobado.'
            : 'GitLab no te deja quitar la aprobación.';
      case 403:
        return 'Tu cuenta no tiene permiso para esto en este proyecto.';
      case 404:
        return approving
            ? 'No se encontró el merge request.'
            : 'No había una aprobación tuya que quitar.';
    }
    if (error.type != DioExceptionType.badResponse) {
      return 'Sin conexión con GitLab. Inténtalo de nuevo.';
    }
  }
  return 'No se pudo completar. Inténtalo de nuevo.';
}
