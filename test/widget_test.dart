// Sin sesión guardada, la app arranca en el login. El canal de
// flutter_secure_storage responde null a todo: "no hay nada guardado".

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
