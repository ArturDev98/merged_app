import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/theme/app_theme.dart';

void main() {
  // Estos colores se pintan encima del fondo: uno opaco tapaba el chip activo y
  // dejaba su texto blanco sobre casi blanco.
  test('los resaltados de interacción son translúcidos en los dos temas', () {
    for (final brightness in Brightness.values) {
      final theme = buildTheme(brightness);
      for (final color in [
        theme.hoverColor,
        theme.focusColor,
        theme.highlightColor,
        theme.splashColor,
      ]) {
        expect(color.a, lessThan(0.5), reason: '$brightness: $color');
      }
    }
  });
}
