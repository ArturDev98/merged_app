import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/activity_event.dart';

ActivityEvent _event(Map<String, dynamic> pushData) => ActivityEvent.fromJson({
  'id': 1,
  'project_id': 7,
  'action_name': pushData['action'] == 'created' ? 'pushed new' : 'pushed to',
  'created_at': '2026-08-18T10:00:00.000Z',
  'push_data': pushData,
});

void main() {
  group('PushData', () {
    test('una rama recién creada llega sin commit_from', () {
      // Este es el caso real que dejaba un tercio del feed sin detalle:
      // GitLab no manda commit_from porque antes del push no había nada.
      final push = _event({
        'action': 'created',
        'ref_type': 'branch',
        'ref': 'feature/cupones',
        'commit_count': 3,
        'commit_from': null,
        'commit_to': 'abc123',
        'commit_title': 'fix: algo',
      }).pushData!;

      expect(push.createsBranch, isTrue);
      expect(push.isDegraded, isFalse);
      // Hay destino, así que se puede comparar…
      expect(push.hasTarget, isTrue);
      // …pero hace falta suplir la base con la rama por defecto.
      expect(push.needsBaseFallback, isTrue);
    });

    test('un push normal trae los dos extremos', () {
      final push = _event({
        'action': 'pushed',
        'ref_type': 'branch',
        'ref': 'main',
        'commit_count': 2,
        'commit_from': 'aaa',
        'commit_to': 'bbb',
      }).pushData!;

      expect(push.hasTarget, isTrue);
      expect(push.needsBaseFallback, isFalse);
      expect(push.createsBranch, isFalse);
    });

    test('un push recortado por GitLab no se puede expandir', () {
      // commit_count 0 es como GitLab entrega los pushes que superan su
      // límite de actividad.
      final push = _event({
        'action': 'pushed',
        'ref_type': 'branch',
        'ref': 'main',
        'commit_count': 0,
        'commit_from': null,
        'commit_to': null,
      }).pushData!;

      expect(push.isDegraded, isTrue);
      expect(push.hasTarget, isFalse);
      expect(push.needsBaseFallback, isFalse);
    });

    test('un evento sin push_data no es push', () {
      final event = ActivityEvent.fromJson({
        'id': 2,
        'project_id': 7,
        'action_name': 'opened',
        'created_at': '2026-08-18T10:00:00.000Z',
        'target_title': 'Un MR',
        'target_type': 'MergeRequest',
      });

      expect(event.isPush, isFalse);
      expect(event.targetTitle, 'Un MR');
    });
  });
}
