import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/merge_request_detail.dart';

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
  'id': 1,
  'iid': 450,
  'project_id': 7,
  'title': 'fix: algo',
  'state': 'opened',
  'draft': false,
  'source_branch': 'fix/x',
  'target_branch': 'main',
  'created_at': '2026-08-01T10:00:00.000Z',
  'updated_at': '2026-08-19T10:00:00.000Z',
  'user_notes_count': 3,
  'web_url': 'https://gitlab.com/g/p/-/merge_requests/450',
  ...extra,
};

void main() {
  group('MergeRequestDetail', () {
    test('lee el pipeline de head_pipeline', () {
      final detail = MergeRequestDetail.fromJson(
        _base({
          'head_pipeline': {
            'id': 99,
            'status': 'failed',
            'ref': 'fix/x',
            'web_url': 'https://gitlab.com/g/p/-/pipelines/99',
          },
        }),
      );

      expect(detail.headPipeline, isNotNull);
      expect(detail.headPipeline!.status, 'failed');
      expect(detail.summary.iid, 450);
    });

    test('cae a pipeline si la instancia no manda head_pipeline', () {
      final detail = MergeRequestDetail.fromJson(
        _base({
          'pipeline': {'id': 5, 'status': 'success'},
        }),
      );

      expect(detail.headPipeline?.status, 'success');
    });

    test('sin pipeline queda nulo, no en un estado inventado', () {
      // Es el caso real de la lista de MRs, que no incluye head_pipeline.
      final detail = MergeRequestDetail.fromJson(_base({}));

      expect(detail.headPipeline, isNull);
    });

    test('un estado de pipeline desconocido se conserva tal cual', () {
      final detail = MergeRequestDetail.fromJson(
        _base({
          'head_pipeline': {'id': 1, 'status': 'un_estado_nuevo'},
        }),
      );

      // No se normaliza a un enum cerrado: un estado que GitLab añada en el
      // futuro debe llegar visible a la UI y no perderse.
      expect(detail.headPipeline!.status, 'un_estado_nuevo');
    });
  });
}
