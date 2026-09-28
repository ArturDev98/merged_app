import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/models/file_diff.dart';
import 'package:merged_app/core/models/merge_request_detail.dart';

void main() {
  group('parseUnifiedDiff', () {
    test('numera cada lado desde la cabecera del bloque', () {
      final lines = parseUnifiedDiff(
        '@@ -10,3 +10,4 @@ class Foo\n'
        ' contexto\n'
        '-quitada\n'
        '+añadida\n'
        '+otra\n'
        ' final\n',
      );

      expect(lines.map((l) => l.kind), [
        DiffLineKind.hunk,
        DiffLineKind.context,
        DiffLineKind.removed,
        DiffLineKind.added,
        DiffLineKind.added,
        DiffLineKind.context,
      ]);
      expect(lines[1].text, 'contexto');
      // La quitada muestra su número viejo; las añadidas, el nuevo.
      expect(lines[2].displayLine, 11);
      expect(lines[3].displayLine, 11);
      expect(lines[4].displayLine, 12);
      expect(lines[5].oldLine, 12);
      expect(lines[5].newLine, 13);
    });

    test('el aviso de fin de archivo no cuenta como línea de código', () {
      final lines = parseUnifiedDiff(
        '@@ -1 +1 @@\n-a\n\\ No newline at end of file\n+b\n',
      );

      expect(lines[2].kind, DiffLineKind.note);
      expect(lines[2].text, 'No newline at end of file');
      expect(lines[3].displayLine, 1);
    });

    test('antes del primer bloque omite cabeceras y conserva avisos', () {
      final lines = parseUnifiedDiff(
        '--- a/logo.png\n+++ b/logo.png\nBinary files a/logo.png and b/logo.png differ\n',
      );

      expect(lines, hasLength(1));
      expect(lines.single.kind, DiffLineKind.note);
    });
  });

  group('FileDiff', () {
    test('cuenta líneas añadidas y quitadas', () {
      final file = FileDiff(
        oldPath: 'a.dart',
        newPath: 'a.dart',
        diff: '@@ -1,2 +1,3 @@\n-x\n+y\n+z\n w\n',
      );

      expect(file.additions, 2);
      expect(file.deletions, 1);
      expect(file.unavailable, isFalse);
    });

    test('lo que GitLab no entrega queda marcado como no disponible', () {
      expect(
        FileDiff.fromJson({
          'old_path': 'package-lock.json',
          'new_path': 'package-lock.json',
          'diff': '',
          'too_large': true,
        }).unavailable,
        isTrue,
      );
      // Un renombrado sin cambios tampoco tiene nada que pintar.
      expect(
        FileDiff.fromJson({
          'old_path': 'docs/a.md',
          'new_path': 'docs/b.md',
          'diff': '',
          'renamed_file': true,
        }).unavailable,
        isTrue,
      );
    });

    test('un archivo borrado se nombra por su ruta vieja', () {
      final file = FileDiff.fromJson({
        'old_path': 'src/legacy/sender.ts',
        'new_path': 'src/legacy/sender.ts',
        'deleted_file': true,
        'diff': '@@ -1 +0,0 @@\n-x\n',
      });

      expect(file.fileName, 'sender.ts');
      expect(file.directory, 'src/legacy');
    });
  });

  test('Comparison separa commits y archivos y avisa del corte', () {
    final comparison = Comparison.fromJson({
      'commits': [
        {'id': 'abc', 'short_id': 'abc', 'title': 'Arregla algo'},
      ],
      'diffs': [
        {'old_path': 'a', 'new_path': 'a', 'diff': '@@ -1 +1 @@\n-a\n+b\n'},
      ],
      'compare_timeout': true,
    });

    expect(comparison.commits.single.title, 'Arregla algo');
    expect(comparison.files.single.additions, 1);
    expect(comparison.truncated, isTrue);
  });

  test('changes_count llega como texto y "1000+" cuenta como 1000', () {
    MergeRequestDetail detail(Object? count) => MergeRequestDetail.fromJson({
      'id': 1,
      'iid': 1,
      'changes_count': count,
    });

    expect(detail('12').changedFiles, 12);
    expect(detail('1000+').changedFiles, 1000);
    expect(detail(null).changedFiles, isNull);
  });
}
