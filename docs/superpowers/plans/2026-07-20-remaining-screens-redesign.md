# Remaining Screens Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the three Stitch-backed, not-yet-redesigned screens — Recent Projects (as a data table), Settings, and the Processing/Realtime Viewer — onto the scoped design system, keeping only real data/functionality ("honest UI").

**Architecture:** Each screen opts into `buildBaseTheme(isDark)` through a scoped `Theme` wrapper around its own subtree only (mirroring `lib/screens/dashboard/dashboard_screen.dart`); shell chrome and un-redesigned tabs are untouched. New presentational widgets take their data via constructor params so they unit-test without providers. Invented furniture (status badges, bulk actions, billing, fake progress %, English "gloss" lines) is deliberately dropped.

**Tech Stack:** Flutter 3 / Dart ^3.8.1, flutter_riverpod ^2.5.1, dio, media_kit, intl, flutter_test. No new dependencies.

**Design source of truth:** `docs/superpowers/specs/2026-07-20-remaining-screens-redesign-design.md` (read it before starting). Stitch refs: `Documentation/design/{html,screens}/{recent-projects,settings,processing-viewer}.*`.

---

## Context an implementer needs

**Working directory is `FrontEnd/`.** All `flutter` commands run there; all Dart paths below are relative to `FrontEnd/`.

**Design tokens** (`lib/core/design/`): `buildBaseTheme(bool isDark)` in `base_theme.dart`; `AppPalette` semantic accents (`success`/`successDark`, `tealSubtle`/`tealSubtleDark`, `videoStage`); `AppTypography` (`urduFamily = 'NotoNastaliqUrdu'`, `urduScale`, `urduHeight`). Spacing/radii on `AppSizes` (xs=4, sm=8, md=16, lg=24, xl=32; radiusSm=6, radiusMd=8, radiusLg=12; iconSm=18, iconLg=32; breakpointMobile=600). **Read colours/type via `Theme.of(context).colorScheme` / `textTheme`**, not `AppColors`.

**Honest-UI invariant (all screens):** never render the word **"Translation"** — this product does **transliteration**. Every screen's test asserts `find.textContaining('Translation')` → `findsNothing`.

**Reference implementation:** `lib/screens/dashboard/dashboard_screen.dart` (scoped-theme wrapper + provider wiring) and `test/screens/dashboard/dashboard_screen_test.dart` (the `ProviderScope`-override + never-completing `storageServiceProvider` auth seam).

**Data facts:**
- `projectsProvider` (`lib/providers/library_providers.dart`) resolves `List<Map<String, dynamic>>`; each map: `subtitle_id, file_id, project_name, original_filename, is_video (bool), segment_count (int), file_duration (num?, nullable), created_at, updated_at` (ISO-8601), newest-first. Open a project with `AppRoutes.to(context, AppRoutes.editor, arguments: {'fileId': p['file_id'], 'transcription': null})`.
- `EditableSegment` (`lib/models/subtitle_project_model.dart`): `int id; double start, end; String urduText, romanUrduText; bool isEdited;` plus `String get startFormatted` (`HH:MM:SS,mmm`) and `String get displayText`.
- `RealtimeState` (`lib/providers/realtime_subtitle_provider.dart`): `phase (RealtimePhase{idle,connecting,buffering,streaming,complete,error}), List<EditableSegment> segments, double processedThrough/totalDuration, int chunksReady/chunksTotal, String? error/fileId`; getters `bool canPlay`, `double progress` (`chunksReady/chunksTotal` or 0), `int? getSegmentAtTime(double)`.

**Navigation facts (unchanged):** Projects = shell tab 1, Settings = shell tab 4 (`IndexedStack` via `navIndexProvider`) — both return bare bodies (no `Scaffold`/`AppBar`/sidebar). Realtime Viewer is pushed full-screen via `AppRoutes.realtimeViewer` with `{fileId, filename}`; keeps `Row[Sidebar(selectedIndexOverride:-1), Expanded(...)]`, sidebar left unstyled.

**Out of scope:** the sidebar redesign; the 10 undesigned screens; any new backend endpoints.

**Per task:** `dart format` the touched files before every commit; use `withValues(alpha:)` not `withOpacity`. Commit messages end with the `Co-Authored-By` trailer used across this branch.

---

## File Structure

