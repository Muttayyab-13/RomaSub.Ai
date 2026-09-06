// FrontEnd/test/widgets/dashboard/system_status_card_test.dart
//
// The card must be honest: green "Online" only when reachable, red
// "Unreachable" otherwise, and it must NEVER render the word "Translation"
// (this product does transliteration).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_palette.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/models/system_health.dart';
import 'package:romasubai_frontend/widgets/dashboard/system_status_card.dart';

Widget _host(SystemHealth health, {double? width, bool isDark = false}) {
  final card = SystemStatusCard(health: health);
  return MaterialApp(
    theme: buildBaseTheme(isDark),
    home: Scaffold(
      body: Center(
        child: width == null ? card : SizedBox(width: width, child: card),
      ),
    ),
  );
}

/// The one 8×8 circular status dot in the card.
Color? _dotColor(WidgetTester tester) {
  final dot = tester.widget<Container>(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  return (dot.decoration as BoxDecoration).color;
}

const _reachable = SystemHealth(
  reachable: true,
  whisperModel: 'whisper',
  transliterationModel: 'm2m100',
  device: 'cpu',
);

void main() {
  testWidgets('reachable shows Online and the configured models', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SystemHealth(
          reachable: true,
          whisperModel: 'whisper-large-v3-turbo',
          transliterationModel: 'facebook/m2m100_418M',
          device: 'cuda',
        ),
      ),
    );
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('facebook/m2m100_418M · cuda'), findsOneWidget);
  });

  testWidgets('unreachable shows the red Unreachable state', (tester) async {
    await tester.pumpWidget(_host(const SystemHealth.unreachable()));
    expect(find.text('Unreachable'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('header fits at the 320px rail width when Unreachable', (
    tester,
  ) async {
    // The rail is a fixed 320px column; "Unreachable" is longer than "Online",
    // so the header row must not overflow at that width.
    await tester.pumpWidget(
      _host(const SystemHealth.unreachable(), width: 320),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Unreachable'), findsOneWidget);
  });

  testWidgets('online dot uses the light success token in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_reachable));
    expect(_dotColor(tester), AppPalette.success);
  });

  testWidgets('online dot uses the dark success token in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_reachable, isDark: true));
    expect(_dotColor(tester), AppPalette.successDark);
  });

  testWidgets('checking state: neutral "Checking…" with em-dash models', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SystemStatusCard.checking())),
    );
    expect(find.text('Checking…'), findsOneWidget);
    // Must not assert a backend state it hasn't verified yet.
    expect(find.text('Online'), findsNothing);
    expect(find.text('Unreachable'), findsNothing);
    // Both model rows fall back to the em-dash placeholder.
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('never renders the word Translation', (tester) async {
    await tester.pumpWidget(
      _host(
        const SystemHealth(
          reachable: true,
          whisperModel: 'medium',
          transliterationModel: 'm2m100',
          device: 'cpu',
        ),
      ),
    );
    expect(find.textContaining('Translation'), findsNothing);
    expect(find.text('Transliteration'), findsOneWidget);
  });
}
