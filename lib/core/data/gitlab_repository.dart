import '../api/gitlab_client.dart';
import '../models/gitlab_project.dart';
import '../models/gitlab_user.dart';
import '../models/merge_request_summary.dart';
import '../models/push_event.dart';
import '../models/repo_commit.dart';
import '../models/todo_item.dart';

/// Acceso de lectura a GitLab. Traduce endpoints a modelos; no sabe nada de UI.
class GitlabRepository {
  GitlabRepository({GitlabClient? client})
    : _client = client ?? GitlabClient.instance;

  final GitlabClient _client;

  Future<GitlabUser> currentUser() =>
      _client.getOne('/user', parse: GitlabUser.fromJson);

  /// Proyectos donde el usuario es miembro.
  ///
  /// Se pide `simple=true` porque la respuesta completa trae más de 60 campos.
  /// Esta lista tiene doble función: es la pantalla de proyectos y además la
  /// tabla que permite traducir el `project_id` de los eventos a un nombre,
  /// dato que el feed de actividad no trae.
  Future<List<GitlabProject>> memberProjects({int maxPages = 5}) async {
    final all = <GitlabProject>[];
    int? page = 1;
    var guard = 0;
    while (page != null && guard++ < maxPages) {
      final result = await _client.getPage(
        '/projects',
        query: {
          'membership': true,
          'simple': true,
          'order_by': 'last_activity_at',
        },
        page: page,
        perPage: 100,
        parse: GitlabProject.fromJson,
      );
      all.addAll(result.items);
      page = result.nextPage;
    }
    return all;
  }

  /// Una página del feed de actividad.
  Future<Page<PushEvent>> events({int page = 1, int perPage = 30}) =>
      _client.getPage(
        '/events',
        page: page,
        perPage: perPage,
        parse: PushEvent.fromJson,
      );

  /// Commits reales de un push.
  ///
  /// Es la única forma de obtenerlos: los eventos solo traen el título del
  /// último commit. Se llama al abrir el detalle de un push, nunca al pintar
  /// la lista, para no convertir el feed en un N+1.
  Future<List<RepoCommit>> commitsForPush({
    required int projectId,
    required String from,
    required String to,
  }) async {
    final result = await _client.getOne(
      '/projects/$projectId/repository/compare',
      query: {'from': from, 'to': to},
      parse: (json) => json,
    );
    final commits = result['commits'];
    if (commits is! List) return const [];
    return commits
        .whereType<Map<String, dynamic>>()
        .map(RepoCommit.fromJson)
        .toList(growable: false);
  }

  /// Merge requests por scope: `created_by_me`, `assigned_to_me` o
  /// `reviews_for_me`.
  Future<Page<MergeRequestSummary>> mergeRequests({
    required String scope,
    String state = 'opened',
    int page = 1,
    int perPage = 30,
  }) => _client.getPage(
    '/merge_requests',
    query: {'scope': scope, 'state': state},
    page: page,
    perPage: perPage,
    parse: MergeRequestSummary.fromJson,
  );

  /// Pendientes. Solo acepta `pending` o `done`; `all` devuelve 400.
  Future<List<TodoItem>> pendingTodos({int perPage = 100}) async {
    final result = await _client.getPage(
      '/todos',
      query: {'state': 'pending'},
      perPage: perPage,
      parse: TodoItem.fromJson,
    );
    return result.items;
  }
}
