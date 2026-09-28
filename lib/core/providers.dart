import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/gitlab_client.dart';
import 'auth/auth_service.dart';
import 'data/gitlab_repository.dart';
import 'data/open_merge_requests.dart';
import 'data/pending_work.dart';
import 'models/gitlab_project.dart';
import 'models/gitlab_user.dart';
import 'models/merge_request_approvals.dart';
import 'models/merge_request_detail.dart';
import 'models/merge_request_summary.dart';
import 'models/activity_event.dart';
import 'models/file_diff.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService.instance,
);

/// Se rehace al entrar o salir: nada cargado (o fallado) con una sesión pasa a
/// la siguiente, porque todo lo que depende de él se vuelve a pedir.
final gitlabRepositoryProvider = Provider<GitlabRepository>((ref) {
  ref.watch(sessionProvider.select((session) => session.valueOrNull));
  return GitlabRepository();
});

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

/// Índice de proyectos por id: los eventos solo traen `project_id` y sin
/// esto el feed no sabe a qué proyecto pertenece cada push.
final projectsByIdProvider = Provider<Map<int, GitlabProject>>((ref) {
  final projects = ref.watch(projectsProvider).valueOrNull ?? const [];
  return {for (final project in projects) project.id: project};
});

/// Lo que espera al usuario, ya deduplicado. Alimenta la campana.
final pendingWorkProvider = FutureProvider<List<PendingItem>>((ref) async {
  // Se lanzan las tres a la vez y se esperan después: son independientes.
  final todos = ref.watch(gitlabRepositoryProvider).pendingTodos();
  final reviewing = ref.watch(
    openMergeRequestsByScopeProvider('reviews_for_me').future,
  );
  final assigned = ref.watch(
    openMergeRequestsByScopeProvider('assigned_to_me').future,
  );

  return mergePendingWork(
    todos: await todos,
    reviewing: (await reviewing).items,
    assigned: (await assigned).items,
  );
});

/// MRs abiertos de un scope. La campana y el acceso de la home comparten estas
/// descargas en vez de repetirlas.
final openMergeRequestsByScopeProvider =
    FutureProvider.family<Page<MergeRequestSummary>, String>(
      (ref, scope) =>
          ref.watch(gitlabRepositoryProvider).mergeRequests(scope: scope),
    );

final openMergeRequestsProvider = FutureProvider<OpenMergeRequests>((
  ref,
) async {
  final pages = await Future.wait([
    for (final scope in mrScopes)
      ref.watch(openMergeRequestsByScopeProvider(scope).future),
  ]);
  return OpenMergeRequests({
    for (final (i, scope) in mrScopes.indexed) scope: pages[i],
  });
});

/// Ventana de actividad para los contadores del resumen.
const activityWindow = Duration(days: 30);

class ActivitySummary {
  const ActivitySummary({
    required this.pushes,
    required this.commits,
    required this.branchesCreated,
    required this.projectsTouched,
    required this.activeDays,
  });

  final int pushes;
  final int commits;
  final int branchesCreated;
  final int projectsTouched;

  /// Días con algún evento, no solo pushes.
  final int activeDays;
}

/// Eventos de la ventana reciente. Uno solo para resumen y ramas: comparten
/// la descarga en vez de pedir lo mismo dos veces.
final recentEventsProvider = FutureProvider<List<ActivityEvent>>((ref) {
  final since = DateTime.now().subtract(activityWindow);
  return ref.watch(gitlabRepositoryProvider).eventsSince(since);
});

/// Ramas creadas, sin llamada extra: una rama nueva es un push con
/// `action == created` y `ref_type == branch`.
final createdBranchesProvider = FutureProvider<List<ActivityEvent>>((
  ref,
) async {
  final events = await ref.watch(recentEventsProvider.future);
  return events
      .where((e) => e.pushData?.createsBranch ?? false)
      .toList(growable: false);
});

final activitySummaryProvider = FutureProvider<ActivitySummary>((ref) async {
  final events = await ref.watch(recentEventsProvider.future);

  var pushes = 0;
  var commits = 0;
  var branches = 0;
  final projects = <int>{};
  final days = <DateTime>{};

  for (final event in events) {
    final local = event.createdAt.toLocal();
    days.add(DateTime(local.year, local.month, local.day));
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
    activeDays: days.length,
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
  Future<ActivityFeedState> build() {
    ref.watch(gitlabRepositoryProvider);
    return _fetch(1);
  }

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

/// Commits y archivos de un push, vía compare. Solo al abrir el detalle.
final pushChangesProvider = FutureProvider.family<Comparison, PushRef>(
  (ref, push) => ref
      .watch(gitlabRepositoryProvider)
      .compare(projectId: push.projectId, from: push.from, to: push.to),
);

/// Identifica un commit dentro de su proyecto.
typedef CommitRef = ({int projectId, String sha});

final commitDiffProvider = FutureProvider.family<Page<FileDiff>, CommitRef>(
  (ref, commit) => ref
      .watch(gitlabRepositoryProvider)
      .commitDiff(projectId: commit.projectId, sha: commit.sha),
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
  Future<MergeRequestListState> build(MrQuery arg) {
    ref.watch(gitlabRepositoryProvider);
    return _fetch(1);
  }

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

final mergeRequestApprovalsProvider =
    FutureProvider.family<MergeRequestApprovals, MrRef>(
      (ref, mr) => ref
          .watch(gitlabRepositoryProvider)
          .approvals(projectId: mr.projectId, iid: mr.iid),
    );

/// Primera página de archivos cambiados de un MR. Solo se pide si son pocos:
/// con muchos, el detalle manda a GitLab en vez de descargarlos.
final mergeRequestDiffsProvider = FutureProvider.family<Page<FileDiff>, MrRef>(
  (ref, mr) => ref
      .watch(gitlabRepositoryProvider)
      .mergeRequestDiffs(projectId: mr.projectId, iid: mr.iid),
);

/// True si una consulta falla por sesión revocada. El interceptor borra los
/// tokens, pero sin esto el gate no volvería al login.
final sessionExpiredProvider = Provider<bool>((ref) {
  bool expired(AsyncValue<Object?> value) =>
      value.hasError && isSessionExpired(value.error);

  return expired(ref.watch(currentUserProvider)) ||
      expired(ref.watch(activityFeedProvider)) ||
      expired(ref.watch(projectsProvider));
});
