import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';

void main() {
  registerFontLicense();
  runApp(const ProviderScope(child: MergedApp()));
}
