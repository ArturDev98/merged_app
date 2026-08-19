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
    final user = await client.getOne('/user', parse: (json) => json);
    line(
      'GET /user -> @${user['username']} (id ${user['id']}, '
      '${user['name']})',
    );
    return user;
  });

  final todos = await step('GET /todos', () async {
    final page = await client.getPage(
      '/todos',
      query: {'state': 'pending'},
      perPage: 100,
      parse: (json) => json,
    );
    line(
      'GET /todos -> ${page.items.length} en esta página, '
      'total=${page.total ?? "(sin cabecera x-total)"}, '
      'siguiente=${page.nextPage ?? "-"}',
    );

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
      line(
        'GET /merge_requests?scope=$scope -> ${page.items.length}, '
        'total=${page.total ?? "-"}, siguiente=${page.nextPage ?? "-"}',
      );
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
    line(
      '  eventos degradados (commit_count=0): $degraded '
      'de ${page.items.length}',
    );
    if (page.items.isNotEmpty) {
      final first = page.items.first;
      line(
        '  ejemplo: ${first['push_data']?['ref']} — '
        '${first['push_data']?['commit_title']}',
      );
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
  line(
    'SOLAPAMIENTO todos(MergeRequest)=${todoMrUrls.length} vs '
    'reviews_for_me=${reviewUrls.length} -> ${overlap.length} repetidos',
  );

  // Segunda tanda: la primera salió vacía en todos y MRs mientras /events venía
  // lleno. Antes de rediseñar la home hay que saber si esta cuenta simplemente
  // no tiene nada abierto hoy, o si directamente no usa merge requests.
  line('--- ¿qué contiene realmente esta cuenta? ---');

  await step('GET /projects?membership=true', () async {
    final page = await client.getPage(
      '/projects',
      query: {'membership': true, 'simple': true},
      perPage: 1,
      parse: (json) => json,
    );
    line('proyectos donde soy miembro -> ${page.total ?? "(sin x-total)"}');
    return page;
  });

  for (final scope in ['created_by_me', 'assigned_to_me', 'reviews_for_me']) {
    await step('GET /merge_requests?scope=$scope&state=all', () async {
      final page = await client.getPage(
        '/merge_requests',
        query: {'scope': scope, 'state': 'all'},
        perPage: 1,
        parse: (json) => json,
      );
      line(
        'MRs históricos ($scope, cualquier estado) -> '
        '${page.total ?? "(sin x-total)"}',
      );
      return page;
    });
  }

  await step('GET /todos?state=all', () async {
    final page = await client.getPage(
      '/todos',
      query: {'state': 'all'},
      perPage: 1,
      parse: (json) => json,
    );
    line(
      'todos históricos (pending + done) -> '
      '${page.total ?? "(sin x-total)"}',
    );
    return page;
  });

  // Sin filtro de acción: dice de qué está hecha su actividad real, que es
  // la única fuente que sí trae datos.
  await step('GET /events (sin filtro)', () async {
    final page = await client.getPage(
      '/events',
      perPage: 100,
      parse: (json) => json,
    );
    final byAction = <String, int>{};
    final byTarget = <String, int>{};
    for (final e in page.items) {
      final a = e['action_name'] as String? ?? '?';
      byAction[a] = (byAction[a] ?? 0) + 1;
      final t = e['target_type'] as String? ?? '(sin target)';
      byTarget[t] = (byTarget[t] ?? 0) + 1;
    }
    line(
      'eventos recientes -> ${page.items.length} '
      '(siguiente=${page.nextPage ?? "-"})',
    );
    line('  por action_name: $byAction');
    line('  por target_type: $byTarget');
    if (page.items.isNotEmpty) {
      line('  más reciente: ${page.items.first['created_at']}');
      line('  más antiguo en esta página: ${page.items.last['created_at']}');
    }
    return page;
  });

  // Claves reales de cada payload, para modelar sobre lo que devuelve la API
  // y no sobre lo que promete la documentación.
  line('--- forma de los payloads ---');

  void dumpKeys(String label, Map<String, dynamic> json) {
    final keys = json.keys.toList()..sort();
    line('$label: ${keys.join(", ")}');
  }

  await step('claves /user', () async {
    dumpKeys('user', await client.getOne('/user', parse: (j) => j));
    return true;
  });

  await step('claves /projects', () async {
    final page = await client.getPage(
      '/projects',
      query: {'membership': true},
      perPage: 1,
      parse: (json) => json,
    );
    if (page.items.isNotEmpty) dumpKeys('project', page.items.first);
    return true;
  });

  await step('claves /events', () async {
    final page = await client.getPage(
      '/events',
      query: {'action': 'pushed'},
      perPage: 1,
      parse: (json) => json,
    );
    if (page.items.isNotEmpty) {
      dumpKeys('event', page.items.first);
      final push = page.items.first['push_data'];
      if (push is Map<String, dynamic>) dumpKeys('  push_data', push);
      final author = page.items.first['author'];
      if (author is Map<String, dynamic>) dumpKeys('  author', author);
    }
    return true;
  });

  await step('claves /merge_requests', () async {
    final page = await client.getPage(
      '/merge_requests',
      query: {'scope': 'created_by_me', 'state': 'all'},
      perPage: 1,
      parse: (json) => json,
    );
    if (page.items.isNotEmpty) {
      dumpKeys('merge_request', page.items.first);
      final mr = page.items.first;
      line(
        '  muestra: !${mr['iid']} "${mr['title']}" '
        'state=${mr['state']} draft=${mr['draft']} '
        'pipeline=${mr['head_pipeline']?['status'] ?? "(sin head_pipeline)"}',
      );
    }
    return true;
  });

  line('--- fin ---');
  return report.toString();
}
