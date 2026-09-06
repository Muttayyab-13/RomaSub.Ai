// test/widgets/realtime/live_transcript_panel_test.dart
//
// Each transcript row shows a mono timecode, the Roman-Urdu line, and the real
// Urdu-script line — NOT an invented English translation. The current segment is
// highlighted. There is no "Translating…" affordance.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';
import 'package:romasubai_frontend/widgets/realtime/live_transcript_panel.dart';

List<EditableSegment> _segs() => [
  EditableSegment(
    id: 0,
    start: 75,
    end: 78,
    urduText: 'تو بنیادی طور پر',
    romanUrduText: 'Toh basically, humara approach kaafi straight-forward tha.',
  ),
  EditableSegment(
    id: 1,
    start: 83,
    end: 86,
    urduText: 'منصوبہ بندی ضروری ہے',
    romanUrduText: 'Planning is essential.',
  ),
];

Widget _host({int? current}) => MaterialApp(
  theme: buildBaseTheme(false),
  home: Scaffold(
    body: LiveTranscriptPanel(segments: _segs(), currentIndex: current),
  ),
);

void main() {
  testWidgets('renders roman-urdu + urdu-script lines and timecodes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(current: 0));
    expect(find.textContaining('Toh basically'), findsOneWidget);
    expect(
      find.text('تو بنیادی طور پر'),
      findsOneWidget,
    ); // real Urdu, not English
    expect(
      find.textContaining('01:15'),
      findsOneWidget,
    ); // 75s → mm:ss timecode
  });

  testWidgets('never shows English gloss or "Translating"', (tester) async {
    await tester.pumpWidget(_host(current: 0));
    expect(find.textContaining('Translating'), findsNothing);
    expect(find.textContaining('Translation'), findsNothing);
  });

  testWidgets('empty segments → waiting state, no rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBaseTheme(false),
        home: const Scaffold(
          body: LiveTranscriptPanel(segments: [], currentIndex: null),
        ),
      ),
    );
    expect(find.textContaining('Toh basically'), findsNothing);
  });
}
