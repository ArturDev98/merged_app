import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teal de la marca: el mismo del icono y del splash.
const brandTeal = Color(0xFF00695C);

/// Fuente para código, SHAs y detalles técnicos. Va incluida en la app: la
/// "monospace" del sistema no existe en web y en Android varía por marca.
const monoFontFamily = 'JetBrainsMono';

// La misma que el splash oscuro (values-night/colors.xml).
const _darkSurface = Color(0xFF0E1917);

/// Fondo y primer plano de una categoría: tipo de evento, estado, etc.
@immutable
class Tone {
  const Tone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static Tone lerp(Tone a, Tone b, double t) => Tone(
    Color.lerp(a.background, b.background, t)!,
    Color.lerp(a.foreground, b.foreground, t)!,
  );
}

/// Colores propios que el ColorScheme no modela. Los tonos van por color;
/// qué color toca a cada cosa se decide en las etiquetas.
@immutable
class MergedColors extends ThemeExtension<MergedColors> {
  const MergedColors({
    required this.header,
    required this.onHeader,
    required this.onHeaderMuted,
    required this.badge,
    required this.onBadge,
    required this.teal,
    required this.purple,
    required this.amber,
    required this.blue,
    required this.coral,
    required this.green,
    required this.red,
    required this.neutral,
  });

  final Color header;
  final Color onHeader;
  final Color onHeaderMuted;
  final Color badge;
  final Color onBadge;

  final Tone teal;
  final Tone purple;
  final Tone amber;
  final Tone blue;
  final Tone coral;
  final Tone green;
  final Tone red;
  final Tone neutral;

  static MergedColors of(BuildContext context) =>
      Theme.of(context).extension<MergedColors>()!;

  static const light = MergedColors(
    header: brandTeal,
    onHeader: Colors.white,
    onHeaderMuted: Color(0xFFB7E4DC),
    badge: Color(0xFFFFB547),
    onBadge: Color(0xFF4A2A00),
    teal: Tone(Color(0xFFE1F5EE), Color(0xFF0F6E56)),
    purple: Tone(Color(0xFFEEEDFE), Color(0xFF534AB7)),
    amber: Tone(Color(0xFFFAEEDA), Color(0xFF854F0B)),
    blue: Tone(Color(0xFFE6F1FB), Color(0xFF185FA5)),
    coral: Tone(Color(0xFFFAECE7), Color(0xFF993C1D)),
    green: Tone(Color(0xFFEAF3DE), Color(0xFF3B6D11)),
    red: Tone(Color(0xFFFCEBEB), Color(0xFFA32D2D)),
    neutral: Tone(Color(0xFFEEF3F2), Color(0xFF4F5F5B)),
  );

  static const dark = MergedColors(
    header: Color(0xFF12403A),
    onHeader: Colors.white,
    onHeaderMuted: Color(0xFF9FE1CB),
    badge: Color(0xFFFFB547),
    onBadge: Color(0xFF4A2A00),
    teal: Tone(Color(0xFF085041), Color(0xFF9FE1CB)),
    purple: Tone(Color(0xFF3C3489), Color(0xFFCECBF6)),
    amber: Tone(Color(0xFF633806), Color(0xFFFAC775)),
    blue: Tone(Color(0xFF0C447C), Color(0xFFB5D4F4)),
    coral: Tone(Color(0xFF712B13), Color(0xFFF5C4B3)),
    green: Tone(Color(0xFF27500A), Color(0xFFC0DD97)),
    red: Tone(Color(0xFF791F1F), Color(0xFFF7C1C1)),
    neutral: Tone(Color(0xFF1E2F2B), Color(0xFFB9C9C5)),
  );

  @override
  MergedColors copyWith() => this;

  @override
  MergedColors lerp(MergedColors? other, double t) {
    if (other == null) return this;
    return MergedColors(
      header: Color.lerp(header, other.header, t)!,
      onHeader: Color.lerp(onHeader, other.onHeader, t)!,
      onHeaderMuted: Color.lerp(onHeaderMuted, other.onHeaderMuted, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      onBadge: Color.lerp(onBadge, other.onBadge, t)!,
      teal: Tone.lerp(teal, other.teal, t),
      purple: Tone.lerp(purple, other.purple, t),
      amber: Tone.lerp(amber, other.amber, t),
      blue: Tone.lerp(blue, other.blue, t),
      coral: Tone.lerp(coral, other.coral, t),
      green: Tone.lerp(green, other.green, t),
      red: Tone.lerp(red, other.red, t),
      neutral: Tone.lerp(neutral, other.neutral, t),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: brandTeal,
    brightness: brightness,
  );

  // Superficies fijadas a mano: las del seed salen grisáceas y no casan con el
  // teal de la cabecera.
  final scheme = dark
      ? seeded.copyWith(
          primary: const Color(0xFF5DCAA5),
          onPrimary: const Color(0xFF04342C),
          primaryContainer: const Color(0xFF085041),
          onPrimaryContainer: const Color(0xFF9FE1CB),
          surface: _darkSurface,
          surfaceContainerLowest: const Color(0xFF09120F),
          surfaceContainerLow: const Color(0xFF14211E),
          surfaceContainer: const Color(0xFF182724),
          surfaceContainerHigh: const Color(0xFF1E2F2B),
          surfaceContainerHighest: const Color(0xFF253834),
        )
      : seeded.copyWith(
          primary: brandTeal,
          onPrimary: Colors.white,
          surface: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF4F8F7),
          surfaceContainer: const Color(0xFFEEF3F2),
          surfaceContainerHigh: const Color(0xFFE8EFED),
          surfaceContainerHighest: const Color(0xFFE1E9E7),
        );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Outfit',
  );
  // base.textTheme aún no trae tamaños (Theme.of los añade después): sin
  // fundirlos aquí, los estilos de AppBar y ListTile salían a 14 px.
  final text = base.typography.englishLike.merge(base.textTheme);
  const semibold = FontWeight.w600;
  // Outfit tiene la x baja: a 12 y 11 px (los de Material) cuesta leerla.
  final bodySmall = text.bodySmall?.copyWith(fontSize: 13);
  final labelSmall = text.labelSmall?.copyWith(fontSize: 12);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    // En claro, el resaltado de hover y pulsación es teal y no gris. Siempre
    // translúcido: se pinta encima del fondo, y opaco tapaba el chip activo.
    hoverColor: dark ? null : const Color(0xFF1D9E75).withValues(alpha: 0.12),
    focusColor: dark ? null : brandTeal.withValues(alpha: 0.12),
    highlightColor: dark ? null : brandTeal.withValues(alpha: 0.12),
    splashColor: dark ? null : brandTeal.withValues(alpha: 0.12),
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: semibold),
      titleMedium: text.titleMedium?.copyWith(fontWeight: semibold),
      titleSmall: text.titleSmall?.copyWith(fontWeight: semibold),
      labelLarge: text.labelLarge?.copyWith(fontWeight: semibold),
      bodySmall: bodySmall,
      labelSmall: labelSmall,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: semibold,
        color: scheme.onSurface,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      minLeadingWidth: 38,
      horizontalTitleGap: 14,
      titleTextStyle: text.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge?.copyWith(fontWeight: semibold),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    extensions: [dark ? MergedColors.dark : MergedColors.light],
  );
}

/// La licencia OFL exige acompañar a cada fuente allí donde se reparta.
void registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Outfit', 'JetBrainsMono']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
}
