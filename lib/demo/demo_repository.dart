import '../core/api/gitlab_client.dart';
import '../core/data/gitlab_repository.dart';
import '../core/models/activity_event.dart';
import '../core/models/gitlab_project.dart';
import '../core/models/gitlab_user.dart';
import '../core/models/merge_request_approvals.dart';
import '../core/models/merge_request_detail.dart';
import '../core/models/merge_request_summary.dart';
import '../core/models/file_diff.dart';
import '../core/models/todo_item.dart';
import 'demo_data.dart';
import 'demo_diffs.dart';

/// Repositorio sin red: sirve los datos de `demo_data.dart` por los mismos
/// `fromJson` que usa la app real.
class DemoRepository extends GitlabRepository {
  // Latencia fingida para que se vean los estados de carga.
  static const _latency = Duration(milliseconds: 350);

  late final List<Map<String, dynamic>> _events = demoEvents();
  late final List<Map<String, dynamic>> _projects = demoProjects();

  // MRs aprobados por el usuario demo durante la sesión.
  final _approvedByMe = <int>{};

  Future<T> _later<T>(T Function() build) => Future.delayed(_latency, build);

  @override
  Future<GitlabUser> currentUser() => _later(() => GitlabUser.fromJson(demoMe));

  @override
  Future<List<GitlabProject>> memberProjects({int maxPages = 5}) =>
      _later(() => _projects.map(GitlabProject.fromJson).toList());

  @override
  Future<Page<ActivityEvent>> events({int page = 1, int perPage = 30}) =>
      _later(() {
        final start = (page - 1) * perPage;
        final raw = _events.skip(start).take(perPage).toList();
        return Page(
          items: raw.map(ActivityEvent.fromJson).toList(),
          raw: raw,
          nextPage: start + perPage < _events.length ? page + 1 : null,
        );
      });

  @override
  Future<List<ActivityEvent>> eventsSince(
    DateTime since, {
    int maxPages = 4,
    int perPage = 100,
  }) => _later(
    () => _events
        .map(ActivityEvent.fromJson)
        .where((e) => e.createdAt.isAfter(since))
        .toList(),
  );

  String _path(int projectId) =>
      _projects.firstWhere((p) => p['id'] == projectId)['name'] as String;

  @override
  Future<Comparison> compare({
    required int projectId,
    required String from,
    required String to,
  }) => _later(() {
    final push = demoPushesByCommit[to];
    if (push == null) return const Comparison(commits: [], files: []);
    final path = _path(projectId);
    return Comparison.fromJson({
      'commits': demoCommits(push, path),
      'diffs': demoPushDiffs(push, path),
      'compare_timeout': false,
    });
  });

  @override
  Future<Page<FileDiff>> commitDiff({
    required int projectId,
    required String sha,
  }) => _later(() {
    final raw = demoCommitDiffs(sha, _path(projectId));
    return Page(items: raw.map(FileDiff.fromJson).toList(), raw: raw);
  });

  @override
  Future<Page<FileDiff>> mergeRequestDiffs({
    required int projectId,
    required int iid,
  }) => _later(() {
    final mr = demoMergeRequests().values
        .expand((list) => list)
        .firstWhere((mr) => mr['project_id'] == projectId && mr['iid'] == iid);
    final changes = int.tryParse(
      demoMergeRequestExtras()[mr['id']]?['changes_count'] as String? ?? '',
    );
    final raw = demoMergeRequestDiffs(mr, _path(projectId), changes ?? 0);
    return Page(items: raw.map(FileDiff.fromJson).toList(), raw: raw);
  });

  @override
  Future<Page<MergeRequestSummary>> mergeRequests({
    required String scope,
    String state = 'opened',
    int page = 1,
    int perPage = 30,
  }) => _later(() {
    final raw = (demoMergeRequests()[scope] ?? const [])
        .where((mr) => state == 'all' || mr['state'] == state)
        .toList();
    return Page(
      items: raw.map(MergeRequestSummary.fromJson).toList(),
      raw: raw,
      total: raw.length,
    );
  });

  @override
  Future<MergeRequestDetail> mergeRequestDetail({
    required int projectId,
    required int iid,
  }) => _later(() {
    final mr = demoMergeRequests().values
        .expand((list) => list)
        .firstWhere((mr) => mr['project_id'] == projectId && mr['iid'] == iid);
    final extra = demoMergeRequestExtras()[mr['id']] ?? const {};
    return MergeRequestDetail.fromJson({...mr, ...extra});
  });

  int _mrId(int projectId, int iid) =>
      demoMergeRequests().values
              .expand((list) => list)
              .firstWhere(
                (mr) => mr['project_id'] == projectId && mr['iid'] == iid,
              )['id']
          as int;

  MergeRequestApprovals _approvalsOf(int id) {
    final by = [
      ...?demoApprovers()[id],
      if (_approvedByMe.contains(id)) demoMe,
    ];
    return MergeRequestApprovals.fromJson({
      'approved': by.isNotEmpty,
      'approved_by': [
        for (final user in by) {'user': user},
      ],
      'user_can_approve': true,
    });
  }

  @override
  Future<MergeRequestApprovals> approvals({
    required int projectId,
    required int iid,
  }) => _later(() => _approvalsOf(_mrId(projectId, iid)));

  @override
  Future<MergeRequestApprovals> approve({
    required int projectId,
    required int iid,
    String? sha,
  }) => _later(() {
    final id = _mrId(projectId, iid);
    _approvedByMe.add(id);
    return _approvalsOf(id);
  });

  @override
  Future<void> unapprove({required int projectId, required int iid}) =>
      _later(() => _approvedByMe.remove(_mrId(projectId, iid)));

  @override
  Future<List<TodoItem>> pendingTodos({int perPage = 100}) =>
      _later(() => demoTodos().map(TodoItem.fromJson).toList());
}
