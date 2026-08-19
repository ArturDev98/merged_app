import 'package:flutter/foundation.dart';

import 'gitlab_client.dart';

/// Diagnóstico temporal de la Fase 1.
///
/// Objetivo: confirmar contra la cuenta real que los scopes `read_api` +
/// `read_user` alcanzan para todo lo que la home necesita, y medir el volumen
/// y el solapamiento antes de construir UI encima. Se borra cuando la Fase 2
/// esté hecha.
Future<String> runApiSmokeTest() async {
  final report = StringBuffer();
  final client = GitlabClient.instance;

  void line(String text) {
    report.writeln(text);
    debugPrint('[smoke] $text');
  }

  /// Ejecuta un paso aislando su fallo: si un endpoint no está permitido por
  /// los scopes, queremos ver el resto del informe igualmente.
  Future<T?> step<T>(String label, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      line('$label -> FALLO: $e');
      return null;
    }
  }

  line('--- Smoke test API GitLab ---');

  await step('GET /user', () async {
    final user = await client.getOne(
      '/user',
      parse: (json) => json,
    );
    line('GET /user -> @${user['username']} (id ${user['id']}, '
        '${user['name']})');
    return user;
  });

  final todos = await step('GET /todos', () async {
    final page = await client.getPage(
      '/todos',
      query: {'state': 'pending'},
      perPage: 100,
      parse: (json) => json,
    );
    line('GET /todos -> ${page.items.length} en esta página, '
        'total=${page.total ?? "(sin cabecera x-total)"}, '
        'siguiente=${page.nextPage ?? "-"}');

    final byAction = <String, int>{};
    final byType = <String, int>{};
    for (final t in page.items) {
      byAction[t['action_name'] as String? ?? '?'] =
          (byAction[t['action_name'] as String? ?? '?'] ?? 0) + 1;
      byType[t['target_type'] as String? ?? '?'] =
          (byType[t['target_type'] as String? ?? '?'] ?? 0) + 1;
    }
    line('  por action_name: $byAction');
    line('  por target_type: $byType');
    return page;
  });

  final mrsByScope = <String, List<Map<String, dynamic>>>{};
  for (final scope in ['reviews_for_me', 'assigned_to_me', 'created_by_me']) {
    await step('GET /merge_requests?scope=$scope', () async {
      final page = await client.getPage(
        '/merge_requests',
        query: {'scope': scope, 'state': 'opened'},
        perPage: 100,
        parse: (json) => json,
      );
      mrsByScope[scope] = page.items.cast<Map<String, dynamic>>();
      line('GET /merge_requests?scope=$scope -> ${page.items.length}, '
          'total=${page.total ?? "-"}, siguiente=${page.nextPage ?? "-"}');
      return page;
    });
  }

  await step('GET /events?action=pushed', () async {
    final page = await client.getPage(
      '/events',
      query: {'action': 'pushed'},
      perPage: 20,
      parse: (json) => json,
    );
    line('GET /events?action=pushed -> ${page.items.length}');
    final degraded = page.items
        .where((e) => (e['push_data']?['commit_count'] as int? ?? 0) == 0)
        .length;
    line('  eventos degradados (commit_count=0): $degraded '
        'de ${page.items.length}');
    if (page.items.isNotEmpty) {
      final first = page.items.first;
      line('  ejemplo: ${first['push_data']?['ref']} — '
          '${first['push_data']?['commit_title']}');
    }
    return page;
  });

  // La pregunta que decide el diseño de la home: ¿cuánto se solapan los todos
  // de tipo aprobación con los MRs donde soy reviewer? Si el solapamiento es
  // alto, deduplicar no es opcional.
  final todoMrUrls = <String>{};
  for (final t in todos?.items ?? const []) {
    if (t['target_type'] == 'MergeRequest' && t['target_url'] != null) {
      todoMrUrls.add((t['target_url'] as String).split('#').first);
    }
  }
  final reviewUrls = (mrsByScope['reviews_for_me'] ?? const [])
      .map((mr) => mr['web_url'] as String?)
      .whereType<String>()
      .toSet();
  final overlap = todoMrUrls.intersection(reviewUrls);
  line('SOLAPAMIENTO todos(MergeRequest)=${todoMrUrls.length} vs '
      'reviews_for_me=${reviewUrls.length} -> ${overlap.length} repetidos');

  line('--- fin ---');
  return report.toString();
}