**Create:**
| Path | Responsibility |
|---|---|
| `lib/core/utils/format_utils.dart` | `formatDuration(num?)` → `H:MM:SS`/`M:SS`/`--:--`; `formatRelativeDate(String iso, {DateTime? now})` → "Today, HH:MM"/"Yesterday"/"MMM d, y" |
| `lib/widgets/projects/projects_table.dart` | `ProjectsTable` — header + rows, real columns, `onTap(project)` |
| `lib/widgets/settings/security_section.dart` | `SecuritySection` — password-change form OR "Signed in with Google" state |
| `lib/widgets/settings/appearance_row.dart` | `AppearanceRow` — Dark Mode switch |
| `lib/widgets/realtime/live_transcript_panel.dart` | `LiveTranscriptPanel` — timecode + Roman-Urdu + Urdu-script rows, current highlight, auto-scroll |
| `test/core/utils/format_utils_test.dart` | Formatter unit tests |
| `test/widgets/projects/projects_table_test.dart` | Table widget tests |
| `test/screens/projects/projects_screen_test.dart` | Projects composition test |
| `test/widgets/settings/security_section_test.dart` | Google-vs-email branch tests |
| `test/widgets/settings/appearance_row_test.dart` | Dark-mode toggle test |
| `test/widgets/realtime/live_transcript_panel_test.dart` | Transcript panel tests |

**Modify:**
| Path | Change |
|---|---|
| `lib/screens/projects/projects_screen.dart` | Rebuild as scoped-theme data table |
| `lib/screens/settings/settings_screen.dart` | Scoped-theme migration; honest sections; preserve handlers + Google branch |
| `lib/screens/realtime/realtime_viewer_screen.dart` | Scoped-theme migration; integrate `LiveTranscriptPanel`; honest progress; dark stage |
| `lib/core/constants/app_strings.dart` | Add strings the tasks introduce |

**Delete (grep-guarded):**
| Path | Why |
|---|---|
| `lib/screens/projects/recent_projects_screen.dart` | Dead `export 'projects_screen.dart';`, imported nowhere |

---

## Task 1: Delete the dead recent_projects re-export

**Files:**
- Delete: `lib/screens/projects/recent_projects_screen.dart`

- [ ] **Step 1: Prove it is dead**

Run: `grep -rn "recent_projects_screen" lib test`
Expected: only the file's own path appears (no `import`/`export` referencing it). If any import exists, STOP and re-point it to `projects_screen.dart` first.

- [ ] **Step 2: Delete and verify compile**

```bash
git rm lib/screens/projects/recent_projects_screen.dart
flutter analyze lib/screens/projects
```
Expected: no issues referencing the deleted file.

- [ ] **Step 3: Commit**

```bash
git add -A lib/screens/projects/recent_projects_screen.dart
git commit -m "chore(projects): delete dead recent_projects_screen re-export"
```

---

## Task 2: Shared formatters (format_utils)

**Files:**
- Create: `lib/core/utils/format_utils.dart`
- Test: `test/core/utils/format_utils_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/format_utils_test.dart
//
// Pins the shared project formatters: duration (H:MM:SS / M:SS / --:--) and the
// relative "last edited" date, evaluated against a fixed `now` so the test is
// deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/utils/format_utils.dart';

void main() {
  group('formatDuration', () {
    test('null → em-dash placeholder', () {
      expect(formatDuration(null), '--:--');
    });
    test('under an hour → M:SS', () {
      expect(formatDuration(225), '3:45');
    });
    test('an hour or more → H:MM:SS', () {
      expect(formatDuration(3725), '1:02:05');
    });
  });

  group('formatRelativeDate', () {
    final now = DateTime(2026, 7, 20, 14, 30);
    test('same calendar day → "Today, HH:MM"', () {
      expect(
        formatRelativeDate('2026-07-20T10:24:00', now: now),
        'Today, 10:24',
      );
    });
    test('previous calendar day → "Yesterday"', () {
      expect(formatRelativeDate('2026-07-19T09:00:00', now: now), 'Yesterday');
    });
    test('older → "MMM d, y"', () {
      expect(formatRelativeDate('2025-10-12T09:00:00', now: now), 'Oct 12, 2025');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/utils/format_utils_test.dart`
