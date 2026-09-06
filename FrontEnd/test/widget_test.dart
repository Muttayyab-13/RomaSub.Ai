// FrontEnd/test/widget_test.dart
//
// Smoke test: MyApp is a ConsumerWidget that reads themeProvider in build(),
// so it must be pumped inside a ProviderScope. This replaces the flutter
// create counter template, which referenced a counter this app never had.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/main.dart';

void main() {
  testWidgets('MyApp builds a MaterialApp inside a ProviderScope', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    // Pump for 2 seconds to allow SplashScreen timer to complete
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
