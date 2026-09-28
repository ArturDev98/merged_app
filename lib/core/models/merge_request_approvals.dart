import 'gitlab_user.dart';

/// Aprobaciones de un MR, de `…/approvals` (también en el plan Free).
class MergeRequestApprovals {
  const MergeRequestApprovals({
    required this.approved,
    required this.approvedBy,
    this.approvalsLeft,
    this.userCanApprove,
  });

  final bool approved;
  final List<GitlabUser> approvedBy;

  /// Solo con reglas de aprobación, que son de los planes de pago.
  final int? approvalsLeft;

  /// Null si la API no lo dice: entonces se ofrece aprobar y GitLab decide.
  final bool? userCanApprove;

  bool approvedByUser(int userId) => approvedBy.any((u) => u.id == userId);

  factory MergeRequestApprovals.fromJson(Map<String, dynamic> json) {
    final approvedBy = [
      for (final entry in json['approved_by'] as List? ?? const [])
        if (entry is Map<String, dynamic> &&
            entry['user'] is Map<String, dynamic>)
          GitlabUser.fromJson(entry['user'] as Map<String, dynamic>),
    ];
    return MergeRequestApprovals(
      approved: json['approved'] as bool? ?? approvedBy.isNotEmpty,
      approvedBy: approvedBy,
      approvalsLeft: json['approvals_left'] as int?,
      userCanApprove: json['user_can_approve'] as bool?,
    );
  }
}