Expected: FAIL — `format_utils.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/utils/format_utils.dart
import 'package:intl/intl.dart';

/// Formats a seconds count as H:MM:SS (≥1h) or M:SS, or "--:--" when null.
String formatDuration(num? seconds) {
  if (seconds == null) return '--:--';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Relative "last edited" label from an ISO-8601 string.
/// Same day → "Today, HH:MM"; previous day → "Yesterday"; else "MMM d, y".
/// [now] is injectable for deterministic tests.
String formatRelativeDate(String iso, {DateTime? now}) {
  final when = DateTime.tryParse(iso)?.toLocal();
  if (when == null) return '';
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final thatDay = DateTime(when.year, when.month, when.day);
  final diff = today.difference(thatDay).inDays;
  if (diff == 0) return 'Today, ${DateFormat('HH:mm').format(when)}';
  if (diff == 1) return 'Yesterday';
  return DateFormat('MMM d, y').format(when);
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/utils/format_utils_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/utils/format_utils.dart test/core/utils/format_utils_test.dart
git add lib/core/utils/format_utils.dart test/core/utils/format_utils_test.dart
git commit -m "feat(projects): shared duration + relative-date formatters"
```

---

## Task 3: ProjectsTable widget

**Files:**
- Create: `lib/widgets/projects/projects_table.dart`
- Test: `test/widgets/projects/projects_table_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
    'file_duration': 2712,
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

  testWidgets('tapping a row fires onProjectTap with that project', (tester) async {
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/projects/projects_table_test.dart`
Expected: FAIL — `projects_table.dart` does not exist.

- [ ] **Step 3: Implement**

Build a bordered card containing a header `Row` (Project / Filename / Duration / Segments / Last Edited) and one `InkWell` row per project. Use `colorScheme`/`textTheme`/`AppSizes` only. Duration uses `formatDuration(p['file_duration'] as num?)`; last-edited uses `formatRelativeDate(p['updated_at'] as String? ?? '')`; icon is `p['is_video'] == true ? Icons.movie_outlined : Icons.audiotrack_outlined`. Duration and segment cells use a mono style (`textTheme.bodySmall` + `fontFamily: AppTypography.mono` if present, else default mono). No checkbox, no Status cell, no kebab.

```dart
// lib/widgets/projects/projects_table.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/format_utils.dart';

/// A dense table of projects. Columns map 1:1 to real backend fields; there is
/// deliberately no Status column (projects have no status), no bulk-select, and
/// no row menu (no rename/delete endpoint exists). [onProjectTap] opens the
/// editor for the tapped row.
class ProjectsTable extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final ValueChanged<Map<String, dynamic>> onProjectTap;

  const ProjectsTable({
    super.key,
    required this.projects,
    required this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(context),
          for (var i = 0; i < projects.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _row(context, projects[i]),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final style = text.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PROJECT', style: style)),
          Expanded(
            flex: 3,
            child: Text('FILENAME', style: style),
          ),
          Expanded(
            flex: 2,
            child: Text('DURATION', style: style, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text('SEGMENTS', style: style, textAlign: TextAlign.right),
          ),
          Expanded(flex: 3, child: Text('LAST EDITED', style: style)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = text.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurfaceVariant,
    );
    final isVideo = p['is_video'] == true;
    return InkWell(
      onTap: () => onProjectTap(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                    size: AppSizes.iconSm,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      (p['project_name'] ?? '') as String,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                (p['original_filename'] ?? '') as String,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatDuration(p['file_duration'] as num?),
                textAlign: TextAlign.right,
                style: mono,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p['segment_count'] ?? 0}',
                textAlign: TextAlign.right,
                style: mono,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                formatRelativeDate((p['updated_at'] ?? '') as String),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/projects/projects_table_test.dart`
Expected: PASS (5 tests). If `surfaceContainerHighest` is unavailable in the theme, use `scheme.surface` with a subtle overlay instead.

- [ ] **Step 5: Commit**

```bash
dart format lib/widgets/projects/projects_table.dart test/widgets/projects/projects_table_test.dart
git add lib/widgets/projects/projects_table.dart test/widgets/projects/projects_table_test.dart
git commit -m "feat(projects): ProjectsTable widget (real columns, no status/bulk/kebab)"
```

---

## Task 4: Rebuild projects_screen.dart

**Files:**
- Modify: `lib/screens/projects/projects_screen.dart`
- Test: `test/screens/projects/projects_screen_test.dart`
- Maybe modify: `lib/core/constants/app_strings.dart` (add `projectsAllTitle = "All Projects"`, `projectsSearchHint = "Search projects…"`, `projectsCountSuffix = "total"`, `projectsEmpty`, `projectsSearchEmpty` if not already present — reuse existing keys where they exist).

