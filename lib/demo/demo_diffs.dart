// Diffs ficticios con la forma del campo `diffs` de la API: los de la rama de
// reintentos están escritos a mano; el resto se generan.

import 'demo_data.dart';

Map<String, dynamic> _file(
  String path,
  String diff, {
  String? oldPath,
  bool newFile = false,
  bool deletedFile = false,
  bool renamedFile = false,
  bool tooLarge = false,
}) => {
  'old_path': oldPath ?? path,
  'new_path': path,
  'a_mode': '100644',
  'b_mode': '100644',
  'diff': diff,
  'new_file': newFile,
  'renamed_file': renamedFile,
  'deleted_file': deletedFile,
  'too_large': tooLarge,
  'collapsed': false,
};

final _webhookFiles = [
  _file('src/webhooks/retry-queue.ts', newFile: true, r'''@@ -0,0 +1,18 @@
+import { queue, deadLetter } from '../infra/queue';
+import type { WebhookEvent } from './types';
+
+const MAX_ATTEMPTS = 6;
+const BASE_DELAY_MS = 2_000;
+
+/** Reencola un webhook fallido con espera exponencial. */
+export async function scheduleRetry(event: WebhookEvent, attempt: number) {
+  if (attempt >= MAX_ATTEMPTS) {
+    await deadLetter.push(event);
+    return;
+  }
+  await queue.push(event, {
+    delay: BASE_DELAY_MS * 2 ** attempt,
+    attempt: attempt + 1,
+  });
+}
'''),
  _file('src/webhooks/dispatcher.ts', r'''@@ -1,6 +1,7 @@
 import { HttpClient } from '../infra/http';
 import { Logger } from '../infra/logger';
+import { scheduleRetry } from './retry-queue';
 import type { WebhookEvent } from './types';

 export class WebhookDispatcher {
@@ -14,10 +15,15 @@ export class WebhookDispatcher {

   async dispatch(event: WebhookEvent) {
-    const response = await this.http.post(event.url, event.payload);
-    if (!response.ok) {
-      this.logger.error(`Webhook ${event.id} falló`);
-    }
+    try {
+      const response = await this.http.post(event.url, event.payload, {
+        timeout: 10_000,
+      });
+      if (!response.ok) throw new Error(`HTTP ${response.status}`);
+    } catch (error) {
+      this.logger.warn(`Webhook ${event.id} falló, se reintenta`, error);
+      await scheduleRetry(event, event.attempt ?? 0);
+    }
   }
 }
'''),
  _file('src/webhooks/legacy-sender.ts', deletedFile: true, r'''@@ -1,6 +0,0 @@
-import { HttpClient } from '../infra/http';
-
-/** @deprecated Usa WebhookDispatcher. */
-export function sendWebhook(url: string, payload: unknown) {
-  return new HttpClient().post(url, payload);
-}
'''),
  _file('test/webhooks/retry-queue.test.ts', newFile: true, r'''@@ -0,0 +1,13 @@
+import { scheduleRetry } from '../../src/webhooks/retry-queue';
+import { queue, deadLetter } from '../../src/infra/queue';
+
+describe('scheduleRetry', () => {
+  it('espera el doble en cada intento', async () => {
+    await scheduleRetry(evento, 3);
+    expect(queue.push).toHaveBeenCalledWith(evento, { delay: 16_000, attempt: 4 });
+  });
+
+  it('al sexto intento lo manda a la cola de fallidos', async () => {
+    await scheduleRetry(evento, 6);
+    expect(deadLetter.push).toHaveBeenCalledWith(evento);
+  });
'''),
  _file(
    'docs/webhooks.md',
    oldPath: 'docs/hooks.md',
    renamedFile: true,
    r'''@@ -1,3 +1,6 @@
-# Hooks
+# Webhooks

 Los webhooks se firman con HMAC-SHA256 y se envían por POST.
+
+Si el destino falla, se reintentan hasta 6 veces con espera exponencial
+(2 s, 4 s, 8 s…). Después pasan a la cola de fallidos.
''',
  ),
  _file('package-lock.json', '', tooLarge: true),
];

const _genericPaths = {
  'tienda-web': [
    'src/cart/totals.ts',
    'src/cart/coupons.ts',
    'src/api/checkout.ts',
  ],
  'app-movil': ['lib/orders/orders_screen.dart', 'lib/theme/dark.dart'],
  'infra-terraform': [
    'modules/workers/main.tf',
    'modules/workers/variables.tf',
  ],
  'docs': ['guias/reembolsos.md'],
  'design-system': ['tokens/colors.json'],
  'portal-proveedores': [
    'src/suppliers/validate-nit.ts',
    'src/suppliers/form.tsx',
  ],
};

Map<String, dynamic> _generic(String path, String title) =>
    _file(path, '''@@ -18,6 +18,9 @@ export function handle(input) {
   const result = compute(input);
-  return result;
+  // $title
+  const checked = validate(result);
+  return checked;
 }

 export default handle;
''');

List<Map<String, dynamic>> _genericFiles(
  String projectPath,
  String title,
  int count,
) {
  final paths = _genericPaths[projectPath] ?? const ['src/service.ts'];
  return List.generate(count, (i) {
    final base = paths[i % paths.length];
    // Más archivos que rutas de ejemplo: se numeran para no repetir nombre.
    final path = i < paths.length ? base : base.replaceFirst('.', '_$i.');
    return _generic(path, title);
  });
}

List<Map<String, dynamic>> demoPushDiffs(DemoPush push, String projectPath) =>
    push.ref == 'feature/reintentos-webhook'
    ? _webhookFiles
    : _genericFiles(projectPath, push.lastTitle, push.commits.clamp(1, 3));

/// Los archivos del push se reparten entre sus commits.
List<Map<String, dynamic>> demoCommitDiffs(String sha, String projectPath) {
  final push = demoPushByCommitSha[sha];
  if (push == null) return const [];
  final all = demoPushDiffs(push, projectPath);
  final index = demoCommitIndex[sha] ?? 0;
  return [
    for (final (i, file) in all.indexed)
      if (i % push.commits == index) file,
  ];
}

List<Map<String, dynamic>> demoMergeRequestDiffs(
  Map<String, dynamic> mr,
  String projectPath,
  int changes,
) => mr['iid'] == 142
    ? _webhookFiles
    : _genericFiles(projectPath, mr['title'] as String, changes.clamp(0, 30));
