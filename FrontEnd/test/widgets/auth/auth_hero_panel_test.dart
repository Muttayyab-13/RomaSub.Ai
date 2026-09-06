// test/widgets/auth/auth_hero_panel_test.dart
//
// The hero panel is a single full-bleed image (the brand artwork). It must fill
// whatever box the split/stack layout hands it — full panel or slim compact
// band — without overflowing, and fall back to the navy backdrop if the asset
// can't be decoded.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/widgets/auth/auth_hero_panel.dart';

Future<void> _pumpAt(
  WidgetTester tester,
  Size size, {
  bool compact = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.fromSize(
          size: size,
          child: AuthHeroPanel(compact: compact),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('full panel fills a normal split width without overflow', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(580, 820));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('full panel fills the narrowest split without overflow', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(409, 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact band fills without overflow', (tester) async {
    await _pumpAt(tester, const Size(360, 168), compact: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
