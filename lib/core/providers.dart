import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'data/gitlab_repository.dart';
import 'data/pending_work.dart';
import 'models/gitlab_project.dart';
import 'models/gitlab_user.dart';
import 'models/merge_request_detail.dart';
import 'models/merge_request_summary.dart';
import 'models/activity_event.dart';
import 'models/repo_commit.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService.instance,
);

final gitlabRepositoryProvider = Provider<GitlabRepository>(
  (ref) => GitlabRepository(),
);

/// Si hay sesión utilizable. Refrescar este provider es lo que hace que la app
/// pase de login a home y viceversa.
final sessionProvider = FutureProvider<bool>(
  (ref) => ref.watch(authServiceProvider).isLoggedIn(),
);

final currentUserProvider = FutureProvider<GitlabUser>(
  (ref) => ref.watch(gitlabRepositoryProvider).currentUser(),
);

final projectsProvider = FutureProvider<List<GitlabProject>>(
  (ref) => ref.watch(gitlabRepositoryProvider).memberProjects(),
);

/// Índice de proyectos por id.
///
/// Los eventos solo traen `project_id`, así que sin este mapa el feed no puede
/// decir a qué proyecto pertenece cada push.
final projectsByIdProvider = Provider<Map<int, GitlabProject>>((ref) {
  final projects = ref.watch(projectsProvider).valueOrNull ?? const [];
  return {for (final project in projects) project.id: project};
});

/// Lo que espera al usuario, ya deduplicado. Alimenta la campana.
final pendingWorkProvider = FutureProvider<List<PendingItem>>((ref) async {
  final repo = ref.watch(gitlabRepositoryProvider);
  // Se lanzan las tres a la vez y se esperan después: son independientes.
  final todos = repo.pendingTodos();
  final reviewing = repo.mergeRequests(scope: 'reviews_for_me');
  final assigned = repo.mergeRequests(scope: 'assigned_to_me');

  return mergePendingWork(
    todos: await todos,
    reviewing: (await reviewing).items,
    assigned: (await assigned).items,
  );
});

/// Los MRs propios abiertos. Deliberadamente fuera de la campana: son trabajo
/// en curso, no algo que bloquee al usuario.
final myOpenMergeRequestsProvider = FutureProvider<List<MergeRequestSummary>>((
  ref,
) async {
  final page = await ref
      .watch(gitlabRepositoryProvider)
      .mergeRequests(scope: 'created_by_me');
  return page.items;
});

/// Ventana de actividad para los contadores del resumen.
const activityWindow = Duration(days: 30);

class ActivitySummary {
  const ActivitySummary({
    required this.pushes,
    required this.commits,
    required this.branchesCreated,
    required this.projectsTouched,
  });

  final int pushes;
  final int commits;
  final int branchesCreated;
  final int projectsTouched;
}

final activitySummaryProvider = FutureProvider<ActivitySummary>((ref) async {
  final since = DateTime.now().subtract(activityWindow);
  final events = await ref.watch(gitlabRepositoryProvider).eventsSince(since);

  var pushes = 0;
  var commits = 0;
  var branches = 0;
  final projects = <int>{};

  for (final event in events) {
    final push = event.pushData;
    if (push == null) continue;
    pushes++;
    commits += push.commitCount;
    if (push.createsBranch) branches++;
    projects.add(event.projectId);
  }

  return ActivitySummary(
    pushes: pushes,
    commits: commits,
    branchesCreated: branches,
    projectsTouched: projects.length,
  );
});

/// Estado del feed paginado.
class ActivityFeedState {
  const ActivityFeedState({
    required this.events,
    this.nextPage,
    this.loadingMore = false,
  });

  final List<ActivityEvent> events;
  final int? nextPage;
  final bool loadingMore;

