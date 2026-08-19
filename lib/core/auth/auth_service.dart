import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de autenticación contra GitLab usando OAuth2 + PKCE.
/// No usa Client Secret: la app es pública (no confidencial), por lo que
/// PKCE garantiza la seguridad del intercambio del authorization code
/// sin necesidad de un backend intermediario.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // TODO: reemplaza esto por tu Client ID real de GitLab.
  static const String _clientId =
      'f9192e195fbe00cee1b1ec0df918b183af0a648578aec3c040d1aa519e2338a8';

  static const String _redirectUri = 'dev.merged.app://callback';
  static const String _discoveryUrl =
      'https://gitlab.com/.well-known/openid-configuration';

  static const _keyAccessToken = 'gl_access_token';
  static const _keyRefreshToken = 'gl_refresh_token';
  static const _keyExpiry = 'gl_expiry';

  /// Último error capturado durante login/refresh, solo para debugging.
  /// En producción esto se reemplaza por un logger real, no se muestra
  /// crudo al usuario final.
  String? lastError;

  /// Lanza el flujo de login: abre el navegador/webview del sistema,
  /// el usuario se autentica en GitLab, y al volver obtenemos los tokens.
  Future<bool> login() async {
    lastError = null;
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          discoveryUrl: _discoveryUrl,
          scopes: ['read_api', 'read_user'],
        ),
      );

      if (result.accessToken == null) {
        lastError = 'La respuesta de GitLab no incluyó un access token.';
        return false;
      }

      await _persistTokens(result);
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<void> _persistTokens(TokenResponse result) async {
    await _storage.write(key: _keyAccessToken, value: result.accessToken);
    if (result.refreshToken != null) {
      await _storage.write(
        key: _keyRefreshToken,
        value: result.refreshToken,
      );
    }
    if (result.accessTokenExpirationDateTime != null) {
      await _storage.write(
        key: _keyExpiry,
        value: result.accessTokenExpirationDateTime!.toIso8601String(),
      );
    }
  }

  Future<String?> getValidAccessToken() async {
    final expiryStr = await _storage.read(key: _keyExpiry);
    final accessToken = await _storage.read(key: _keyAccessToken);

    if (accessToken == null) return null;

    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final isExpired = expiry == null ||
        expiry.isBefore(DateTime.now().add(const Duration(seconds: 30)));

    if (!isExpired) return accessToken;

    return _refreshAccessToken();
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) return null;

    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          discoveryUrl: _discoveryUrl,
          refreshToken: refreshToken,
          grantType: 'refresh_token',
          scopes: ['read_api', 'read_user'],
        ),
      );

      if (result.accessToken == null) {
        await logout();
        return null;
      }

      await _persistTokens(result);
      return result.accessToken;
    } catch (e) {
      lastError = e.toString();
      await logout();
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    return (await getValidAccessToken()) != null;
  }

  Future<void> logout() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyExpiry);
  }
}