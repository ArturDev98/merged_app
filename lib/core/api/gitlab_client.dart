import 'package:dio/dio.dart';

import '../auth/auth_service.dart';

/// Se lanza cuando no hay sesión utilizable y no se pudo refrescar.
/// La UI debe reaccionar mandando al usuario de vuelta al login.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'La sesión de GitLab expiró o fue revocada.';
}

/// Una página de resultados de la API, con la info de paginación que GitLab
/// devuelve en cabeceras (no en el cuerpo).
class Page<T> {
  const Page({required this.items, this.nextPage, this.total});

  final List<T> items;

  /// Cabecera `x-next-page`. Null si esta es la última página.
  final int? nextPage;

  /// Cabecera `x-total`. GitLab la omite cuando el conteo sería caro, así que
  /// nunca hay que asumir que viene.
  final int? total;

  bool get hasMore => nextPage != null;
}

/// Cliente HTTP contra la API v4 de GitLab.
///
/// Solo lectura: los scopes de la app son `read_api` + `read_user`.
class GitlabClient {
  GitlabClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        // Dejamos pasar los 4xx para poder distinguir 401 de 403 y dar un
        // mensaje útil, en vez de que dio los convierta todos en excepción.
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(AuthService.instance, _dio));
  }

  static final GitlabClient instance = GitlabClient._internal();

  static const String baseUrl = 'https://gitlab.com/api/v4';

  late final Dio _dio;

  /// GET de un objeto único (por ejemplo `/user`).
  Future<T> getOne<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    final response = await _dio.get<dynamic>(path, queryParameters: query);
    _ensureOk(response);
    return parse(response.data as Map<String, dynamic>);
  }

  /// GET de una colección paginada.
  Future<Page<T>> getPage<T>(
    String path, {
    Map<String, dynamic>? query,
    int page = 1,
    int perPage = 20,
    required T Function(Map<String, dynamic>) parse,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: {
        ...?query,
        'page': page,
        'per_page': perPage,
      },
    );
    _ensureOk(response);

    final raw = response.data as List<dynamic>;
    return Page<T>(
      items: raw
          .map((e) => parse(e as Map<String, dynamic>))
          .toList(growable: false),
      nextPage: _intHeader(response, 'x-next-page'),
      total: _intHeader(response, 'x-total'),
    );
  }

  void _ensureOk(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status == 200) return;
    if (status == 401) throw const SessionExpiredException();
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'GitLab respondió $status en ${response.requestOptions.path}',
    );
  }

  /// GitLab manda las cabeceras de paginación vacías (no ausentes) cuando no
  /// hay siguiente página, así que un parse directo devolvería null igualmente,
  /// pero conviene ser explícito.
  static int? _intHeader(Response<dynamic> response, String name) {
    final value = response.headers.value(name);
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._auth, this._dio);

  final AuthService _auth;
  final Dio _dio;

  /// Marca en la request para no entrar en bucle de reintentos.
  static const String _retriedKey = 'merged.auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _auth.getValidAccessToken();
    if (token == null) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const SessionExpiredException(),
        ),
        true,
      );
    }
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;
    if (!isUnauthorized || alreadyRetried) return handler.next(err);

    // Un 401 con el token aún vigente en el reloj significa que lo revocaron
    // en el servidor: hay que forzar el refresh, no fiarse de la expiración.
    final token = await _auth.refreshAccessToken();
    if (token == null) {
      await _auth.logout();
      return handler.next(err);
    }

    final retry = err.requestOptions..extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(retry));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
