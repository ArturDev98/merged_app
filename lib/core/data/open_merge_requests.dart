import '../api/gitlab_client.dart';
import '../models/merge_request_summary.dart';

/// Scopes de `/merge_requests`, en el orden de las pestañas de la app.
const mrScopes = ['created_by_me', 'assigned_to_me', 'reviews_for_me'];

/// MRs abiertos en los que participa el usuario, contados una vez: quien crea
/// un MR suele asignárselo y saldría repetido.
class OpenMergeRequests {
  const OpenMergeRequests(this.byScope);

  final Map<String, Page<MergeRequestSummary>> byScope;

  int get count => {
    for (final page in byScope.values)
      for (final mr in page.items) mr.id,
  }.length;

  /// Alguna lista tiene más páginas: el número es un mínimo.
  bool get capped => byScope.values.any((page) => page.hasMore);

  /// Pestaña que abrir desde la home: la primera que tenga algo.
  String get firstScopeWithItems => mrScopes.firstWhere(
    (scope) => byScope[scope]?.items.isNotEmpty ?? false,
    orElse: () => mrScopes.first,
  );
}
