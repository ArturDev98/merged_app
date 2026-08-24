import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/merge_request_summary.dart';
import 'package:merged_app/shared/merge_request_labels.dart';

MergeRequestSummary _mr({String state = 'opened', bool draft = false}) =>
    MergeRequestSummary.fromJson({
      'id': 1,
      'iid': 1,
      'project_id': 7,
      'title': 'x',
      'state': state,
      'draft': draft,
      'source_branch': 'a',
      'target_branch': 'b',
      'user_notes_count': 0,
    });

void main() {
  group('scopes y estados', () {
    test('los scopes usan los valores que espera la API', () {
      expect(MrScope.created.apiValue, 'created_by_me');
      expect(MrScope.assigned.apiValue, 'assigned_to_me');
      expect(MrScope.reviewing.apiValue, 'reviews_for_me');
    });

    test('cada scope explica su propio vacío', () {
      final mensajes = MrScope.values.map((s) => s.emptyMessage).toSet();
      expect(mensajes, hasLength(MrScope.values.length));
    });

    test('los estados coinciden con el parámetro de GitLab', () {
      expect(MrState.opened.apiValue, 'opened');
      expect(MrState.merged.apiValue, 'merged');
      expect(MrState.all.apiValue, 'all');
    });
  });

  group('etiquetas', () {
    test('un borrador se distingue de un abierto normal', () {
      expect(mrStateLabel(_mr(draft: true)), 'Borrador');
      expect(mrStateLabel(_mr()), 'Abierto');
      expect(mrStateLabel(_mr(state: 'merged')), 'Fusionado');
    });

    test('un estado de pipeline desconocido se muestra, no se oculta', () {
      expect(pipelineLabel('success'), 'Pipeline correcto');
      // Lo importante: no cae en un genérico que borre la información.
      expect(pipelineLabel('un_estado_nuevo'), contains('un_estado_nuevo'));
    });

    test('solo se traducen los diagnósticos de fusión accionables', () {
      expect(mergeStatusLabel('conflict'), 'Tiene conflictos');
      expect(mergeStatusLabel('not_approved'), 'Faltan aprobaciones');
      // "checking" es ruido interno: mejor no mostrar nada.
      expect(mergeStatusLabel('checking'), isNull);
      expect(mergeStatusLabel(null), isNull);
    });
  });
}
