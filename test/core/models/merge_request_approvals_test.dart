import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/merge_request_approvals.dart';

void main() {
  test('lee quién aprobó y si fue el usuario actual', () {
    final approvals = MergeRequestApprovals.fromJson({
      'approved': true,
      'approved_by': [
        {
          'user': {'id': 7, 'username': 'cruiz', 'name': 'Carlos Ruiz'},
          'approved_at': '2026-09-28T10:00:00Z',
        },
      ],
      'approvals_left': 0,
    });

    expect(approvals.approvedBy.single.name, 'Carlos Ruiz');
    expect(approvals.approvedByUser(7), isTrue);
    expect(approvals.approvedByUser(1), isFalse);
    // La API no siempre dice si puedes aprobar: entonces se deja a GitLab.
    expect(approvals.userCanApprove, isNull);
  });

  test('sin campo approved, lo deduce de la lista', () {
    expect(MergeRequestApprovals.fromJson({}).approved, isFalse);
    expect(MergeRequestApprovals.fromJson({}).approvedBy, isEmpty);
  });
}
