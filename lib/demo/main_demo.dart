import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/providers.dart';
import 'demo_repository.dart';

// App con datos ficticios, sin login ni red, para revisar la interfaz.
// flutter run -d chrome -t lib/demo/main_demo.dart
void main() {
  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) async => true),
        gitlabRepositoryProvider.overrideWithValue(DemoRepository()),
      ],
      child: const MergedApp(),
    ),
  );
}
