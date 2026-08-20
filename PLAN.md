# Merged — Plan de trabajo

App móvil Flutter: **GitLab resumido en el móvil**. El usuario inicia sesión con
su cuenta de GitLab y ve, de un vistazo, su informe personal: su actividad, sus
merge requests, sus commits, sus ramas y sus proyectos.

- **Destino:** app pública. Se valida primero con la cuenta del autor, pero se
  diseña para cualquier usuario de GitLab.
- **Alcance v0.1:** solo lectura (`read_api` + `read_user`, ya validados).
- **Instancia:** gitlab.com. Ver "Decisiones abiertas".

---

## Lo que dijo la API (medido, no supuesto)

Diagnóstico del 2026-08-18 contra una cuenta real de 11 proyectos:

| Fuente | Resultado |
|---|---|
| MRs creados (histórico) | 9, **0 abiertos** en ese momento |
| MRs asignados / como reviewer (histórico) | **0** |
| Todos pendientes | **0** |
| Eventos recientes | **100 con página siguiente** (~4/día) |
| Eventos degradados (`commit_count: 0`) | **0 de 20** |
| Reparto de actividad | `pushed to: 63`, `pushed new: 33`, `opened: 3`, `joined: 1` |

Dos lecturas que cambiaron el plan original:

1. **La home de "qué requiere mi atención" estaría vacía casi siempre** para un
   perfil como este. No es que hoy no haya nada: es que `reviews_for_me` y
   `assigned_to_me` son 0 en todo el histórico. Para otros perfiles (revisores,
   leads) serán la parte más llena, así que se mantienen — pero no pueden ser
   el centro de la pantalla principal.
2. **Los eventos de push llegan íntegros**, no degradados como advierte la
   documentación para el peor caso. La actividad es la fuente más rica.

### Cómo sí se consiguen "mis commits"

No existe endpoint de commits propios entre proyectos, pero cada evento de push
trae `project_id`, `commit_from` y `commit_to`. Con eso,
`GET /projects/:id/repository/compare?from=&to=` devuelve la **lista real de
commits** (id, título, autor, fecha). Verificado en la documentación.

Así que: el feed cuesta **una** llamada, y los commits reales de un push cuestan
**una más, solo al tocarlo**. Nada de N+1 al pintar la lista.

### Dos huecos en los payloads (medidos)

- **Los eventos no traen el nombre del proyecto, solo `project_id`.** Pintar el
  feed con el nombre sería un N+1. Solución: cargar una vez
  `/projects?membership=true&simple=true` (11 elementos) y resolver en local.
  La lista de proyectos deja de ser solo una pantalla y pasa a ser también
  tabla de búsqueda.
- **La lista de merge requests no incluye `head_pipeline`.** Comprobado sobre un
  MR real. El estado del pipeline solo está en el detalle
  (`/projects/:id/merge_requests/:iid`), así que la lista no debe prometerlo.

### Ramas creadas

No hacen falta llamadas extra: son los propios eventos con
`push_data.action == 'created'` y `ref_type == 'branch'` (33 de los últimos 100).

---

## Superficies de la v0.1

1. **Resumen (el "informe").** Pantalla de entrada: contadores del periodo
   —pushes, commits, ramas creadas, proyectos, MRs abiertos— y accesos al resto.
2. **Actividad.** Feed de pushes. Al tocar uno, sus commits reales vía `compare`.
3. **Merge requests.** Creados por mí / asignados / a revisar, con estado de
   draft. El pipeline solo en el detalle (ver más abajo).
4. **Proyectos.** Aquellos donde el usuario es miembro.
5. **Ramas creadas.** Derivadas del feed de eventos.

**Home híbrida:** la actividad ocupa el cuerpo; los pendientes viven en una
**campana con contador** en la barra superior.

### La campana

Responde a una sola pregunta: **¿me están esperando?**

- **Cuenta:** todos pendientes + MRs abiertos donde el usuario es reviewer o
  asignado, **deduplicados** por `TodoItem.dedupeKey` / `web_url` (un mismo MR
  llega por las dos vías).
- **No cuenta** los MRs abiertos propios: son trabajo en curso, no algo que
  bloquee. Van al resumen como un contador aparte.
- **El cero se muestra**, en gris y con el `0` visible. Es deliberado: la
  convención habitual de ocultar el badge en cero haría dudar entre "no tengo
  nada" y "esto no ha cargado".
