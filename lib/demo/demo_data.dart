// Datos ficticios con la forma de los payloads reales de la API de GitLab.
// Las fechas son relativas a ahora para que el feed siempre parezca reciente.

const _host = 'https://gitlab.com';
const _namespace = 'acme';

String _ago(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _user(int id, String username, String name) => {
  'id': id,
  'username': username,
  'name': name,
  'avatar_url': null,
  'web_url': '$_host/$username',
};

final demoMe = _user(1, 'lgomez', 'Laura Gómez');
final _carlos = _user(2, 'cruiz', 'Carlos Ruiz');
final _marta = _user(3, 'msalas', 'Marta Salas');
final _julian = _user(4, 'jperez', 'Julián Pérez');

String projectUrl(String path) => '$_host/$_namespace/$path';

Map<String, dynamic> _project(
  int id,
  String path,
  String description,
  Duration lastActivity, {
  String defaultBranch = 'main',
}) => {
  'id': id,
  'name': path,
  'name_with_namespace': 'Acme / $path',
  'path_with_namespace': '$_namespace/$path',
  'description': description,
  'avatar_url': null,
  'web_url': projectUrl(path),
  'default_branch': defaultBranch,
  'last_activity_at': _ago(lastActivity),
};

List<Map<String, dynamic>> demoProjects() => [
  _project(
    102,
    'api-pagos',
    'Pasarela de pagos y webhooks',
    const Duration(minutes: 25),
  ),
  _project(
    101,
    'tienda-web',
    'Catálogo, carrito y checkout',
    const Duration(hours: 5),
  ),
  _project(
    103,
    'app-movil',
    'App Flutter para clientes',
    const Duration(days: 1),
    defaultBranch: 'develop',
  ),
  _project(
    104,
    'infra-terraform',
    'Infraestructura como código',
    const Duration(days: 3),
  ),
  _project(105, 'docs', 'Documentación interna', const Duration(days: 5)),
  _project(
    106,
    'portal-proveedores',
    'Alta y gestión de proveedores',
    const Duration(days: 7),
  ),
  _project(
    107,
    'design-system',
    'Componentes y tokens de diseño',
    const Duration(days: 16),
  ),
  _project(
    108,
    'scripts-datos',
    'Cargas y limpiezas puntuales',
    const Duration(days: 40),
  ),
];

/// Un push, con lo necesario para generar después sus commits.
class DemoPush {
  const DemoPush(this.projectId, this.ref, this.commits, this.lastTitle);
  final int projectId;
  final String ref;
  final int commits;
  final String lastTitle;
}

final demoPushesByCommit = <String, DemoPush>{};

/// Qué push y qué posición tiene cada commit generado, para servir su diff.
final demoPushByCommitSha = <String, DemoPush>{};
final demoCommitIndex = <String, int>{};

var _nextEventId = 9000;

Map<String, dynamic> _push(
  Duration ago,
  int projectId,
  String ref,
  int commits,
  String title, {
  bool created = false,
}) {
  final id = _nextEventId++;
  final to = _sha(id);
  demoPushesByCommit[to] = DemoPush(projectId, ref, commits, title);
  return {
    'id': id,
    'project_id': projectId,
    'action_name': created ? 'pushed new' : 'pushed to',
    'created_at': _ago(ago),
    'author': demoMe,
    'push_data': {
      'action': created ? 'created' : 'pushed',
      'ref_type': 'branch',
      'ref': ref,
      'commit_count': commits,
      // Como en la API real, al crear una rama no hay commit base.
      'commit_from': created ? null : _sha(id + 5000),
      'commit_to': to,
      'commit_title': title,
    },
  };
}

Map<String, dynamic> _event(
  Duration ago,
  int projectId,
  String action, {
  String? title,
  String? type,
  int? iid,
}) => {
  'id': _nextEventId++,
  'project_id': projectId,
  'action_name': action,
  'created_at': _ago(ago),
  'author': demoMe,
  'target_title': title,
  'target_type': type,
  'target_iid': iid,
};

String _sha(int seed) {
  const hex = '0123456789abcdef';
  // Park-Miller: los productos caben en 2^53, así que también es exacto en web.
  var x = (seed * 7919) % 2147483647 + 1;
  return List.generate(40, (_) {
    x = (x * 48271) % 2147483647;
    return hex[x % 16];
  }).join();
}

List<Map<String, dynamic>> demoEvents() {
  _nextEventId = 9000;
  demoPushesByCommit.clear();
  const h = Duration(hours: 1);
  const d = Duration(days: 1);
  return [
    _push(
      const Duration(minutes: 25),
      102,
      'feature/reintentos-webhook',
      3,
      'Reintenta los webhooks fallidos con backoff exponencial',
    ),
    _event(
      h * 2,
      102,
      'opened',
      title: 'Reintentos de webhooks con backoff',
      type: 'MergeRequest',
      iid: 142,
    ),
    _push(
      h * 3,
      102,
      'feature/reintentos-webhook',
      1,
      'Añade la cola de reintentos',
      created: true,
    ),
    _push(h * 5, 101, 'main', 2, 'Corrige el cálculo del IVA en el carrito'),
    _event(
      d,
      101,
      'commented on',
      title: 'Migra el checkout a la nueva API',
      type: 'DiffNote',
    ),
    _push(
      d + h * 2,
      103,
      'develop',
      5,
      'Ajusta el tema oscuro de la pantalla de pedidos',
    ),
    _event(
      d * 2,
      101,
      'accepted',
      title: 'Actualiza dependencias de seguridad',
      type: 'MergeRequest',
      iid: 85,
    ),
    _push(
      d * 2 + h * 4,
      103,
      'fix/login-biometrico',
      2,
      'Pide la huella solo si el dispositivo la tiene',
      created: true,
    ),
    _push(d * 3, 104, 'main', 1, 'Sube la memoria del worker de colas a 1 GiB'),
    _push(d * 5, 105, 'main', 1, 'Documenta el flujo de reembolsos'),
    _event(
      d * 6,
      101,
      'opened',
      title: 'El export CSV corta los acentos',
      type: 'Issue',
      iid: 31,
    ),
    _event(d * 7, 106, 'joined', title: 'portal-proveedores'),
    _push(d * 8, 102, 'main', 4, 'Valida la firma de los webhooks entrantes'),
    _push(
      d * 9,
      101,
      'feature/cupones',
      1,
      'Modelo de cupones por categoría',
      created: true,
    ),
    _push(
      d * 10,
      101,
      'feature/cupones',
      6,
      'Aplica el cupón antes de calcular el envío',
    ),
    _event(
      d * 12,
      101,
      'closed',
      title: 'Prueba de concepto con GraphQL',
      type: 'MergeRequest',
      iid: 80,
    ),
    _push(
      d * 14,
      103,
      'develop',
      3,
      'Cachea el catálogo para abrir sin conexión',
    ),
    _push(
      d * 18,
      104,
      'feature/redis-cluster',
      2,
      'Módulo de Redis en modo clúster',
      created: true,
    ),
    _push(d * 21, 105, 'main', 1, 'Corrige enlaces rotos del índice'),
    _push(d * 26, 107, 'main', 2, 'Tokens de color para el tema oscuro'),
  ];
}

const _commitPool = [
  'Extrae la configuración a variables de entorno',
  'Añade tests del caso sin conexión',
  'Renombra el servicio para que diga lo que hace',
  'Quita un log que filtraba el token',
  'Ajusta los tiempos de espera del cliente HTTP',
];

List<Map<String, dynamic>> demoCommits(DemoPush push, String projectPath) =>
    List.generate(push.commits, (i) {
      // compare devuelve del más antiguo al más nuevo; el título del push es el último.
      final isLast = i == push.commits - 1;
      final sha = _sha(push.projectId * 100 + i + push.ref.length);
      demoPushByCommitSha[sha] = push;
      demoCommitIndex[sha] = i;
      return {
        'id': sha,
        'short_id': sha.substring(0, 8),
        'title': isLast ? push.lastTitle : _commitPool[i % _commitPool.length],
        'message': null,
        'author_name': demoMe['name'],
        'author_email': 'laura@acme.dev',
        'created_at': _ago(Duration(minutes: 25 + (push.commits - 1 - i) * 17)),
        'web_url': '${projectUrl(projectPath)}/-/commit/$sha',
      };
    });

Map<String, dynamic> _mr(
  int id,
  int iid,
  int projectId,
  String projectPath,
  String title, {
  required Map<String, dynamic> author,
  required String source,
  String target = 'main',
  String state = 'opened',
  bool draft = false,
  Duration created = const Duration(days: 2),
  Duration updated = const Duration(hours: 3),
  int notes = 0,
  bool conflicts = false,
}) => {
  'id': id,
  'iid': iid,
  'project_id': projectId,
  'title': title,
  'state': state,
  'draft': draft,
  'source_branch': source,
  'target_branch': target,
  'created_at': _ago(created),
  'updated_at': _ago(updated),
  'user_notes_count': notes,
  'author': author,
  'web_url': '${projectUrl(projectPath)}/-/merge_requests/$iid',
  'has_conflicts': conflicts,
  'merge_status': conflicts ? 'cannot_be_merged' : 'can_be_merged',
};

final _mr142 = _mr(
  5142,
  142,
  102,
  'api-pagos',
  'Reintentos de webhooks con backoff',
  author: demoMe,
  source: 'feature/reintentos-webhook',
  created: const Duration(hours: 2),
  updated: const Duration(minutes: 25),
  notes: 1,
);
final _mr88 = _mr(
  5088,
  88,
  101,
  'tienda-web',
  'Draft: Cupones por categoría',
  author: demoMe,
  source: 'feature/cupones',
  draft: true,
  created: const Duration(days: 9),
  updated: const Duration(days: 1),
);
final _mr57 = _mr(
  5057,
  57,
  103,
  'app-movil',
  'Login biométrico',
  author: demoMe,
  source: 'fix/login-biometrico',
  target: 'develop',
  created: const Duration(days: 2),
  updated: const Duration(hours: 20),
  notes: 4,
);
final _mr85 = _mr(
  5085,
  85,
  101,
  'tienda-web',
  'Actualiza dependencias de seguridad',
  author: demoMe,
  source: 'chore/deps',
  state: 'merged',
  created: const Duration(days: 4),
  updated: const Duration(days: 2),
  notes: 2,
);
final _mr80 = _mr(
  5080,
  80,
  101,
  'tienda-web',
  'Prueba de concepto con GraphQL',
  author: demoMe,
  source: 'spike/graphql',
  state: 'closed',
  created: const Duration(days: 20),
  updated: const Duration(days: 12),
  notes: 7,
);
final _mr87 = _mr(
  5087,
  87,
  101,
  'tienda-web',
  'Migra el checkout a la nueva API',
  author: _carlos,
  source: 'feature/checkout-v2',
  created: const Duration(days: 3),
  updated: const Duration(hours: 6),
  notes: 12,
);
final _mr23 = _mr(
  5023,
  23,
  104,
  'infra-terraform',
  'Clúster de Redis para sesiones',
  author: _marta,
  source: 'feature/redis-sesiones',
  created: const Duration(days: 5),
  updated: const Duration(days: 1),
  notes: 5,
);
final _mr12 = _mr(
  5012,
  12,
  106,
  'portal-proveedores',
  'Alta de proveedores con validación de NIT',
  author: _julian,
  source: 'feature/validar-nit',
  created: const Duration(days: 6),
  updated: const Duration(days: 2),
  notes: 3,
  conflicts: true,
);
final _mr84 = _mr(
  5084,
  84,
  101,
  'tienda-web',
  'Paginación en el listado de pedidos',
  author: _carlos,
  source: 'feature/paginar-pedidos',
  state: 'merged',
  created: const Duration(days: 11),
  updated: const Duration(days: 8),
  notes: 6,
);

/// MRs por scope de la API (`created_by_me`, `reviews_for_me`, `assigned_to_me`).
Map<String, List<Map<String, dynamic>>> demoMergeRequests() => {
  'created_by_me': [_mr142, _mr88, _mr57, _mr85, _mr80],
  'reviews_for_me': [_mr87, _mr23, _mr84],
  // El !87 llega también por aquí: la campana debe contarlo una sola vez.
  'assigned_to_me': [_mr87, _mr12],
};

Map<String, dynamic> _pipeline(
  int id,
  String status,
  String ref,
  String url,
  Duration ago,
) => {
  'id': id,
  'status': status,
  'ref': ref,
  'web_url': '$url/-/pipelines/$id',
  'updated_at': _ago(ago),
};

/// Lo que el detalle añade a la lista, por id global del MR.
Map<int, Map<String, dynamic>> demoMergeRequestExtras() {
  Map<String, dynamic> extra(
    Map<String, dynamic> mr,
    String? pipeline,
    String? mergeStatus, {
    String? description,
    int upvotes = 0,
    required String changes,
  }) {
    final url = (mr['web_url'] as String).split('/-/').first;
    return {
      'head_pipeline': pipeline == null
          ? null
          : _pipeline(
              mr['id'] as int,
              pipeline,
              mr['source_branch'] as String,
              url,
              const Duration(hours: 1),
            ),
      'description': description,
      'upvotes': upvotes,
      'downvotes': 0,
      'detailed_merge_status': mergeStatus,
      'merged_at': mr['state'] == 'merged' ? mr['updated_at'] : null,
      'closed_at': mr['state'] == 'closed' ? mr['updated_at'] : null,
      'changes_count': changes,
    };
  }

  return {
    5142: extra(
      _mr142,
      changes: '6',
      'running',
      'ci_still_running',
      description: 'Los webhooks que fallan se reencolan con espera exponencial, hasta 6 intentos.',
    ),
    5088: extra(_mr88, changes: '47', 'success', 'draft_status'),
    5057: extra(
      _mr57,
      changes: '3',
      'failed',
      'ci_must_pass',
      description:
          'Usa la huella o el rostro cuando el dispositivo lo permite.',
    ),
    5085: extra(_mr85, changes: '2', 'success', null, upvotes: 2),
    5080: extra(_mr80, changes: '12', 'canceled', null),
    5087: extra(
      _mr87,
      changes: '4',
      'success',
      'not_approved',
      description: 'Sustituye las llamadas al checkout antiguo por la API v2. Requiere revisar el cálculo de impuestos.',
      upvotes: 1,
    ),
    5023: extra(_mr23, changes: '5', 'success', 'discussions_not_resolved'),
    5012: extra(_mr12, changes: '8', null, 'conflict'),
    5084: extra(_mr84, changes: '3', 'success', null, upvotes: 3),
  };
}

List<Map<String, dynamic>> demoTodos() => [
  {
    'id': 701,
    'action_name': 'approval_required',
    'target_type': 'MergeRequest',
    'body': 'Migra el checkout a la nueva API',
    'created_at': _ago(const Duration(hours: 6)),
    'target_url': '${_mr87['web_url']}#note_88121',
    'author': _carlos,
    'project': {'name_with_namespace': 'Acme / tienda-web'},
  },
  {
    'id': 702,
    'action_name': 'directly_addressed',
    'target_type': 'Issue',
    'body': '@lgomez ¿puedes mirar por qué no llegan los reembolsos parciales?',
    'created_at': _ago(const Duration(hours: 9)),
    'target_url': '${projectUrl('tienda-web')}/-/issues/34#note_5521',
    'author': _carlos,
    'project': {'name_with_namespace': 'Acme / tienda-web'},
  },
  {
    'id': 703,
    'action_name': 'build_failed',
    'target_type': 'MergeRequest',
    'body': 'Login biométrico',
    'created_at': _ago(const Duration(hours: 20)),
    'target_url': _mr57['web_url'],
    'author': demoMe,
    'project': {'name_with_namespace': 'Acme / app-movil'},
  },
];
