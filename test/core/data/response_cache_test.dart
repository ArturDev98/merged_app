import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/data/response_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ResponseCache', () {
    test('devuelve lo guardado con su fecha', () async {
      final cache = ResponseCache();
      await cache.write('k', [
        {'id': 1, 'name': 'uno'},
      ]);

      final read = await cache.read('k');

      expect(read, isNotNull);
      expect(read!.data.single['name'], 'uno');
      expect(DateTime.now().difference(read.savedAt).inSeconds, lessThan(5));
    });

    test('una clave sin guardar devuelve null, no una lista vacía', () async {
      // Importa la distinción: vacío significaría "no hay datos" y null
      // significa "no hay caché", que llevan a comportamientos distintos.
      expect(await ResponseCache().read('inexistente'), isNull);
    });

    test('un contenido corrupto no revienta, se ignora', () async {
      SharedPreferences.setMockInitialValues({'cache_v1_k': 'esto no es json'});

      expect(await ResponseCache().read('k'), isNull);
    });

    test('servingFrom se queda con la fecha más antigua', () async {
      final cache = ResponseCache();
      final viejo = DateTime(2026, 8, 1);
      final nuevo = DateTime(2026, 8, 19);

      cache.markServedFromCache(nuevo);
      cache.markServedFromCache(viejo);

      // Lo que el usuario ve es tan viejo como su parte más vieja.
      expect(cache.servingFrom.value, viejo);
    });

    test('markFresh borra el aviso de datos guardados', () async {
      final cache = ResponseCache()..markServedFromCache(DateTime(2026, 8, 1));
      expect(cache.servingFrom.value, isNotNull);

      cache.markFresh();

      expect(cache.servingFrom.value, isNull);
    });

    test('clear borra solo las claves de la caché', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final cache = ResponseCache();
      await cache.write('k', [
        {'a': 1},
      ]);

      await cache.clear();

      expect(await cache.read('k'), isNull);
      final prefs = await SharedPreferences.getInstance();
      // La preferencia de tema no es caché y debe sobrevivir.
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });
}
