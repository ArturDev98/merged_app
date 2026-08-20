import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merged_app/core/auth/auth_failure.dart';

void main() {
  group('AuthFailure', () {
    test('cancelar no se trata como error', () {
      final failure = AuthFailure.from(
        FlutterAppAuthUserCancelledException(
          code: '0',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            type: '0',
            code: '1',
            errorDescription: 'User cancelled flow',
          ),
        ),
      );

      expect(failure.kind, AuthFailureKind.cancelled);
      expect(failure.isUserChoice, isTrue);
      expect(failure.title, 'Inicio de sesión cancelado');
      // Lo que ve el usuario no puede ser el volcado de la excepción.
      expect(failure.message, isNot(contains('platformErrorDetails')));
      // Pero el detalle técnico sigue disponible, plegado.
      expect(failure.detail, contains('FlutterAppAuthUserCancelledException'));
    });

    test('reconoce la falta de conexión por el código de descubrimiento', () {
      final failure = AuthFailure.from(
        PlatformException(
          code: 'discovery_failed',
          message: 'Error retrieving discovery document',
        ),
      );

      expect(failure.kind, AuthFailureKind.network);
      expect(failure.title, 'Sin conexión con GitLab');
    });

    test('reconoce la falta de conexión por el mensaje de DNS', () {
      // Texto exacto que devolvió el dispositivo real sin internet.
      final failure = AuthFailure.from(
        PlatformException(
          code: 'otro_codigo',
          message: "Unable to resolve host 'gitlab.com': No address associated",
        ),
      );

      expect(failure.kind, AuthFailureKind.network);
    });

    test('un rechazo de GitLab no ofrece reintentar', () {
      final failure = AuthFailure.from(
        PlatformException(code: 'token_failed', message: 'invalid_client'),
      );

      expect(failure.kind, AuthFailureKind.rejected);
      expect(failure.canRetry, isFalse);
    });

    test('cualquier otra cosa cae en desconocido pero conserva el detalle', () {
      final failure = AuthFailure.from(StateError('algo raro'));

      expect(failure.kind, AuthFailureKind.unknown);
      expect(failure.detail, contains('algo raro'));
    });
  });
}
