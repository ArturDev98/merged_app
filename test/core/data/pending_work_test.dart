import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/data/pending_work.dart';
import 'package:merged_app/core/models/merge_request_summary.dart';
import 'package:merged_app/core/models/todo_item.dart';

const _mrUrl = 'https://gitlab.com/grupo/proyecto/-/merge_requests/12';

TodoItem _todo({
  required int id,
  required String action,
  String? targetUrl,
  String body = 'Un MR',
}) => TodoItem.fromJson({
  'id': id,
  'action_name': action,
  'target_type': 'MergeRequest',
  'body': body,
  'created_at': '2026-08-18T10:00:00.000Z',
  'target_url': targetUrl,
});

MergeRequestSummary _mr({
  required int id,
  required String webUrl,
  String title = 'Un MR',
  String updatedAt = '2026-08-18T09:00:00.000Z',
}) => MergeRequestSummary.fromJson({
  'id': id,
  'iid': id,
  'project_id': 1,
  'title': title,
  'state': 'opened',
  'draft': false,
  'source_branch': 'feat/x',
  'target_branch': 'main',
  'created_at': '2026-08-01T10:00:00.000Z',
  'updated_at': updatedAt,
  'user_notes_count': 0,
  'web_url': webUrl,
});

void main() {
  group('normalizeGitlabUrl', () {
    test('quita el ancla del comentario', () {
      expect(normalizeGitlabUrl('$_mrUrl#note_99'), _mrUrl);
    });

    test('quita la query y la barra final', () {
      expect(normalizeGitlabUrl('$_mrUrl/?foo=1'), _mrUrl);
    });

    test('devuelve null para vacío o nulo', () {
      expect(normalizeGitlabUrl(null), isNull);
      expect(normalizeGitlabUrl(''), isNull);
    });
  });

  group('mergePendingWork', () {
    test('no repite un MR que llega como todo y como revisión', () {
      final result = mergePendingWork(
        todos: [
          _todo(
            id: 1,
            action: 'approval_required',
            targetUrl: '$_mrUrl#note_5',
          ),
        ],
        reviewing: [_mr(id: 12, webUrl: _mrUrl)],
        assigned: const [],
      );

      expect(result, hasLength(1));
      // Gana el todo: es el único que sabe por qué está pendiente.
      expect(result.single.kind, PendingKind.todo);
      expect(result.single.reason, 'Requiere tu aprobación');
    });

    test('un MR que es a la vez revisión y asignación cuenta una sola vez', () {
      final result = mergePendingWork(
        todos: const [],
        reviewing: [_mr(id: 12, webUrl: _mrUrl)],
        assigned: [_mr(id: 12, webUrl: _mrUrl)],
      );

      expect(result, hasLength(1));
      expect(result.single.kind, PendingKind.reviewRequest);
    });

    test('conserva los elementos distintos', () {
      final result = mergePendingWork(
        todos: [_todo(id: 1, action: 'mentioned', targetUrl: '$_mrUrl#note_1')],
        reviewing: [
          _mr(id: 99, webUrl: 'https://gitlab.com/g/p/-/merge_requests/99'),
        ],
        assigned: const [],
      );

      expect(result, hasLength(2));
    });

    test('un todo sin URL no colisiona con otro sin URL', () {
      final result = mergePendingWork(
        todos: [
          _todo(id: 1, action: 'mentioned', body: 'A'),
          _todo(id: 2, action: 'mentioned', body: 'B'),
        ],
        reviewing: const [],
        assigned: const [],
      );

      expect(result, hasLength(2));
    });

    test('ordena por fecha, lo más reciente primero', () {
      final result = mergePendingWork(
        todos: const [],
        reviewing: [
          _mr(
            id: 1,
            webUrl: 'https://gitlab.com/g/p/-/merge_requests/1',
            updatedAt: '2026-08-10T09:00:00.000Z',
          ),
          _mr(
            id: 2,
            webUrl: 'https://gitlab.com/g/p/-/merge_requests/2',
            updatedAt: '2026-08-18T09:00:00.000Z',
          ),
        ],
        assigned: const [],
      );

      expect(result.map((e) => e.title).first, 'Un MR');
      expect(result.first.at!.isAfter(result.last.at!), isTrue);
    });

    test('sin nada pendiente devuelve lista vacía', () {
      expect(
        mergePendingWork(
          todos: const [],
          reviewing: const [],
          assigned: const [],
        ),
        isEmpty,
      );
    });
  });
}