- **Sin sección vacía en el cuerpo.** La campana ya comunica el estado; una
  franja de "sin pendientes" diría lo mismo dos veces y empujaría el feed hacia
  abajo todos los días.
- **Fricción asumida:** una campana sugiere que puedes despachar lo que hay
  dentro, y la v0.1 es de solo lectura. Al tocar se abre la lista y cada
  elemento lleva a "Abrir en GitLab".

> Los estados vacíos son diseño de primera clase, no un caso borde: en la cuenta
> de desarrollo varias secciones estarán vacías a diario.

---

## Arquitectura

```
lib/
  core/
    auth/        auth_service.dart          ✅ funcionando
    api/         gitlab_client.dart         ✅ dio + interceptor + paginación
                 api_smoke_test.dart        (temporal, se borra en fase 2)
    models/      user, project, merge_request, todo, push_event, commit
  features/
    summary/     el informe (home)
    activity/    feed + detalle de push
    merge_requests/
    projects/
  app.dart
  main.dart
```

- **Estado: `flutter_riverpod`.** Datos asíncronos con caché e invalidación.
- **HTTP: `dio`.** Elegido por los interceptors. ✅ hecho.
- **Modelos: `fromJson` a mano** mientras sean pocos.

---

## Fases

### Fase 0 — Higiene — ✅ completada

- [x] `git init` + primer commit
- [x] Smoke test real en `widget_test.dart`, mockeando el canal de
      flutter_secure_storage
- [x] `flutter analyze` sin avisos
- [x] Identidad real: `com.example.merged_app` → `dev.merged.app` (Android, iOS
      y macOS)

### Fase 1 — Capa de datos — ✅ completada

- [x] `GitlabClient` sobre dio, `baseUrl = https://gitlab.com/api/v4`
- [x] Interceptor de auth: inyecta el token; ante 401 refresca y reintenta una
      vez; si el refresh falla, cierra sesión
- [x] Paginación por cabeceras (`x-next-page`, `x-total` tratada como opcional)
- [x] Smoke test contra la cuenta real: los scopes alcanzan, ningún 403
- [x] Modelos a partir de los payloads reales
- [x] Repositorios por superficie (actividad, MRs, proyectos)

### Fase 2 — Resumen + Actividad — ✅ completada

- [x] Riverpod y estructura de `features/`
- [x] Pantalla de resumen con los contadores
- [x] Campana con contador de pendientes deduplicados
- [x] Feed de actividad con paginación (hay más de 100 eventos)
- [x] Detalle de push → commits reales vía `compare`
- [x] Pull to refresh y los cuatro estados: cargando, vacío, error, sin conexión
- [x] Borrar `api_smoke_test.dart`

### Fase 3 — Merge requests y proyectos — en curso

- [ ] Lista de MRs por scope, con draft (el pipeline va en el detalle)
- [ ] Detalle de MR
- [x] Lista de proyectos (accesible tocando su tarjeta en el resumen)
- [ ] **"Abrir en GitLab"** con `web_url`: en una app de solo lectura es la
      válvula de escape imprescindible

### Fase 4 — Ramas y pulido

- [ ] Ramas creadas, derivadas de los eventos
- [ ] Tema claro/oscuro, icono, splash
- [ ] Caché offline
- [ ] Sesión expirada y logout

---

## Decisiones abiertas

- **Instancias self-managed.** Hoy la URL es fija. Para una app pública es una
  limitación real: mucha gente usa GitLab autoalojado. `GitlabClient.baseUrl`
  está centralizado en un único punto a propósito, así que añadir una pantalla
  de instancia es un cambio acotado. Decidir antes de publicar.
- **Aplicación OAuth de producción.** La actual es "Merged (Dev)", personal. Una
  app pública necesita la suya. El `client_id` viaja en el binario, lo cual es
  correcto para un cliente público con PKCE.

## Fuera de la v0.1

Acciones de escritura (aprobar, comentar, marcar todos), issues, pipelines como
sección propia, notificaciones push, búsqueda global.

---

## Cuidado al actualizar el template de Flutter

`android/app/src/main/AndroidManifest.xml` tiene dos desviaciones deliberadas del
template, ambas necesarias para que el login OAuth vuelva a la app. Están
documentadas en el propio archivo. Un `flutter create` encima puede reintroducir
el fallo de forma silenciosa.
