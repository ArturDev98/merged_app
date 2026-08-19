import 'package:flutter/material.dart';
import 'core/api/api_smoke_test.dart';
import 'core/auth/auth_service.dart';

void main() {
  runApp(const MergedApp());
}

class MergedApp extends StatelessWidget {
  const MergedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merged',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const LoginTestScreen(),
    );
  }
}

class LoginTestScreen extends StatefulWidget {
  const LoginTestScreen({super.key});

  @override
  State<LoginTestScreen> createState() => _LoginTestScreenState();
}

class _LoginTestScreenState extends State<LoginTestScreen> {
  bool _loading = false;
  bool _loggedIn = false;
  bool _running = false;
  String? _report;
  String? _tokenPreview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    setState(() => _loggedIn = loggedIn);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await AuthService.instance.login();

    if (!mounted) return;

    if (success) {
      final token = await AuthService.instance.getValidAccessToken();
      setState(() {
        _loggedIn = true;
        _loading = false;
        // Solo mostramos un preview corto del token, nunca el token completo en UI.
        _tokenPreview = token != null
            ? '${token.substring(0, 8)}... (${token.length} chars)'
            : null;
      });
    } else {
      setState(() {
        _loading = false;
        _error = AuthService.instance.lastError ??
            'Login falló o fue cancelado. Revisa el Client ID y el redirect URI.';
      });
    }
  }

  Future<void> _handleSmokeTest() async {
    setState(() {
      _running = true;
      _report = null;
    });
    final report = await runApiSmokeTest();
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _tokenPreview = null;
      _report = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merged — Test de Auth')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _loggedIn ? Icons.check_circle : Icons.lock_outline,
                size: 64,
                color: _loggedIn ? Colors.teal : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _loggedIn ? 'Sesión activa' : 'No autenticado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_tokenPreview != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Token: $_tokenPreview',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator()
              else if (_loggedIn)
                FilledButton.tonal(
                  onPressed: _handleLogout,
                  child: const Text('Cerrar sesión'),
                )
              else
                FilledButton(
                  onPressed: _handleLogin,
                  child: const Text('Iniciar sesión con GitLab'),
                ),
              if (_loggedIn && !_loading) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _running ? null : _handleSmokeTest,
                  child: Text(
                    _running ? 'Ejecutando…' : 'Ejecutar diagnóstico API',
                  ),
                ),
              ],
              if (_report != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _report!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}