import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// Por qué no se pudo iniciar sesión, en términos que la UI pueda usar.
enum AuthFailureKind {
  /// El usuario cerró el navegador. No es un fallo: es una decisión suya.
  cancelled,

  /// No se pudo llegar a gitlab.com.
  network,

  /// GitLab respondió, pero rechazó la petición (client id, redirect, scopes).
  rejected,

  unknown,
}

/// Fallo de autenticación ya traducido, para no enseñar en el login el
/// `toString()` de la excepción.
class AuthFailure {
  const AuthFailure({
    required this.kind,
    required this.title,
    required this.message,
    this.detail,
  });

  final AuthFailureKind kind;

  /// Frase corta para encabezar.
  final String title;

  /// Explicación en una o dos líneas, en lenguaje de usuario.
  final String message;

  /// Texto técnico original, para el desplegable de detalle. Nunca es lo
  /// primero que ve el usuario.
  final String? detail;

  /// Cancelar no es un error: la UI lo trata en tono neutro, no en rojo.
  bool get isUserChoice => kind == AuthFailureKind.cancelled;

  /// Reintentar solo tiene sentido si el problema puede haber cambiado.
  bool get canRetry => kind != AuthFailureKind.rejected;

  factory AuthFailure.from(Object error) {
    final detail = error.toString();

    if (error is FlutterAppAuthUserCancelledException) {
      return AuthFailure(
        kind: AuthFailureKind.cancelled,
        title: 'Inicio de sesión cancelado',
        message:
            'Cerraste la ventana de GitLab antes de terminar. '
            'Puedes intentarlo de nuevo cuando quieras.',
        detail: detail,
      );
    }

    if (error is PlatformException) {
      if (_looksLikeNetwork(error)) {
        return AuthFailure(
          kind: AuthFailureKind.network,
          title: 'Sin conexión con GitLab',
          message:
              'No se pudo contactar con gitlab.com. Revisa tu conexión '
              'a internet e inténtalo otra vez.',
          detail: detail,
        );
      }
      if (error.code == 'authorize_and_exchange_code_failed' ||
          error.code == 'token_failed') {
        return AuthFailure(
          kind: AuthFailureKind.rejected,
          title: 'GitLab rechazó el inicio de sesión',
          message:
              'La aplicación no pudo autenticarse. Puede que su '
              'configuración en GitLab haya cambiado.',
          detail: detail,
        );
      }
    }

    return AuthFailure(
      kind: AuthFailureKind.unknown,
      title: 'No se pudo iniciar sesión',
      message: 'Ocurrió un problema inesperado. Inténtalo de nuevo.',
      detail: detail,
    );
  }

  /// El fallo de red llega envuelto distinto según plataforma y momento: se
  /// reconoce por el código y, si no, por el mensaje.
  static bool _looksLikeNetwork(PlatformException error) {
    if (error.code == 'discovery_failed') return true;
    final text = '${error.message ?? ''} ${error.details ?? ''}'.toLowerCase();
    return text.contains('network error') ||
        text.contains('unable to resolve host') ||
        text.contains('failed to connect') ||
        text.contains('timeout');
  }
}
