// test/screens/projects/projects_screen_test.dart
//
// Pumps the real ProjectsScreen with a seeded projectsProvider. Verifies the
// "All Projects" title + count, that rows render through ProjectsTable, that
// search filters, and the honest-UI invariants (no Status column/badges, never
// "Translation"). Auth is neutralised with the never-completing storageService
// seam (see dashboard_screen_test.dart).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:romasubai_frontend/core/constants/app_strings.dart';
import 'package:romasubai_frontend/providers/library_providers.dart';
import 'package:romasubai_frontend/screens/projects/projects_screen.dart';
import 'package:romasubai_frontend/services/storage_service.dart';
import 'package:romasubai_frontend/widgets/projects/projects_table.dart';

final _projects = <Map<String, dynamic>>[
  {
    'file_id': 'f1',
    'project_name': 'Interview_Raw_01',
    'original_filename': 'Interview_Raw_01.mp4',
    'is_video': true,
    'segment_count': 842,
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

Future<void> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? projects,
  bool throwError = false,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final neverReady = Completer<StorageService>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWith((ref) => neverReady.future),
        projectsProvider.overrideWith((ref) async {
          if (throwError) throw Exception('boom');
          return projects ?? _projects;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: ProjectsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders title, count, and rows', (tester) async {
    await _pump(tester);
    expect(find.textContaining('All Projects'), findsOneWidget);
    expect(
      find.textContaining('total'),
      findsOneWidget,
    ); // count pill "2 total"
    expect(find.byType(ProjectsTable), findsOneWidget);
    expect(find.text('Interview_Raw_01'), findsOneWidget);
  });

  testWidgets('search filters the rows', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'Podcast');
    await tester.pumpAndSettle();
    expect(find.text('Podcast_Ep12'), findsOneWidget);
    expect(find.text('Interview_Raw_01'), findsNothing);
  });

  testWidgets('empty library shows the empty state', (tester) async {
    await _pump(tester, projects: const []);
    expect(find.byType(ProjectsTable), findsNothing);
    expect(find.text(AppStrings.projectsEmptyTitle), findsOneWidget);
  });

  testWidgets('honest UI: no Status column, never "Translation"', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Status'), findsNothing);
    expect(find.textContaining('Translation'), findsNothing);
  });

  testWidgets('provider error renders an honest error message', (tester) async {
    await _pump(tester, throwError: true);
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(find.byType(ProjectsTable), findsNothing);
  });
}
