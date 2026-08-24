import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que se guardó de una respuesta, con su fecha.
class CachedResponse {
  const CachedResponse({required this.data, required this.savedAt});

  final List<Map<String, dynamic>> data;
  final DateTime savedAt;
}

/// Guarda la última respuesta buena de cada consulta para poder abrir la app
/// sin conexión.
///
/// Almacena el JSON crudo, no los modelos: así un cambio en un modelo no
/// invalida lo ya guardado ni obliga a escribir serializadores en los dos
/// sentidos.
class ResponseCache {
  ResponseCache();

  static const String _prefix = 'cache_v1_';

  SharedPreferences? _prefs;

  /// Fecha de los datos que se están sirviendo desde disco, o null si todo lo
  /// que se ve viene de la red. La UI lo observa para avisar de que está
  /// mirando información guardada.
  final ValueNotifier<DateTime?> servingFrom = ValueNotifier(null);

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Se llama al empezar un refresco: hasta que algo falle, se asume que lo
  /// mostrado está fresco.
  void markFresh() => servingFrom.value = null;

  Future<void> write(String key, List<Map<String, dynamic>> data) async {
    try {
      final store = await _store;
      await store.setString(
        '$_prefix$key',
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Que no se pueda guardar en disco no debe romper una petición que sí
      // funcionó: la caché es una mejora, no un requisito.
    }
  }

  Future<CachedResponse?> read(String key) async {
    try {
      final store = await _store;
      final raw = store.getString('$_prefix$key');
      if (raw == null) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final list = decoded['data'];
      if (list is! List) return null;

      return CachedResponse(
        data: list.whereType<Map<String, dynamic>>().toList(growable: false),
        savedAt:
            DateTime.tryParse(decoded['saved_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  /// Registra que se está sirviendo información guardada. Se queda con la más
  /// antigua de la pantalla, que es la que marca la antigüedad real de lo que
  /// el usuario ve.
  void markServedFromCache(DateTime savedAt) {
    final current = servingFrom.value;
    if (current == null || savedAt.isBefore(current)) {
      servingFrom.value = savedAt;
    }
  }

  Future<void> clear() async {
    final store = await _store;
    for (final key in store.getKeys().where((k) => k.startsWith(_prefix))) {
      await store.remove(key);
    }
    servingFrom.value = null;
  }
}
