// Smoke test de arranque: verifica que la app levanta y, sin sesión guardada,
// aterriza en el login.
//
// AuthService toca flutter_secure_storage, que en un test de widget no tiene
// implementación nativa detrás. Interceptamos su MethodChannel y respondemos
// null a todo, que es exactamente el caso "no hay nada guardado".

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merged_app/app.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('sin sesión guardada muestra el login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MergedApp()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión con GitLab'), findsOneWidget);
    expect(find.text('Tu GitLab, resumido'), findsOneWidget);
  });
}