- [ ] **Step 1: Read first**

Read the current `lib/screens/projects/projects_screen.dart` (its `_searchController`, `projectsAsync.when`, empty/search-empty states) and `test/screens/dashboard/dashboard_screen_test.dart` (the auth seam + `projectsProvider` override). The rebuild keeps the search + state machine, swaps the grid for `ProjectsTable`, and wraps the subtree in `buildBaseTheme`.

- [ ] **Step 2: Write the failing composition test**

```dart
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
import 'package:romasubai_frontend/providers/library_providers.dart';
import 'package:romasubai_frontend/screens/projects/projects_screen.dart';
import 'package:romasubai_frontend/services/storage_service.dart';
import 'package:romasubai_frontend/widgets/projects/projects_table.dart';

final _projects = <Map<String, dynamic>>[
  {
    'file_id': 'f1', 'project_name': 'Interview_Raw_01',
    'original_filename': 'Interview_Raw_01.mp4', 'is_video': true,
    'segment_count': 842, 'file_duration': 2712,
    'updated_at': '2026-07-20T10:24:00',
  },
  {
    'file_id': 'f2', 'project_name': 'Podcast_Ep12',
    'original_filename': 'Podcast_Ep12.mp3', 'is_video': false,
    'segment_count': 45, 'file_duration': null,
    'updated_at': '2026-07-19T09:00:00',
  },
];

Future<void> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>>? projects,
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
        projectsProvider.overrideWith((ref) async => projects ?? _projects),
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
    expect(find.textContaining('total'), findsOneWidget); // count pill "2 total"
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
  });

  testWidgets('honest UI: no Status column, never "Translation"', (tester) async {
    await _pump(tester);
    expect(find.text('Status'), findsNothing);
    expect(find.textContaining('Translation'), findsNothing);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/screens/projects/projects_screen_test.dart`
Expected: FAIL (old grid screen; no "All Projects"/`ProjectsTable`).

- [ ] **Step 4: Rebuild the screen**

Rebuild `ProjectsScreen.build` as a `ConsumerStatefulWidget` returning a bare `Column` (no `Scaffold`) wrapped in `Theme(data: buildBaseTheme(ref.watch(themeProvider).isDark), child: Builder(...))`. Structure:
- A header row: `Text('All Projects', style: textTheme.headlineSmall)` + a mono count pill (`'${filtered.length} total'`) + a right-aligned search `TextField` bound to the existing `_searchController` (placeholder "Search projects…"). Keep the existing client-side filter over `project_name` + `original_filename`.
- Body: `projectsAsync.when(loading: CircularProgressIndicator, error: honest error text, data:)`. On data → filter; if empty and query empty → real empty state; if empty and query non-empty → search-empty state; else `Expanded(child: SingleChildScrollView(child: ProjectsTable(projects: filtered, onProjectTap: (p) => AppRoutes.to(context, AppRoutes.editor, arguments: {'fileId': p['file_id'], 'transcription': null}))))`.
- Replace every `AppColors.getX(isDark)` with a `colorScheme` role. Delete the `_ProjectTile` grid code.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/screens/projects/projects_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/screens/projects/projects_screen.dart test/screens/projects/projects_screen_test.dart lib/core/constants/app_strings.dart
git add lib/screens/projects/projects_screen.dart test/screens/projects/projects_screen_test.dart lib/core/constants/app_strings.dart
git commit -m "feat(projects): rebuild as design-system data table (All Projects)"
```

---

## Task 5: Settings section widgets (SecuritySection + AppearanceRow)

**Files:**
- Create: `lib/widgets/settings/security_section.dart`, `lib/widgets/settings/appearance_row.dart`
- Test: `test/widgets/settings/security_section_test.dart`, `test/widgets/settings/appearance_row_test.dart`

These carry the two trickiest honest-UI invariants (the Google-vs-email password branch, and the real dark-mode toggle) as pure widgets, so they test without auth mocking.

- [ ] **Step 1: Write the failing tests**

```dart
// test/widgets/settings/security_section_test.dart
//
// Email accounts get the password-change form; Google accounts (no password)
// get an honest "Signed in with Google" state instead of dead fields.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/settings/security_section.dart';

Widget _host({required bool isGoogle}) => MaterialApp(
  theme: buildBaseTheme(false),
  home: Scaffold(
    body: SecuritySection(
      isGoogleAccount: isGoogle,
      isBusy: false,
      onChangePassword: (_, _) {},
    ),
  ),
);

