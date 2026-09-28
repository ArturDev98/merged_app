import 'package:flutter/material.dart';

import '../core/models/file_diff.dart';
import '../core/theme/app_theme.dart';
import 'open_in_gitlab.dart';
import 'tone_icon.dart';

// Por encima de esto un diff no se lee en un móvil: se corta y se ofrece GitLab.
const _maxLinesPerFile = 400;

const _mono = TextStyle(
  fontFamily: monoFontFamily,
  fontSize: 12.5,
  height: 1.45,
);

/// Archivos cambiados, cada uno con su diff desplegable.
class FileDiffList extends StatelessWidget {
  const FileDiffList({
    super.key,
    required this.files,
    this.webUrl,
    this.incomplete = false,
  });

  final List<FileDiff> files;

  /// Dónde ver el cambio completo en GitLab.
  final String? webUrl;

  /// GitLab no entregó todos los archivos.
  final bool incomplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final additions = files.fold(0, (sum, f) => sum + f.additions);
    final deletions = files.fold(0, (sum, f) => sum + f.deletions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Row(
            children: [
              Text('Archivos cambiados', style: theme.textTheme.titleSmall),
              const SizedBox(width: 6),
              Text(
                '${files.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _Counts(additions: additions, deletions: deletions),
            ],
          ),
        ),
        if (incomplete)
          _Notice(
            text: 'GitLab no entregó todos los archivos de este cambio.',
            webUrl: webUrl,
          ),
        for (final (index, file) in files.indexed) ...[
          if (index > 0) const Divider(indent: 64),
          _FileDiffTile(
            file: file,
            webUrl: webUrl,
            // Con un solo archivo no hay nada que elegir: se abre directamente.
            initiallyExpanded: files.length == 1,
          ),
        ],
      ],
    );
  }
}

class _FileDiffTile extends StatefulWidget {
  const _FileDiffTile({
    required this.file,
    required this.webUrl,
    required this.initiallyExpanded,
  });

  final FileDiff file;
  final String? webUrl;
  final bool initiallyExpanded;

  @override
  State<_FileDiffTile> createState() => _FileDiffTileState();
}

class _FileDiffTileState extends State<_FileDiffTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final theme = Theme.of(context);
    final colors = MergedColors.of(context);
    final (icon, tone) = switch (file) {
      FileDiff(newFile: true) => (Icons.add, colors.green),
      FileDiff(deletedFile: true) => (Icons.remove, colors.red),
      FileDiff(renamedFile: true) => (
        Icons.drive_file_rename_outline,
        colors.blue,
      ),
      _ => (Icons.edit_outlined, colors.amber),
    };
    final subtitle = file.renamedFile
        ? 'Renombrado desde ${file.oldPath}'
        : file.directory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            child: Row(
              children: [
                ToneIcon(icon: icon, tone: tone, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Counts(additions: file.additions, deletions: file.deletions),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: file.unavailable
                ? _Notice(
                    text: _whyUnavailable(file),
                    webUrl: _worthOpening(file) ? widget.webUrl : null,
                    padding: EdgeInsets.zero,
                  )
                : _DiffLines(lines: file.lines, webUrl: widget.webUrl),
          ),
      ],
    );
  }

  static bool _isBinary(FileDiff file) => file.lines.any(
    (l) => l.kind == DiffLineKind.note && l.text.startsWith('Binary files'),
  );

  static bool _worthOpening(FileDiff file) =>
      file.tooLarge || file.collapsed || _isBinary(file);

  static String _whyUnavailable(FileDiff file) {
    if (file.tooLarge || file.collapsed) {
      return 'GitLab no envía este cambio por su tamaño.';
    }
    if (_isBinary(file)) {
      return 'Archivo binario: no se puede mostrar como texto.';
    }
    if (file.renamedFile) return 'Solo cambió de nombre.';
    if (file.newFile) return 'Archivo nuevo, vacío.';
    if (file.deletedFile) return 'Se borró un archivo vacío.';
    return 'Sin cambios de texto que mostrar.';
  }
}

class _DiffLines extends StatelessWidget {
  const _DiffLines({required this.lines, required this.webUrl});

  final List<DiffLine> lines;
  final String? webUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = lines.take(_maxLinesPerFile).toList();
    final hidden = lines.length - visible.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              // Un solo scroll horizontal para todo el archivo: las líneas de
              // código no se parten, porque romperían la indentación.
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final line in visible) _Line(line)],
                    ),
                  ),
                ),
              ),
            ),
            if (hidden > 0)
              _Notice(
                text: '$hidden líneas más que no caben aquí.',
                webUrl: webUrl,
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.line);

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = MergedColors.of(context);

    final (background, marker, markerColor) = switch (line.kind) {
      DiffLineKind.added => (
        colors.green.background,
        '+',
        colors.green.foreground,
      ),
      DiffLineKind.removed => (
        colors.red.background,
        '−',
        colors.red.foreground,
      ),
      DiffLineKind.hunk => (scheme.surfaceContainerHigh, '', scheme.outline),
      _ => (Colors.transparent, '', scheme.outline),
    };
    final muted =
        line.kind == DiffLineKind.hunk || line.kind == DiffLineKind.note;

    return Container(
      color: background,
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                line.displayLine?.toString() ?? '',
                textAlign: TextAlign.right,
                // Del color de la línea: una quitada lleva su número viejo y
                // así no se confunde con el nuevo de la de al lado.
                style: _mono.copyWith(
                  fontSize: 11,
                  color: marker.isEmpty ? scheme.outline : markerColor,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 14,
            child: Text(marker, style: _mono.copyWith(color: markerColor)),
          ),
          Text(
            // Los tabuladores se pintan con anchos erráticos: se igualan a 4.
            line.text.replaceAll('\t', '    '),
            softWrap: false,
            style: _mono.copyWith(
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
              fontStyle: line.kind == DiffLineKind.note
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.additions, required this.deletions});

  final int additions;
  final int deletions;

  @override
  Widget build(BuildContext context) {
    if (additions == 0 && deletions == 0) return const SizedBox.shrink();
    final colors = MergedColors.of(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    return Text.rich(
      TextSpan(
        children: [
          if (additions > 0)
            TextSpan(
              text: '+$additions',
              style: TextStyle(color: colors.green.foreground),
            ),
          if (additions > 0 && deletions > 0) const TextSpan(text: ' '),
          if (deletions > 0)
            TextSpan(
              text: '−$deletions',
              style: TextStyle(color: colors.red.foreground),
            ),
        ],
      ),
      style: style,
    );
  }
}

/// Aviso en ámbar, con salida a GitLab si hay adónde ir.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.webUrl,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final String text;
  final String? webUrl;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tone = MergedColors.of(context).amber;
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: tone.foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tone.foreground,
                ),
              ),
            ),
            if (webUrl != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: tone.foreground),
                onPressed: () => openInGitlab(context, webUrl),
                child: const Text('Ver en GitLab'),
              ),
          ],
        ),
      ),
    );
  }
}
