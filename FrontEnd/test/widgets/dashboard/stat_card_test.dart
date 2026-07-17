// FrontEnd/test/widgets/dashboard/stat_card_test.dart
//
// StatCard renders a label and a value. `value` is nullable so the card can
// show a placeholder while its provider is still loading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/dashboard/stat_card.dart';

Widget _host({required String label, String? value, IconData icon = Icons.folder}) {
  return MaterialApp(
    theme: buildBaseTheme(false),
    home: Scaffold(
      body: StatCard(icon: icon, label: label, value: value),
    ),
  );
}

void main() {
  testWidgets('renders label and value', (tester) async {
    await tester.pumpWidget(_host(label: 'TOTAL PROJECTS', value: '142'));
    expect(find.text('TOTAL PROJECTS'), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
  });

  testWidgets('shows an em dash when value is null (loading)', (tester) async {
    await tester.pumpWidget(_host(label: 'EXPORTS', value: null));
    expect(find.text('EXPORTS'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
