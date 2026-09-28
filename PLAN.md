# Merged — Plan de trabajo

App móvil Flutter: **GitLab resumido en el móvil**. El usuario inicia sesión con
su cuenta de GitLab y ve, de un vistazo, su informe personal: su actividad, sus
merge requests, sus commits, sus ramas y sus proyectos.

- **Destino:** app pública. Se valida primero con la cuenta del autor, pero se
  diseña para cualquier usuario de GitLab.
- **Alcance v0.1:** solo lectura (`read_api` + `read_user`, ya validados).
- **Instancia:** solo gitlab.com. Plataforma: Android. Idioma: español. Ver
  "Decisiones".
- **Ruta:** pulir la interfaz → beta repartiendo el APK → Play Store.

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
    auth/        auth_service, auth_failure
    api/         gitlab_client              dio + interceptor + paginación
    data/        repositorio, campana (pending_work), caché offline
    models/      user, project, merge_request, todo, activity_event, commit
    providers.dart, theme_mode_controller.dart
  features/
    auth/        login
    summary/     el informe (home)
    activity/    detalle de push
    pending/     lista de la campana
    merge_requests/
    projects/
    branches/
  shared/        etiquetas, "Abrir en GitLab", tiempos relativos, estados
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
- [x] CI en GitHub Actions: formato, análisis y tests en cada push y PR
      (2026-09-27)
- [x] Fuera `linux/`, `macos/` y `windows/`: la v0.1 es Android; `web/` se
      queda para el modo demo e `ios/` para cuando toque

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

### Fase 3 — Merge requests y proyectos — ✅ completada

- [x] Lista de MRs por scope, con draft y filtro de estado
- [x] Detalle de MR con pipeline y diagnóstico de fusión
- [x] Lista de proyectos (accesible tocando su tarjeta en el resumen)
- [x] **"Abrir en GitLab"** con `web_url`: en una app de solo lectura es la
      válvula de escape imprescindible

### Fase 4 — Ramas y pulido — ✅ completada

- [x] Ramas creadas, derivadas de los eventos (sin llamadas extra)
- [x] Tema claro/oscuro con selector persistente, e icono adaptativo
- [x] Caché offline: última respuesta buena, con aviso de datos guardados
- [x] Sesión expirada: el gate vuelve al login solo

Fases 3 y 4 validadas en el teléfono el 2026-09-27: datos y navegación
correctos. El splash pasa a la fase 5.

### Fase 5 — Pulido de interfaz

- [x] Nombre visible "Merged" en Android, iOS y web
- [x] Splash propio, claro y oscuro, también con la API de Android 12+
      (falta verlo en el teléfono)
- [x] Modo demo para revisar la interfaz en el navegador, sin login ni red:
      `flutter run -d chrome -t lib/demo/main_demo.dart`
- [x] Dirección visual «Viva»: fuente Outfit incluida en la app, teal de marca,
      un color por tipo de evento
- [x] Home: cabecera con los números del periodo, accesos directos a MRs,
      ramas y proyectos, y actividad agrupada por día
- [x] Tema, licencias y cerrar sesión, en una hoja que se abre desde el avatar
- [x] Las etiquetas (tags) nuevas ya no se anuncian como ramas
- [x] Textos del framework en español (`flutter_localizations`) y plurales
      bien concordados
- [ ] Revisar en el teléfono y ajustar lo que salga

### Fase 6 — Beta por APK

Validar con usuarios reales antes de pagar Play Console.

- [ ] App OAuth de producción en un grupo de gitlab.com y su `client_id` en la
      app. Va **antes** de repartir: la pantalla de autorización de GitLab
      enseña quién creó la app, y los testers no deben autorizar la de dev
- [ ] Versión `0.1.0+1`, descripción de `pubspec.yaml` y README reales
- [ ] Versión visible dentro de la app, para saber qué APK tiene quien reporta
- [ ] Firma de release propia (`key.properties` fuera de git). Con la de debug,
      un APK solo actualiza a otro si ambos se compilaron en este PC
- [ ] APK universal y canal de reparto
- [ ] Buscar testers con otro perfil: revisores o asignados a MRs. La campana y
      la lista de MRs "a revisar" nunca tienen datos con la cuenta del autor

### Fase 7 — Publicación en Play

- [ ] Cuenta de Play Console (25 USD, pago único)
- [ ] Política de privacidad en una URL pública y formulario de seguridad de
      datos. Es corta: no hay backend, todo va del móvil a GitLab
- [ ] Prueba cerrada obligatoria para cuentas personales nuevas: **12 testers
      inscritos durante 14 días seguidos**. Los de la beta son los candidatos
- [ ] Ficha de la tienda: capturas y descripción, aclarando que es un cliente
      no oficial de GitLab

---

## Decisiones (2026-09-27)

- **Solo gitlab.com en la v0.1.** Soportar instancias self-managed no es solo
  cambiar `GitlabClient.baseUrl`: el `client_id` de OAuth pertenece a la
  instancia donde se registró y no existe en las demás. Queda para la v0.2,
  entrando con un Personal Access Token.
- **App OAuth de producción en un grupo de gitlab.com**, no en una cuenta
  concreta: si la cuenta dueña se desactiva, el login cae para todos. El
  `client_id` viaja en el binario, lo cual es correcto para un cliente público
  con PKCE. "Merged (Dev)" se queda para desarrollo.
- **Solo español en la v0.1.** El inglés llega en la v0.2 con `gen-l10n`.
- **Solo Android en la v0.1.** iOS requiere compilar en un Mac.

## Fuera de la v0.1

Acciones de escritura (aprobar, comentar, marcar todos), issues, pipelines como
sección propia, notificaciones push, búsqueda global, instancias self-managed,
inglés, iOS.

---

## Cuidado al actualizar el template de Flutter

`android/app/src/main/AndroidManifest.xml` tiene dos desviaciones deliberadas del
template, ambas necesarias para que el login OAuth vuelva a la app. Están
documentadas en el propio archivo. Un `flutter create` encima puede reintroducir
el fallo de forma silenciosa.
