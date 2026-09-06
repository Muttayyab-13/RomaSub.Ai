// FrontEnd/test/screens/dashboard/dashboard_screen_test.dart
//
// Composition test for the redesigned DashboardScreen. Pumps the *real* screen
// (not just its child widgets) so we verify the wiring the widget-level tests
// can't: the greeting, the rail's real project/export counts, the honest
// system-status card, the empty state, dark mode, and the responsive layout.
//
// Auth is neutralised without a backend by overriding `storageServiceProvider`
// with a future that never completes: `authNotifierProvider` then falls back to
// its inert `_LoadingAuthNotifier` (null user, no network). The three data
// providers are overridden with seeded values, short-circuiting the API client.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:romasubai_frontend/core/constants/app_strings.dart';
import 'package:romasubai_frontend/models/system_health.dart';
import 'package:romasubai_frontend/providers/library_providers.dart';
import 'package:romasubai_frontend/screens/dashboard/dashboard_screen.dart';
import 'package:romasubai_frontend/services/storage_service.dart';
import 'package:romasubai_frontend/widgets/dashboard/stat_card.dart';

const _reachableHealth = SystemHealth(
  reachable: true,
  whisperModel: 'whisper-large-v3-turbo',
  transliterationModel: 'm2m100_418M',
  device: 'cpu',
);

final _sampleProjects = <Map<String, dynamic>>[
  {
    'file_id': 'f1',
    'project_name': 'Interview_Raw_01',
    'original_filename': 'Interview_Raw_01.mp4',
    'is_video': true,
    'file_duration': 2720,
    'created_at': '2026-07-17T10:42:00Z',
  },
  {
    'file_id': 'f2',
    'project_name': 'Podcast_Ep12',
    'original_filename': 'Podcast_Ep12.mp3',
    'is_video': false,
    'file_duration': 4325,
    'created_at': '2026-07-16T09:00:00Z',
  },
  {
    'file_id': 'f3',
    'project_name': 'Lecture_Notes',
    'original_filename': 'Lecture_Notes.mp4',
    'is_video': true,
    'file_duration': 600,
    'created_at': '2026-07-15T14:00:00Z',
  },
];

final _sampleExports = <Map<String, dynamic>>[
  {'export_id': 'e1'},
  {'export_id': 'e2'},
];

Future<void> _pumpDashboard(
  WidgetTester tester, {
  List<Map<String, dynamic>>? projects,
  List<Map<String, dynamic>>? exports,
  SystemHealth health = _reachableHealth,
  bool healthPending = false,
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Never completes → authNotifierProvider stays on its inert loading notifier.
  final neverReady = Completer<StorageService>();
  // Optionally hold /health in flight to exercise the "Checking…" branch.
  final pendingHealth = Completer<SystemHealth>();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWith((ref) => neverReady.future),
        projectsProvider.overrideWith(
          (ref) async => projects ?? _sampleProjects,
        ),
        exportsProvider.overrideWith((ref) async => exports ?? _sampleExports),
        systemHealthProvider.overrideWith(
          (ref) => healthPending ? pendingHealth.future : Future.value(health),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wide layout: greeting, upload, recents, and real counts', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    // Greeting (no user → no name suffix) and the distinct page subtitle.
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text(AppStrings.dashGreetingSubtitle), findsOneWidget);

    // Upload dropzone.
    expect(find.text(AppStrings.dashUploadTitle), findsOneWidget);

    // Recent projects render real rows.
    expect(find.text('Interview_Raw_01'), findsOneWidget);
    expect(find.text('Podcast_Ep12'), findsOneWidget);

    // Rail stat cards show the real counts (3 projects, 2 exports).
    expect(find.widgetWithText(StatCard, '3'), findsOneWidget);
    expect(find.widgetWithText(StatCard, '2'), findsOneWidget);
  });

  testWidgets('honest system status: models shown, never "Translation"', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    expect(find.text(AppStrings.dashOnline), findsOneWidget);
    expect(find.text(AppStrings.dashTranscription), findsOneWidget);
    expect(find.text(AppStrings.dashTransliteration), findsOneWidget);
    expect(find.text('whisper-large-v3-turbo'), findsOneWidget);
    expect(find.text('m2m100_418M · cpu'), findsOneWidget);

    // The honest-UI invariant: the fabricated word must never appear.
    expect(find.textContaining('Translation'), findsNothing);
  });

  testWidgets('unreachable backend: red status + em-dash models', (
    tester,
  ) async {
    await _pumpDashboard(tester, health: const SystemHealth.unreachable());

    expect(find.text(AppStrings.dashUnreachable), findsOneWidget);
    expect(find.text(AppStrings.dashOnline), findsNothing);
    // Both model rows fall back to the em-dash placeholder.
    expect(find.text(AppStrings.dashUnknownModel), findsNWidgets(2));
    expect(find.textContaining('Translation'), findsNothing);
  });

  testWidgets('status shows neutral "Checking…" while /health is in flight', (
    tester,
  ) async {
    await _pumpDashboard(tester, healthPending: true);

    // The card must not claim a green "Online" it hasn't verified yet.
    expect(find.text(AppStrings.dashChecking), findsOneWidget);
    expect(find.text(AppStrings.dashOnline), findsNothing);
    expect(find.text(AppStrings.dashUnreachable), findsNothing);
  });

  testWidgets('empty library: recents empty state + zero counts', (
    tester,
  ) async {
    await _pumpDashboard(tester, projects: const [], exports: const []);

    expect(find.text(AppStrings.dashNoProjects), findsOneWidget);
    // Both stat cards read 0.
    expect(find.widgetWithText(StatCard, '0'), findsNWidgets(2));
  });

  testWidgets('narrow layout renders without overflow (rail stacks)', (
    tester,
  ) async {
    // < 900 → stacked; < 600 → compact dropzone. A RenderFlex overflow here
    // would throw and fail the test, so a clean pump is the assertion.
    await _pumpDashboard(tester, size: const Size(500, 1400));

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text(AppStrings.dashUploadTitle), findsOneWidget);
    // Rail still present below the main column.
    expect(find.text(AppStrings.dashSystemStatus), findsOneWidget);
    expect(find.widgetWithText(StatCard, '3'), findsOneWidget);
  });

  testWidgets('dark mode builds and renders', (tester) async {
    SharedPreferences.setMockInitialValues({'is_dark_mode': true});
    await _pumpDashboard(tester);

    // The theme flips to dark after _loadTheme settles; the screen must still
    // render its key content without throwing.
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text(AppStrings.dashUploadTitle), findsOneWidget);
    expect(find.textContaining('Translation'), findsNothing);
  });
}
