import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/activity_event.dart';
import 'package:merged_app/shared/activity_labels.dart';

ActivityEvent _event(Map<String, dynamic> extra) => ActivityEvent.fromJson({
  'id': 1,
  'project_id': 7,
  'created_at': '2026-08-19T10:00:00.000Z',
  ...extra,
});

void main() {
  group('describeActivity', () {
    test('un alta en proyecto dice qué pasó', () {
      // Este era el caso roto: la fila mostraba el nombre del proyecto en el
      // título y otra vez en el subtítulo, sin explicar nada.
      final event = _event({
        'action_name': 'joined',
        'target_title': 'personas-front',
      });

      expect(describeActivity(event), 'Te uniste al proyecto');
    });

    test('distingue crear rama de hacer push', () {
      final creado = _event({
        'action_name': 'pushed new',
        'push_data': {
          'action': 'created',
          'ref_type': 'branch',
          'ref': 'fix/x',
          'commit_count': 1,
          'commit_to': 'abc',
        },
      });
      final empujado = _event({
        'action_name': 'pushed to',
        'push_data': {
          'action': 'pushed',
          'ref_type': 'branch',
          'ref': 'main',
          'commit_count': 2,
          'commit_from': 'a',
          'commit_to': 'b',
        },
      });

      expect(describeActivity(creado), 'Creaste la rama');
      expect(describeActivity(empujado), 'Hiciste push');
    });

    test('nombra el tipo de objeto al abrirlo', () {
      final event = _event({
        'action_name': 'opened',
        'target_type': 'MergeRequest',
        'target_title': 'Un MR',
      });

      expect(describeActivity(event), 'Abriste un merge request');
    });

    test('una acción desconocida no se inventa nada', () {
      final event = _event({'action_name': 'destroyed'});

      expect(describeActivity(event), 'destroyed');
    });
  });

  group('activityIcon', () {
    test('cada tipo de evento tiene su propio icono', () {
      final joined = _event({'action_name': 'joined'});
      final opened = _event({'action_name': 'opened'});
      final rama = _event({
        'action_name': 'pushed new',
        'push_data': {
          'action': 'created',
          'ref_type': 'branch',
          'ref': 'x',
          'commit_count': 1,
          'commit_to': 'abc',
        },
      });

      expect(activityIcon(joined), isNot(activityIcon(opened)));
      expect(activityIcon(rama), isNot(activityIcon(joined)));
    });
  });
}
