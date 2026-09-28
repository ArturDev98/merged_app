import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/shared/relative_time.dart';

void main() {
  // Domingo 27 de septiembre de 2026, a media mañana.
  final now = DateTime(2026, 9, 27, 10);

  group('dayLabel', () {
    test('hoy y ayer se nombran por su nombre', () {
      expect(dayLabel(DateTime(2026, 9, 27, 0, 5), now: now), 'Hoy');
      expect(dayLabel(DateTime(2026, 9, 26, 23, 59), now: now), 'Ayer');
    });

    test('el resto lleva día de la semana y fecha corta', () {
      expect(dayLabel(DateTime(2026, 9, 24, 12), now: now), 'Jueves 24 sep');
    });

    test('otro año lo dice, para no confundir diciembre con el actual', () {
      expect(
        dayLabel(DateTime(2025, 12, 31, 12), now: now),
        'Miércoles 31 dic 2025',
      );
    });
  });

  test('clockTime rellena con ceros', () {
    expect(clockTime(DateTime(2026, 9, 27, 9, 5)), '09:05');
  });
}