void main() {
  testWidgets('email account shows the password form', (tester) async {
    await tester.pumpWidget(_host(isGoogle: false));
    expect(find.byType(TextField), findsNWidgets(3)); // current/new/confirm
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('google account shows the signed-in-with-Google state', (tester) async {
    await tester.pumpWidget(_host(isGoogle: true));
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
```

```dart
// test/widgets/settings/appearance_row_test.dart
//
// The Dark Mode row reflects the current value and reports toggles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/base_theme.dart';
import 'package:romasubai_frontend/widgets/settings/appearance_row.dart';

void main() {
  testWidgets('reflects value and reports toggle', (tester) async {
    bool? toggled;
    await tester.pumpWidget(MaterialApp(
      theme: buildBaseTheme(false),
      home: Scaffold(
        body: AppearanceRow(isDark: false, onChanged: (v) => toggled = v),
      ),
    ));
    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(toggled, true);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widgets/settings/`
Expected: FAIL — widgets do not exist.

- [ ] **Step 3: Implement the widgets**

```dart
// lib/widgets/settings/appearance_row.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

/// A single Dark Mode row. Pure: [isDark] in, [onChanged] out — the screen wires
/// it to themeProvider (persisted to shared_preferences 'is_dark_mode').
class AppearanceRow extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onChanged;
  const AppearanceRow({super.key, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dark Mode', style: text.bodyMedium),
            Text(
              'Use the dark colour scheme',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        Switch(value: isDark, onChanged: onChanged),
      ],
    );
  }
}
```

```dart
// lib/widgets/settings/security_section.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

/// Password change for email accounts. Google accounts have no password, so they
/// see an honest "signed in with Google" note instead of fields wired to a call
/// that would 400.
class SecuritySection extends StatefulWidget {
  final bool isGoogleAccount;
  final bool isBusy;
  final void Function(String current, String next) onChangePassword;
  const SecuritySection({
    super.key,
    required this.isGoogleAccount,
    required this.isBusy,
    required this.onChangePassword,
  });

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (widget.isGoogleAccount) {
      return Row(
        children: [
          Icon(Icons.g_mobiledata, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'You signed in with Google, so there is no password to change here.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _field(_current, 'Current password'),
        const SizedBox(height: AppSizes.sm),
        _field(_next, 'New password'),
        const SizedBox(height: AppSizes.sm),
        _field(_confirm, 'Confirm new password'),
        const SizedBox(height: AppSizes.md),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: widget.isBusy
                ? null
                : () {
                    if (_next.text == _confirm.text && _next.text.isNotEmpty) {
                      widget.onChangePassword(_current.text, _next.text);
                    }
                  },
            child: const Text('Update Password'),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    obscureText: true,
    decoration: InputDecoration(labelText: label),
  );
}
```

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/widgets/settings/`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/widgets/settings/ test/widgets/settings/
git add lib/widgets/settings/ test/widgets/settings/
git commit -m "feat(settings): SecuritySection (Google branch) + AppearanceRow widgets"
```

---

## Task 6: Rebuild settings_screen.dart

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1: Read first**

Read the current `settings_screen.dart` in full. Preserve its three real handlers (`_handleSaveProfile` → `authNotifier.updateProfile`, `_handleChangePassword` → `authNotifier.changePassword`, `_handlePickImage` → `uploadProfilePicture`) and their `mounted`/loading/error-snackbar patterns, and the `user.googleId == null` gating. Read `lib/providers/auth_provider.dart` for the exact `AuthState`/`authNotifierProvider` API and `UserModel` (fields `email`, `firstName`, `lastName`, `googleId`/`isGoogleUser`, `isVerified`, `createdAt`, `profilePictureUrl`).

- [ ] **Step 2: Rebuild with scoped theme + honest sections**

Wrap the body in `Theme(data: buildBaseTheme(isDark), child: Builder(...))` (`isDark = ref.watch(themeProvider).isDark`). Replace every `AppColors.getX(isDark)` and hardcoded `Colors.grey/green.shadeXXX` with `colorScheme` roles (`AppPalette.success`/`successDark` for the verified badge). Return a bare `SingleChildScrollView` (no `Scaffold`). Compose a single-column stack of bordered "cards", each a titled section:
  1. **Profile** — avatar (existing picker/upload, keep `${ApiConfig.baseUrl}${user.profilePictureUrl}` prefix + initials fallback) + First/Last name Edit→Save/Cancel flow (gated to `user.googleId == null`, real `updateProfile`) + a **read-only** Email field.
  2. **Security** — `SecuritySection(isGoogleAccount: user.isGoogleUser, isBusy: <loading>, onChangePassword: _handleChangePassword)`.
  3. **Appearance** — `AppearanceRow(isDark: isDark, onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme())`.
  4. **Account** — read-only rows: Account Type (Google/Email), Verified/Pending, Member Since (`formatRelativeDate` is not appropriate here — show `DateFormat('MMM d, y').format(user.createdAt)` or the existing format).

**Delete/omit (honest-UI cuts):** notification bell, top-bar Save/Export, "Search settings", help icon, "Pro Tip"/billing/invoice/team copy, delete-account/danger zone, language selector, editable email, "Pro Editor" label. Never render "Translation".

- [ ] **Step 3: Honest-UI + analyze guard**

Run:
```bash
grep -niE "delete account|danger|billing|invoice|manage plan|upgrade|language|Translation" lib/screens/settings/settings_screen.dart
flutter analyze lib/screens/settings lib/widgets/settings
```
Expected: grep prints nothing; analyze clean. (If "language" appears only in an unrelated real context, judge accordingly — the target is no billing/delete/plan/translation copy.)

- [ ] **Step 4: Verify the settings widget tests still pass**

Run: `flutter test test/widgets/settings/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/screens/settings/settings_screen.dart
git add lib/screens/settings/settings_screen.dart
git commit -m "feat(settings): design-system migration; honest profile/security/appearance/account sections"
```

---

## Task 7: LiveTranscriptPanel widget

**Files:**
- Create: `lib/widgets/realtime/live_transcript_panel.dart`
- Test: `test/widgets/realtime/live_transcript_panel_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
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
    id: 0, start: 75, end: 78,
    urduText: 'تو بنیادی طور پر',
    romanUrduText: 'Toh basically, humara approach kaafi straight-forward tha.',
  ),
  EditableSegment(
    id: 1, start: 83, end: 86,
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
  testWidgets('renders roman-urdu + urdu-script lines and timecodes', (tester) async {
    await tester.pumpWidget(_host(current: 0));
    expect(find.textContaining('Toh basically'), findsOneWidget);
    expect(find.text('تو بنیادی طور پر'), findsOneWidget); // real Urdu, not English
    expect(find.textContaining('01:15'), findsOneWidget); // 75s → mm:ss timecode
  });

  testWidgets('never shows English gloss or "Translating"', (tester) async {
    await tester.pumpWidget(_host(current: 0));
    expect(find.textContaining('Translating'), findsNothing);
    expect(find.textContaining('Translation'), findsNothing);
  });

  testWidgets('empty segments → waiting state, no rows', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildBaseTheme(false),
      home: const Scaffold(body: LiveTranscriptPanel(segments: [], currentIndex: null)),
    ));
    expect(find.textContaining('Toh basically'), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/realtime/live_transcript_panel_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 3: Implement**

A `ListView.builder` of rows. Each row: a mono `mm:ss` timecode derived from `seg.start` (`'${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}'`), the `romanUrduText` line, and the `urduText` line styled with `AppTypography.urduFamily`/`urduScale`/`urduHeight` and `Directionality(textDirection: TextDirection.rtl)`. The row at `currentIndex` gets a `tealSubtle`/`tealSubtleDark` background + a left teal border. Header: caps label "LIVE TRANSCRIPT". No spinner/blinking cursor, no English line. Empty `segments` → a centered muted "Waiting for subtitles…". Include an optional `ScrollController` the screen can drive to auto-scroll; the widget itself just renders.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/realtime/live_transcript_panel_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/widgets/realtime/live_transcript_panel.dart test/widgets/realtime/live_transcript_panel_test.dart
git add lib/widgets/realtime/live_transcript_panel.dart test/widgets/realtime/live_transcript_panel_test.dart
git commit -m "feat(realtime): LiveTranscriptPanel (roman-urdu + urdu-script, no gloss)"
```

---

## Task 8: Rebuild realtime_viewer_screen.dart

**Files:**
- Modify: `lib/screens/realtime/realtime_viewer_screen.dart`

- [ ] **Step 1: Read first**

Read the current `realtime_viewer_screen.dart` in full. Note the state machine (`RealtimePhase`), the `_buildBufferingState`/`_buildVideoArea`/`VideoControls` structure, `_startVideoWhenReady`, `notifySeek`, and the complete→`AppRoutes.replace(editor, {...})` handoff via `createProjectForEditor`. This is a **behavior-preserving migration plus** the new transcript panel + honest progress copy — do not regress the streaming/seek/handoff logic.

- [ ] **Step 2: Migrate + integrate**

- Wrap the content column (right of `Sidebar(selectedIndexOverride:-1)`) in `Theme(data: buildBaseTheme(isDark), child: Builder(...))` (`isDark` from `Theme.of(context).brightness` at call site, or `ref.watch(themeProvider).isDark`). Replace the 24 `AppColors.getX(isDark)` calls with `colorScheme` roles.
- **Video stage stays dark in both themes:** keep the stage/`Video` background on `AppPalette.videoStage`/black, NOT `colorScheme.surface`.
- Add the **`LiveTranscriptPanel`** below the video area, fed by `rtState.segments` and `currentIndex: rtState.getSegmentAtTime(currentPlaybackSeconds)`. Give it a `ScrollController` and animate to the bottom when `segments.length` grows (auto-scroll).
- **Honest progress:** while `chunksTotal == 0` (connecting/buffering) show an **indeterminate** `LinearProgressIndicator`; once `chunksTotal > 0` show a **determinate** bar `value: rtState.progress` with the label **"${rtState.chunksReady}/${rtState.chunksTotal} chunks"**. Never render a fabricated percentage. Handle the fast path (instant 0→1) — the determinate bar simply jumps, which is fine.
- **Cuts:** no top-bar Save/Export/bell/"Pro Editor"; no "Buffer: 45s" literal (only show a buffer pill if wired to `rtState.processedThrough - currentPlaybackSeconds`); no "Extracting audio 45%"; no "Translating…" affordance; no English gloss.
- Keep the phase chip, the pulse dot (only when `streaming`), and the complete→"Open Subtitle Editor" button unchanged in behavior.

- [ ] **Step 3: Honest-UI + analyze guard**

Run:
```bash
grep -niE "Translat|Buffer: 45|Extracting audio|45%|Save|Export" lib/screens/realtime/realtime_viewer_screen.dart
flutter analyze lib/screens/realtime lib/widgets/realtime
```
Expected: grep shows no "Translat"/fake-progress/top-bar Save/Export copy (a legitimate "Open Subtitle Editor" button is fine — it's an editor handoff, not an export). Analyze clean.

- [ ] **Step 4: Verify realtime widget tests + build**

Run:
```bash
flutter test test/widgets/realtime/
flutter build web --release
```
Expected: transcript tests PASS; web build exits 0 (full-app compile check, since the screen itself uses media_kit and isn't pumped in a widget test).

- [ ] **Step 5: Commit**

```bash
dart format lib/screens/realtime/realtime_viewer_screen.dart
git add lib/screens/realtime/realtime_viewer_screen.dart
git commit -m "feat(realtime): design-system migration; live transcript + honest chunk progress"
```

---

## Task 9: Full verification + finish

**Files:** none (verification only)

- [ ] **Step 1: Format + analyze the changed surface**

Run:
```bash
dart format lib/core/utils/format_utils.dart lib/widgets/projects lib/widgets/settings lib/widgets/realtime lib/screens/projects lib/screens/settings lib/screens/realtime
dart analyze lib/core/utils/format_utils.dart lib/widgets/projects lib/widgets/settings lib/widgets/realtime lib/screens/projects lib/screens/settings lib/screens/realtime
```
Expected: "No issues found!"

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all green (the ~73 prior + the ~21 new tests from this plan).

- [ ] **Step 3: Honest-UI sweep across the three screens**

Run: `grep -rniE "\bTranslation\b|Completed|Draft|billing|delete account" lib/screens/projects lib/screens/settings lib/screens/realtime`
Expected: no fabricated status/billing/translation copy.

- [ ] **Step 4: Finish the branch**

Invoke `superpowers:finishing-a-development-branch`. Stage only the redesign files (never `eval_results/`, never the unrelated whole-project `dart format` churn). Present merge/PR/keep options.

---

## Notes on staging discipline

The working tree carries an **unrelated whole-project `dart format` churn (~40 files)** and pre-existing `eval_results/*` deletions from before this effort. Every commit in this plan must `git add` only its named files — never `git add -A` at the repo root, never stage `eval_results/`.
