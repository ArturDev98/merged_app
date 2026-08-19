# Merged — Plan de trabajo

App móvil Flutter: dashboard personal de GitLab. Responde a una pregunta
concreta cada mañana: **¿qué requiere mi atención hoy?**

- **Alcance v1:** solo lectura (`read_api` + `read_user`, ya validados).
- **Instancia:** gitlab.com fija.
- **Home:** bandeja unificada de todos + merge requests.

---

## Restricción que define el diseño

GitLab **no expone un endpoint de "mis commits"**. Conviene tenerlo claro antes
de prometer esa pantalla:

| Qué queremos | Endpoint | Calidad |
|---|---|---|
| Qué me toca revisar / responder | `GET /todos?state=pending` | Excelente. Filtros por `approval_required`, `build_failed`, `unmergeable`, `assigned`, `mentioned` |
| Mis MRs (creados / asignados / a revisar) | `GET /merge_requests?scope=…` | Excelente. Una sola llamada por scope, incluye `draft`, `head_pipeline`, `user_notes_count` |
| Mis commits | `GET /events?action=pushed` | **Pobre.** Devuelve *eventos de push*, no commits |

Un evento `pushed` trae `commit_title` (solo el último del push), `commit_count`
y la rama — nunca la lista de commits. Si el push supera el límite de actividad
de GitLab, llega degradado: `commit_count: 0` y campos nulos. Además los eventos
tienen retención limitada en el tiempo.

**Consecuencia:** la pantalla de commits se llama "Actividad" y muestra pushes,
no commits. Iterar `GET /projects/:id/repository/commits` por cada proyecto sería
la alternativa, pero cuesta N+1 llamadas y filtra el autor por string: fuera de v1.

---

## Arquitectura

Se continúa la estructura que ya insinúa `lib/core/auth/`:

```
lib/
  core/
    auth/        auth_service.dart          (ya existe, funcionando)
    api/         gitlab_client.dart         (dio + interceptor de auth)
    models/      user, merge_request, todo, event
  features/
    inbox/       home "qué requiere mi atención"
    merge_requests/
    activity/
  app.dart       MaterialApp + router
  main.dart      solo bootstrap
```

**Decisiones técnicas:**

- **Estado: `flutter_riverpod`.** El caso de uso es datos asíncronos con caché,
  invalidación y pull-to-refresh, que es justo su punto fuerte. La home compone
  tres providers independientes sin acoplarlos.
- **HTTP: `dio`.** Se elige por los interceptors: uno solo inyecta el token
  llamando a `AuthService.getValidAccessToken()`, que ya resuelve el refresh.
- **Modelos: `fromJson` a mano.** Son ~5 modelos; no compensa la fricción de
  `build_runner`. Se migra a `json_serializable` si crecen.

---

## Fases

### Fase 0 — Higiene (antes de tocar features) — ✅ completada

Barato ahora, caro después.

- [x] **`git init` + primer commit.** Nada está versionado todavía. Es el mayor
      riesgo del proyecto ahora mismo.
- [x] Sustituir `test/widget_test.dart` (era el test del contador de la plantilla)
      por un smoke test real de arranque sin sesión, mockeando el MethodChannel
      de flutter_secure_storage.
- [x] Limpiar 3 warnings de null-checks muertos en `auth_service.dart:46,106,111`
      (en flutter_appauth 12 esos valores ya no son nullable).
- [x] Cambiar `applicationId` de `com.example.merged_app` a `dev.merged.app`
      (también los bundle id de iOS y macOS). No afecta al
      login: el redirect (`dev.merged.app://callback`) es independiente del
      applicationId. Renombrar el paquete más adelante es mucho más molesto.

### Fase 1 — Capa de datos

Empieza por un **smoke test** que valide los scopes antes de construir UI encima:
llamar a `GET /user` y `GET /todos` con el token real. Si `read_api` no alcanzara
para algo, es mejor descubrirlo aquí que con tres pantallas ya hechas.

- [ ] `GitlabClient` sobre dio, con `baseUrl = https://gitlab.com/api/v4`
- [ ] Interceptor de auth: inyecta el token; ante 401 refresca y reintenta una vez;
      si el refresh falla, hace logout y devuelve al login
- [ ] Modelos: `GitlabUser`, `MergeRequest`, `Todo`, `PushEvent`
- [ ] Paginación: `page` / `per_page=20`, leyendo la cabecera `X-Next-Page`

### Fase 2 — Home "Qué requiere mi atención"

Fusiona tres fuentes:

```
GET /todos?state=pending
GET /merge_requests?scope=reviews_for_me&state=opened
GET /merge_requests?scope=assigned_to_me&state=opened
```

- [ ] **Deduplicar.** Un mismo MR aparece a la vez como todo `approval_required`
      y en `reviews_for_me`. Sin dedup la home muestra todo dos veces. Clave por
      id de MR / `target_url`
- [ ] Agrupar por urgencia: pipelines rotos → aprobaciones pendientes → menciones
- [ ] Pull to refresh
- [ ] Los cuatro estados de verdad: cargando, vacío, error, sin conexión

### Fase 3 — Detalle de MR

- [ ] Estado de pipeline (`head_pipeline`), draft, nº de comentarios, ramas
- [ ] **"Abrir en GitLab"** con `web_url`. En una app de solo lectura esta es la
      válvula de escape imprescindible: todo lo que no se pueda hacer aquí, se
      hace en el navegador

### Fase 4 — Actividad

- [ ] `GET /events?action=pushed`, presentado honestamente como pushes
- [ ] Contemplar el caso degradado (`commit_count: 0`) sin romper la UI

### Fase 5 — Pulido

- [ ] Tema claro/oscuro, icono, splash
- [ ] Caché offline (última respuesta buena persistida)
- [ ] Logout y pantalla de sesión expirada

---

## Fuera de v1

Escribirlo evita que se cuele: acciones de escritura (aprobar, comentar, marcar
todos), instancias self-managed, issues, pipelines/CI como sección propia,
notificaciones push, búsqueda global, gestión de proyectos.

---

## Cuidado al actualizar el template de Flutter

`android/app/src/main/AndroidManifest.xml` tiene dos desviaciones deliberadas del
template, ambas necesarias para que el login OAuth vuelva a la app. Están
documentadas en el propio archivo. Un `flutter create` encima puede reintroducir
el fallo de forma silenciosa.
