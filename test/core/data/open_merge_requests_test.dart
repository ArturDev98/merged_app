import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/api/gitlab_client.dart';
import 'package:merged_app/core/data/open_merge_requests.dart';
import 'package:merged_app/core/models/merge_request_summary.dart';

Page<MergeRequestSummary> _page(List<int> ids, {bool more = false}) => Page(
  items: [
    for (final id in ids) MergeRequestSummary.fromJson({'id': id, 'iid': id}),
  ],
  raw: const [],
  nextPage: more ? 2 : null,
);

void main() {
  test('un MR propio y asignado a uno mismo cuenta una vez', () {
    final open = OpenMergeRequests({
      'created_by_me': _page([1, 2]),
      'assigned_to_me': _page([2, 3]),
      'reviews_for_me': _page([]),
    });

    expect(open.count, 3);
    expect(open.capped, isFalse);
  });

  test('con solo asignados, el acceso abre esa pestaña y no "Míos"', () {
    final open = OpenMergeRequests({
      'created_by_me': _page([]),
      'assigned_to_me': _page([621]),
      'reviews_for_me': _page([]),
    });

    expect(open.count, 1);
    expect(open.firstScopeWithItems, 'assigned_to_me');
  });

  test('sin nada abierto se queda en "Míos"', () {
    final open = OpenMergeRequests({
      for (final scope in mrScopes) scope: _page([]),
    });

    expect(open.count, 0);
    expect(open.firstScopeWithItems, 'created_by_me');
  });

  test('si una lista tiene más páginas, el número es un mínimo', () {
    final open = OpenMergeRequests({
      'created_by_me': _page([1], more: true),
    });

    expect(open.capped, isTrue);
  });
}
