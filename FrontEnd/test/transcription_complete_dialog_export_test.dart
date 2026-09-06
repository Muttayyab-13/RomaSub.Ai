// FrontEnd/test/transcription_complete_dialog_export_test.dart
//
// The "Transcription Complete!" dialog must offer the full export set, not
// just SRT — mirroring the editor toolbar. Text formats are always available;
// captioned-video exports appear only for video sources.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/widgets/dialogs/transcription_complete_dialog.dart';

Widget _host({required bool isVideo}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: TranscriptionCompleteDialog(
          filename: 'clip.mp4',
          duration: '00:31',
          segmentCount: 8,
          language: 'Urdu',
          previewText: 'preview',
          romanUrduPreviewText: 'preview',
          isVideo: isVideo,
          onExport: (_) {},
          onExportVideo: (_) {},
          onViewDetails: () {},
          onEdit: () {},
        ),
      ),
    ),
  );
}

Future<void> _openExportMenu(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Export'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export menu always offers SRT/VTT/TXT', (tester) async {
    await tester.pumpWidget(_host(isVideo: false));
    await _openExportMenu(tester);

    expect(find.text('Export as SRT'), findsOneWidget);
    expect(find.text('Export as VTT'), findsOneWidget);
    expect(find.text('Export as TXT'), findsOneWidget);
  });

  testWidgets('video sources also offer captioned-video export', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isVideo: true));
    await _openExportMenu(tester);

    expect(find.text('Video — burned-in captions'), findsOneWidget);
    expect(find.text('Video — toggleable captions'), findsOneWidget);
  });

  testWidgets('audio sources hide captioned-video export', (tester) async {
    await tester.pumpWidget(_host(isVideo: false));
    await _openExportMenu(tester);

    expect(find.text('Video — burned-in captions'), findsNothing);
    expect(find.text('Video — toggleable captions'), findsNothing);
  });
}
