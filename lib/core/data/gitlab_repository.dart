import '../api/gitlab_client.dart';
import '../models/gitlab_project.dart';
import '../models/gitlab_user.dart';
import '../models/merge_request_detail.dart';
import '../models/merge_request_summary.dart';
import '../models/activity_event.dart';
import '../models/file_diff.dart';
import '../models/todo_item.dart';
import 'response_cache.dart';

/// Acceso de lectura a GitLab. Traduce endpoints a modelos; no sabe nada de UI.
class GitlabRepository {
  GitlabRepository({GitlabClient? client, ResponseCache? cache})
    : _client = client ?? GitlabClient.instance,
      cache = cache ?? ResponseCache();

  final GitlabClient _client;

  /// Última respuesta buena de cada consulta, para poder abrir la app sin
  /// conexión.
  final ResponseCache cache;

  /// Red primero; el disco solo si la petición falla. Nunca caché en silencio
  /// con red: los datos viejos se confundirían con los actuales.
  Future<List<T>> _networkFirst<T>({
    required String key,
    required Future<List<Map<String, dynamic>>> Function() fetch,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    try {
      final raw = await fetch();
      await cache.write(key, raw);
      return raw.map(parse).toList(growable: false);
    } catch (error) {
      final cached = await cache.read(key);
      if (cached == null) rethrow;
      cache.markServedFromCache(cached.savedAt);
      return cached.data.map(parse).toList(growable: false);
    }
  }

  Future<GitlabUser> currentUser() =>
      _client.getOne('/user', parse: GitlabUser.fromJson);

  /// Proyectos del usuario. `simple=true` porque la completa trae 60+ campos;
  /// también sirve para poner nombre al `project_id` de los eventos.
  Future<List<GitlabProject>> memberProjects({int maxPages = 5}) =>
      _networkFirst(
        key: 'projects',
        parse: GitlabProject.fromJson,
        fetch: () async {
          final all = <Map<String, dynamic>>[];
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
            all.addAll(result.raw);
            page = result.nextPage;
          }
          return all;
        },
      );

  /// Una página del feed de actividad.
  Future<Page<ActivityEvent>> events({int page = 1, int perPage = 30}) async {
    try {
      final result = await _client.getPage(
        '/events',
        page: page,
        perPage: perPage,
        parse: ActivityEvent.fromJson,
      );
      // Solo se guarda la primera página: es lo que hace falta para que la app
      // abra con contenido sin conexión, y evita acumular el feed entero.
      if (page == 1) await cache.write('events_feed', result.raw);
      return result;
    } catch (error) {
      if (page != 1) rethrow;
      final cached = await cache.read('events_feed');
      if (cached == null) rethrow;
      cache.markServedFromCache(cached.savedAt);
      return Page<ActivityEvent>(
        items: cached.data.map(ActivityEvent.fromJson).toList(growable: false),
        raw: cached.data,
        // Sin red no se puede paginar: no se ofrece una siguiente página que
        // fallaría al pedirla.
        nextPage: null,
      );
    }
  }

  /// Eventos desde una fecha, con `after` de la API: así la ventana es real y
  /// no depende de cuánto feed haya cargado el usuario.
  Future<List<ActivityEvent>> eventsSince(
    DateTime since, {
    int maxPages = 4,
    int perPage = 100,
  }) async {
    return _networkFirst(
      key: 'events_since',
      parse: ActivityEvent.fromJson,
      fetch: () async {
        final all = <Map<String, dynamic>>[];
        int? page = 1;
        var guard = 0;
        while (page != null && guard++ < maxPages) {
          final result = await _client.getPage(
            '/events',
            query: {'after': _isoDate(since)},
            page: page,
            perPage: perPage,
            parse: ActivityEvent.fromJson,
          );
          all.addAll(result.raw);
          page = result.nextPage;
        }
        return all;
      },
    );
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Commits y archivos de un push en una sola llamada. Solo al abrir el
  /// detalle, nunca al pintar el feed: sería un N+1.
  Future<Comparison> compare({
    required int projectId,
    required String from,
    required String to,
  }) => _client.getOne(
    '/projects/$projectId/repository/compare',
    query: {'from': from, 'to': to},
    parse: Comparison.fromJson,
  );

  /// Archivos cambiados por un commit. GitLab deja de añadir archivos al
  /// llegar a sus límites de diff: si hay página siguiente, faltan archivos.
  Future<Page<FileDiff>> commitDiff({
    required int projectId,
    required String sha,
  }) => _client.getPage(
    '/projects/$projectId/repository/commits/$sha/diff',
    perPage: 100,
    parse: FileDiff.fromJson,
  );

  /// Archivos cambiados por un merge request. La API no sirve más de 30 por
  /// página aunque se pidan más.
  Future<Page<FileDiff>> mergeRequestDiffs({
    required int projectId,
    required int iid,
  }) => _client.getPage(
    '/projects/$projectId/merge_requests/$iid/diffs',
    perPage: 30,
    parse: FileDiff.fromJson,
  );

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

  /// Detalle de un MR, con lo que la lista no trae. Va por `iid` (el número
  /// visible, !450), no por el `id` global de la lista.
  Future<MergeRequestDetail> mergeRequestDetail({
    required int projectId,
    required int iid,
  }) => _client.getOne(
    '/projects/$projectId/merge_requests/$iid',
    parse: MergeRequestDetail.fromJson,
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
