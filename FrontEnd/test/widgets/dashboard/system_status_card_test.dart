// FrontEnd/test/widgets/dashboard/system_status_card_test.dart
//
// The card must be honest: green "Online" only when reachable, red
// "Unreachable" otherwise, and it must NEVER render the word "Translation"
// (this product does transliteration).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/models/system_health.dart';
import 'package:romasubai_frontend/widgets/dashboard/system_status_card.dart';

Widget _host(SystemHealth health) {
  return MaterialApp(
    theme: buildBaseTheme(false),
    home: Scaffold(body: SystemStatusCard(health: health)),
  );
}

void main() {
  testWidgets('reachable shows Online and the configured models', (tester) async {
    await tester.pumpWidget(_host(const SystemHealth(
      reachable: true,
      whisperModel: 'whisper-large-v3-turbo',
      transliterationModel: 'facebook/m2m100_418M',
      device: 'cuda',
    )));
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('facebook/m2m100_418M · cuda'), findsOneWidget);
  });

  testWidgets('unreachable shows the red Unreachable state', (tester) async {
    await tester.pumpWidget(_host(const SystemHealth.unreachable()));
    expect(find.text('Unreachable'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('never renders the word Translation', (tester) async {
    await tester.pumpWidget(_host(const SystemHealth(
      reachable: true,
      whisperModel: 'medium',
      transliterationModel: 'm2m100',
      device: 'cpu',
    )));
    expect(find.textContaining('Translation'), findsNothing);
    expect(find.text('Transliteration'), findsOneWidget);
  });
}
