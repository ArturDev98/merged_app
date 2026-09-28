import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Icono sobre un cuadrado redondeado del color de su categoría.
class ToneIcon extends StatelessWidget {
  const ToneIcon({
    super.key,
    required IconData this.icon,
    required this.tone,
    this.size = 38,
  }) : letter = null;

  /// Variante con una inicial en lugar de icono (proyectos sin avatar).
  const ToneIcon.letter({
    super.key,
    required String this.letter,
    required this.tone,
    this.size = 38,
  }) : icon = null;

  final IconData? icon;
  final String? letter;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: tone.foreground)
          : Text(
              letter!,
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w600,
                color: tone.foreground,
              ),
            ),
    );
  }
}

/// Etiqueta compacta con icono, del color de su categoría.
class TonePill extends StatelessWidget {
  const TonePill({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La marca de Merged: dos ramas que confluyen en una.
///
/// Reproduce el vector de `ic_launcher_foreground.xml`; si cambia uno, cambia
/// el otro.
class MergedMark extends StatelessWidget {
  const MergedMark({super.key, this.size = 96, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter(color));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Mismas coordenadas que el vector: una caja de 72 con la marca centrada.
    canvas.scale(size.width / 72);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final branches = Path()
      ..moveTo(22, 58)
      ..lineTo(22, 40)
      ..quadraticBezierTo(22, 30, 32, 26)
      ..lineTo(36, 24)
      ..moveTo(50, 58)
      ..lineTo(50, 40)
      ..quadraticBezierTo(50, 30, 40, 26)
      ..lineTo(36, 24)
      ..moveTo(36, 24)
      ..lineTo(36, 12);
    canvas.drawPath(branches, stroke);

    final fill = Paint()..color = color;
    canvas.drawCircle(const Offset(22, 52), 7, fill);
    canvas.drawCircle(const Offset(50, 52), 7, fill);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
