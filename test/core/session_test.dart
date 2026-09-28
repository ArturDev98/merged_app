import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/api/gitlab_client.dart';
import 'package:merged_app/core/providers.dart';

void main() {
  // Era el fallo tras iniciar sesión: perfil, actividad y proyectos seguían en
  // el error que dieron sin sesión.
  test('al iniciar sesión, los datos se vuelven a pedir', () async {
    var loggedIn = false;
    final container = ProviderContainer(
      overrides: [sessionProvider.overrideWith((ref) async => loggedIn)],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.future);
    final before = container.read(gitlabRepositoryProvider);

    loggedIn = true;
    container.invalidate(sessionProvider);
    await container.read(sessionProvider.future);

    expect(container.read(gitlabRepositoryProvider), isNot(same(before)));
  });

  test('la sesión caducada se reconoce aunque llegue envuelta', () {
    final wrapped = DioException(
      requestOptions: RequestOptions(path: '/user'),
      type: DioExceptionType.cancel,
      error: const SessionExpiredException(),
    );

    expect(isSessionExpired(const SessionExpiredException()), isTrue);
    expect(isSessionExpired(wrapped), isTrue);
    expect(
      isSessionExpired(
        DioException(
          requestOptions: RequestOptions(path: '/user'),
          type: DioExceptionType.connectionError,
        ),
      ),
      isFalse,
    );
  });
}