  bool get hasMore => nextPage != null;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    int? nextPage,
    bool clearNextPage = false,
    bool? loadingMore,
  }) => ActivityFeedState(
    events: events ?? this.events,
    nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Feed de actividad con scroll infinito.
class ActivityFeed extends AsyncNotifier<ActivityFeedState> {
  @override
  Future<ActivityFeedState> build() => _fetch(1);

  Future<ActivityFeedState> _fetch(int page) async {
    final result = await ref.read(gitlabRepositoryProvider).events(page: page);
    return ActivityFeedState(events: result.items, nextPage: result.nextPage);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final result = await ref
          .read(gitlabRepositoryProvider)
          .events(page: current.nextPage!);
      state = AsyncData(
        ActivityFeedState(
          events: [...current.events, ...result.items],
          nextPage: result.nextPage,
        ),
      );
    } catch (_) {
      // Un fallo al paginar no debe tirar lo ya cargado: se deja el feed como
      // estaba y el usuario puede reintentar desplazándose otra vez.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(1));
  }
}

final activityFeedProvider =
    AsyncNotifierProvider<ActivityFeed, ActivityFeedState>(ActivityFeed.new);

/// Identifica un push. Es un record, así que la igualdad es estructural y la
/// family de Riverpod cachea bien sin escribir == ni hashCode.
typedef PushRef = ({int projectId, String from, String to});

/// Commits reales de un push, vía compare. Solo se pide al abrir el detalle.
final pushCommitsProvider = FutureProvider.family<List<RepoCommit>, PushRef>(
  (ref, push) => ref
      .watch(gitlabRepositoryProvider)
      .commitsForPush(projectId: push.projectId, from: push.from, to: push.to),
);

/// Consulta de una lista de merge requests. Record: igualdad estructural, así
/// que la family cachea por (scope, estado) sin escribir == ni hashCode.
typedef MrQuery = ({String scope, String state});

class MergeRequestListState {
  const MergeRequestListState({
    required this.items,
    this.nextPage,
    this.loadingMore = false,
    this.total,
  });

  final List<MergeRequestSummary> items;
  final int? nextPage;
  final bool loadingMore;
  final int? total;

  bool get hasMore => nextPage != null;

  MergeRequestListState copyWith({bool? loadingMore}) => MergeRequestListState(
    items: items,
    nextPage: nextPage,
    loadingMore: loadingMore ?? this.loadingMore,
    total: total,
  );
}

/// Lista paginada de merge requests para un scope y estado dados.
class MergeRequestList
    extends FamilyAsyncNotifier<MergeRequestListState, MrQuery> {
  @override
  Future<MergeRequestListState> build(MrQuery arg) => _fetch(1);

  Future<MergeRequestListState> _fetch(int page) async {
    final result = await ref
        .read(gitlabRepositoryProvider)
        .mergeRequests(scope: arg.scope, state: arg.state, page: page);
    return MergeRequestListState(
      items: result.items,
      nextPage: result.nextPage,
      total: result.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final result = await ref
          .read(gitlabRepositoryProvider)
          .mergeRequests(
            scope: arg.scope,
            state: arg.state,
            page: current.nextPage!,
          );
      state = AsyncData(
        MergeRequestListState(
          items: [...current.items, ...result.items],
          nextPage: result.nextPage,
          total: result.total ?? current.total,
        ),
      );
    } catch (_) {
      // Un fallo al paginar no debe tirar lo ya cargado.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final mergeRequestListProvider =
    AsyncNotifierProvider.family<
      MergeRequestList,
      MergeRequestListState,
      MrQuery
    >(MergeRequestList.new);

/// Identifica un merge request dentro de su proyecto.
typedef MrRef = ({int projectId, int iid});

/// Detalle de un merge request. Es la única vía para conocer su pipeline: la
/// lista no incluye head_pipeline.
final mergeRequestDetailProvider =
    FutureProvider.family<MergeRequestDetail, MrRef>(
      (ref, mr) => ref
          .watch(gitlabRepositoryProvider)
          .mergeRequestDetail(projectId: mr.projectId, iid: mr.iid),
    );
