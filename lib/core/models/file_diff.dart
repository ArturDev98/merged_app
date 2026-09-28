import 'repo_commit.dart';

enum DiffLineKind { hunk, context, added, removed, note }

/// Una línea de un diff unificado, sin su prefijo (`+`, `-` o espacio).
class DiffLine {
  const DiffLine(this.kind, this.text, {this.oldLine, this.newLine});

  final DiffLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;

  /// El número que se muestra: el nuevo, salvo en las líneas quitadas.
  int? get displayLine => kind == DiffLineKind.removed ? oldLine : newLine;
}

final _hunkHeader = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

/// Convierte el campo `diff` de GitLab en líneas con su numeración.
List<DiffLine> parseUnifiedDiff(String diff) {
  final lines = <DiffLine>[];
  var oldLine = 0;
  var newLine = 0;
  var inHunk = false;

  final raw = diff.split('\n');
  if (raw.isNotEmpty && raw.last.isEmpty) raw.removeLast();

  for (final line in raw) {
    final header = _hunkHeader.firstMatch(line);
    if (header != null) {
      oldLine = int.parse(header.group(1)!);
      newLine = int.parse(header.group(2)!);
      inHunk = true;
      lines.add(DiffLine(DiffLineKind.hunk, line));
    } else if (!inHunk) {
      // Antes del primer @@ solo llegan cabeceras de archivo (se omiten) o
      // avisos como "Binary files … differ".
      if (!line.startsWith('--- ') && !line.startsWith('+++ ')) {
        lines.add(DiffLine(DiffLineKind.note, line));
      }
    } else if (line.startsWith('+')) {
      lines.add(
        DiffLine(DiffLineKind.added, line.substring(1), newLine: newLine++),
      );
    } else if (line.startsWith('-')) {
      lines.add(
        DiffLine(DiffLineKind.removed, line.substring(1), oldLine: oldLine++),
      );
    } else if (line.startsWith(r'\')) {
      lines.add(DiffLine(DiffLineKind.note, line.substring(1).trim()));
    } else {
      final text = line.startsWith(' ') ? line.substring(1) : line;
      lines.add(
        DiffLine(
          DiffLineKind.context,
          text,
          oldLine: oldLine++,
          newLine: newLine++,
        ),
      );
    }
  }
  return lines;
}

/// Un archivo cambiado. Mismo formato en compare, en el diff de un commit y en
/// el de un merge request.
class FileDiff {
  FileDiff({
    required this.oldPath,
    required this.newPath,
    required this.diff,
    this.newFile = false,
    this.renamedFile = false,
    this.deletedFile = false,
    this.tooLarge = false,
    this.collapsed = false,
  });

  final String oldPath;
  final String newPath;
  final String diff;
  final bool newFile;
  final bool renamedFile;
  final bool deletedFile;

  /// GitLab no entrega el contenido por tamaño: solo se puede ver allí.
  final bool tooLarge;

  /// GitLab lo pliega por sus límites de diff; también queda vacío.
  final bool collapsed;

  late final List<DiffLine> lines = parseUnifiedDiff(diff);

  late final int additions = lines
      .where((l) => l.kind == DiffLineKind.added)
      .length;
  late final int deletions = lines
      .where((l) => l.kind == DiffLineKind.removed)
      .length;

  /// No hay nada que pintar aquí: se ofrece verlo en GitLab.
  bool get unavailable =>
      tooLarge ||
      collapsed ||
      !lines.any(
        (l) => l.kind == DiffLineKind.added || l.kind == DiffLineKind.removed,
      );

  String get path => deletedFile ? oldPath : newPath;
  String get fileName => path.split('/').last;
  String get directory {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }

  factory FileDiff.fromJson(Map<String, dynamic> json) => FileDiff(
    oldPath: json['old_path'] as String? ?? '',
    newPath: json['new_path'] as String? ?? '',
    diff: json['diff'] as String? ?? '',
    newFile: json['new_file'] as bool? ?? false,
    renamedFile: json['renamed_file'] as bool? ?? false,
    deletedFile: json['deleted_file'] as bool? ?? false,
    tooLarge: json['too_large'] as bool? ?? false,
    collapsed: json['collapsed'] as bool? ?? false,
  );
}

/// Resultado de `compare`: los commits de un push y sus archivos cambiados.
class Comparison {
  const Comparison({
    required this.commits,
    required this.files,
    this.truncated = false,
  });

  final List<RepoCommit> commits;
  final List<FileDiff> files;

  /// GitLab cortó la comparación: los commits están completos, los archivos
  /// quizá no.
  final bool truncated;

  factory Comparison.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) {
      final value = json[key];
      return value is List
          ? value.whereType<Map<String, dynamic>>().toList()
          : const [];
    }

    return Comparison(
      commits: list('commits').map(RepoCommit.fromJson).toList(),
      files: list('diffs').map(FileDiff.fromJson).toList(),
      truncated: json['compare_timeout'] as bool? ?? false,
    );
  }
}
