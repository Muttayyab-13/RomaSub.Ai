// test/widgets/projects/projects_table_test.dart
//
// The projects table renders only real per-project fields (icon by is_video,
// name, filename, duration with --:-- fallback, segment count, last-edited) and
// fires onTap with the tapped project. It must never render a Status column or
// the word "Translation".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/projects/projects_table.dart';

final _rows = <Map<String, dynamic>>[
  {
    'file_id': 'f1',
    'project_name': 'Interview_Raw_01',
    'original_filename': 'Interview_Raw_01.mp4',
    'is_video': true,
    'segment_count': 842,
    // Chosen so formatDuration(...) doesn't collide with the '45:12' literal
    // asserted absent below (2712s would format to exactly '45:12').
    'file_duration': 3661,
    'updated_at': '2026-07-20T10:24:00',
  },
  {
    'file_id': 'f2',
    'project_name': 'Podcast_Ep12',
    'original_filename': 'Podcast_Ep12.mp3',
    'is_video': false,
    'segment_count': 45,
    'file_duration': null,
    'updated_at': '2026-07-19T09:00:00',
  },
];

Widget _host({ValueChanged<Map<String, dynamic>>? onTap}) => MaterialApp(
  theme: buildBaseTheme(false),
  home: Scaffold(
    body: ProjectsTable(projects: _rows, onProjectTap: onTap ?? (_) {}),
  ),
);

void main() {
  testWidgets('renders names, filenames, segment counts', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Interview_Raw_01'), findsOneWidget);
    expect(find.text('Podcast_Ep12.mp3'), findsOneWidget);
    expect(find.text('842'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
  });

  testWidgets('null duration shows the --:-- placeholder', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('--:--'), findsOneWidget); // the audio row
    expect(find.text('45:12'), findsNothing);
  });

  testWidgets('video vs audio icon by is_video', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_outlined), findsOneWidget);
  });

  testWidgets('tapping a row fires onProjectTap with that project', (
    tester,
  ) async {
    Map<String, dynamic>? tapped;
    await tester.pumpWidget(_host(onTap: (p) => tapped = p));
    await tester.tap(find.text('Interview_Raw_01'));
    expect(tapped?['file_id'], 'f1');
  });

  testWidgets('no Status column, never "Translation"', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Status'), findsNothing);
    expect(find.textContaining('Translation'), findsNothing);
  });
}
