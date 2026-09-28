import 'merge_request_summary.dart';

/// Pipeline asociado a un merge request.
class PipelineInfo {
  const PipelineInfo({
    required this.id,
    required this.status,
    this.ref,
    this.webUrl,
    this.updatedAt,
  });

  final int id;

  /// "success", "failed", "running"… Texto y no enum: un estado nuevo de
  /// GitLab se perdería en silencio.
  final String status;

  final String? ref;
  final String? webUrl;
  final DateTime? updatedAt;

  factory PipelineInfo.fromJson(Map<String, dynamic> json) => PipelineInfo(
    id: json['id'] as int? ?? 0,
    status: json['status'] as String? ?? 'unknown',
    ref: json['ref'] as String?,
    webUrl: json['web_url'] as String?,
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
  );
}

/// Merge request con lo que solo trae el detalle: la lista no incluye
/// `head_pipeline` (comprobado), así que el tipo impide prometerlo allí.
class MergeRequestDetail {
  const MergeRequestDetail({
    required this.summary,
    this.headPipeline,
    this.description,
    this.upvotes = 0,
    this.downvotes = 0,
    this.detailedMergeStatus,
    this.mergedAt,
    this.closedAt,
    this.changesCount,
  });

  final MergeRequestSummary summary;

  /// Null si el MR no tiene pipeline (proyecto sin CI, o aún sin ejecutar).
  final PipelineInfo? headPipeline;

  final String? description;
  final int upvotes;
  final int downvotes;

  /// Diagnóstico de GitLab sobre si se puede fusionar: "mergeable",
  /// "ci_still_running", "not_approved", "conflict"…
  final String? detailedMergeStatus;

  final DateTime? mergedAt;
  final DateTime? closedAt;

  /// Archivos cambiados. GitLab lo manda como texto y lo corta en "1000+";
  /// llega vacío mientras calcula el diff de un MR recién creado.
  final String? changesCount;

  /// El número, o null si no llegó. "1000+" cuenta como 1000.
  int? get changedFiles =>
      int.tryParse(changesCount?.replaceAll('+', '') ?? '');

  factory MergeRequestDetail.fromJson(Map<String, dynamic> json) {
    // `pipeline` es el nombre antiguo del mismo dato; se consulta como
    // respaldo por si la instancia es vieja.
    final pipeline = json['head_pipeline'] ?? json['pipeline'];

    return MergeRequestDetail(
      summary: MergeRequestSummary.fromJson(json),
      headPipeline: pipeline is Map<String, dynamic>
          ? PipelineInfo.fromJson(pipeline)
          : null,
      description: json['description'] as String?,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      detailedMergeStatus: json['detailed_merge_status'] as String?,
      mergedAt: DateTime.tryParse(json['merged_at'] as String? ?? ''),
      closedAt: DateTime.tryParse(json['closed_at'] as String? ?? ''),
      changesCount: json['changes_count']?.toString(),
    );
  }
}
