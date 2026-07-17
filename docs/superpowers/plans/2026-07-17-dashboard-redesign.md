# Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Dashboard screen against the design system created for the editor (`lib/core/design/`), matching the intent of the Stitch mockup at `Documentation/design/screens/dashboard.png` while showing only data the product actually has.

**Architecture:** The dashboard is one tab inside `main_shell`'s `IndexedStack`. Like the editor, it opts into the new design system through a **scoped `Theme` wrapper around its own subtree only** — the shell chrome (sidebar) and the other four tabs keep the existing `AppColors`/`AppTheme` look until they are redesigned in turn. The new base theme is extracted from `buildEditorTheme` into a shared `buildAppTheme(isDark)` so both screens draw from one source. Colours come from `AppPalette` (via `Theme.of(context).colorScheme`), type from `AppTypography` (via `Theme.of(context).textTheme`), and **spacing/radii stay on the existing `AppSizes` scale** so the dashboard sits coherently beside its sibling tabs.

**Tech Stack:** Flutter 3 / Dart ^3.8.1, flutter_riverpod ^2.5.1 (`FutureProvider.autoDispose` for data), dio (via `apiClientProvider`), intl ^0.19.0 (date formatting), flutter_test. No new dependencies.

---

## Context an implementer needs

**Working directory is `FrontEnd/`.** All `flutter` commands run there. All Dart paths below are relative to `FrontEnd/`.

**Design source of truth:**
- Screenshot: `Documentation/design/screens/dashboard.png`
- Markup with exact values: `Documentation/design/html/dashboard.html`
- Product constraints: `Documentation/PRODUCT_OVERVIEW.md` §4 and the dashboard section §6.8

**The mockup is a reference, not a contract.** Roughly a third of it is invented SaaS furniture this product has no backend for. These parts are **deliberately NOT built** (decided with the user):

1. **Workspace Usage** (Storage 45GB/100GB, Processing Minutes 850/1000, "Approaching limit") — no quotas, storage limits, or billing exist.
2. **Minutes Processed / "+12% this week"** — no aggregate stats or time-series exist.
3. **Recent Activity timeline** — no event log exists; nothing records "started transcription" as an event.
4. **"Pro Editor" / "Premium Plan" tier labels** — no tiers. MIT-licensed FYP.
5. **Notification bell** — no notification system.
6. **Top-bar Save / Export buttons** — those are editor actions; a dashboard has nothing to save or export.
7. **"Completed" / "Draft" status badges** on project rows — subtitle projects have no status field.

**What replaces the invented right rail** (decided with the user): two real stat cards — **Total Projects** and **Exports**, both derived from list endpoints that already exist — plus an **honest System Status card**.

**The System Status card must not lie.** Both the current dashboard's status panel (`isOnline: true` hardcoded three times) and the backend's `GET /health` (`"status": "healthy"`, `"database": "connected"` — literals, never checked) are decorative today. The only honest signals available **without backend changes** are:
- **Reachability** — did `GET /health` return? This is a real fact. Show "Online" (green) on success, "Unreachable" (red) on failure/timeout.
- **Configured models** — `/health` honestly returns `whisper_model`, `m2m100_model`, and `transliteration_device` from settings. Display these raw. Do **not** map them to friendly backend names ("Groq", "Modal") — `/health` does not return the backend type, so that label would be a guess. Displaying the configured model string is honest; inventing "Groq" is not.
- Do **not** surface the `status` or `database` literal fields as truth — they are hardcoded and prove nothing beyond "the server answered", which reachability already covers.

**One live copy bug to fix:** `app_strings.dart:66` ships `romanUrduTranslation = "Roman Urdu Translation"`, rendered on the current dashboard. This product does **transliteration** — script conversion, same language — not translation. Task 1 fixes the string. Getting this wrong misrepresents the entire product.

**The sidebar is out of scope.** The mockup redesigns the left nav, but the sidebar is shared shell chrome rendered for all five tabs. Touching it would restyle every screen at once, breaking the one-screen-at-a-time rollout. The dashboard tab keeps the existing sidebar; a sidebar redesign is a separate future task.

**Known landmines in the existing code (verified, with line numbers):**
- `projectsProvider` is defined **inside** `lib/screens/projects/projects_screen.dart:13` and `exportsProvider` inside `lib/screens/exports/exports_screen.dart:11`. The dashboard needs both. Task 3 moves them to a shared `lib/providers/library_providers.dart` and re-points both screens — importing a screen file just to reach a provider would be a layering smell.
- `lib/providers/project_provider.dart` is **dead** — `ProjectProvider` uses `Project.getSampleData()` and is imported nowhere. Task 10 deletes it (guarded by a grep).
- `lib/widgets/dashboard/processing_history.dart` and `lib/widgets/dashboard/transcription_preview.dart` are one-line `// Placeholder - implement if needed` stubs, imported nowhere. Task 10 deletes them (guarded by a grep).
- Projects open via `AppRoutes.to(context, AppRoutes.editor, arguments: {'fileId': p['file_id'], 'transcription': null})` (`projects_screen.dart:231`). The recent-projects card mirrors this exactly.
- `/subtitles/list/projects` returns objects with: `subtitle_id, file_id, project_name, original_filename, is_video, segment_count, file_duration, created_at, updated_at` (newest-first). `file_duration` is seconds as a `num`, possibly null. `created_at`/`updated_at` are ISO-8601 strings.
- The dashboard is inside the shell, so its content is inset by the sidebar. Layout decisions must key off **content width via `LayoutBuilder`**, not `MediaQuery` screen width — matching the existing dashboard's 760px `LayoutBuilder` pattern.

**Existing test convention** (`test/widgets/editor/segment_tile_test.dart`): repo-relative path comment on line 1, a rationale block, a private `_host({...})` builder that wraps the widget in `MaterialApp(theme: buildEditorTheme(false), home: Scaffold(body: ...))`, `find.text`/`find.byIcon` assertions, callbacks stubbed as `(_) {}` or `() {}`. **No mocktail/mockito** — the repo hand-writes fakes. Every widget this plan tests takes its data as constructor params, so no `ProviderScope` override or fake is needed for widget tests.

---

## File Structure

**Create:**
| Path | Responsibility |
|---|---|
| `lib/core/design/app_shell_theme.dart` | `buildAppTheme(bool isDark)` — the shared base `ThemeData` (scheme + typography + divider + icon), no editor extension |
| `lib/providers/library_providers.dart` | `projectsProvider`, `exportsProvider` (moved here), `systemHealthProvider` |
| `lib/models/system_health.dart` | `SystemHealth` value type + `fromJson` + `unreachable` factory |
| `lib/widgets/dashboard/stat_card.dart` | `StatCard` — icon + uppercase label + big number; used for Total Projects / Exports |
| `lib/widgets/dashboard/system_status_card.dart` | `SystemStatusCard` — honest reachability dot + configured model rows |
| `lib/widgets/dashboard/recent_projects_card.dart` | `RecentProjectsCard` — bordered card, project rows, "View All", empty/loading/error states, `_formatProjectDate`/`_formatDuration` helpers |
| `lib/widgets/dashboard/upload_dropzone.dart` | `UploadDropzone` — dashed drop zone, format chips, tap-to-pick |
| `test/core/design/app_shell_theme_test.dart` | Base theme unit test |
| `test/models/system_health_test.dart` | `SystemHealth.fromJson` + `unreachable` tests |
| `test/widgets/dashboard/stat_card_test.dart` | StatCard widget tests |
| `test/widgets/dashboard/system_status_card_test.dart` | SystemStatusCard widget tests (incl. the no-"translation" copy guard) |
| `test/widgets/dashboard/recent_projects_card_test.dart` | RecentProjectsCard widget tests (rows, empty, View All, transliteration copy, duration format) |

**Modify:**
| Path | Change |
|---|---|
| `lib/core/design/editor_theme.dart` | `buildEditorTheme` delegates to `buildAppTheme`, then adds the `EditorTheme` extension |
| `lib/core/constants/app_strings.dart:66` | Fix the "Translation" copy; add the dashboard strings Task 1 lists |
| `lib/services/api/api_config.dart` | Add `health = '/health'` |
| `lib/screens/projects/projects_screen.dart:13` | Delete local `projectsProvider`; import from `library_providers.dart` |
| `lib/screens/exports/exports_screen.dart:11` | Delete local `exportsProvider`; import from `library_providers.dart` |
| `lib/screens/dashboard/dashboard_screen.dart` | Rebuild: scoped `buildAppTheme` wrapper, greeting header, responsive layout, new widgets |

**Delete (each guarded by a grep step in Task 10):**
| Path | Why |
|---|---|
| `lib/providers/project_provider.dart` | Dead sample-data provider, imported nowhere |
| `lib/widgets/dashboard/processing_history.dart` | `// Placeholder` stub, imported nowhere |
| `lib/widgets/dashboard/transcription_preview.dart` | `// Placeholder` stub, imported nowhere |

---

## Decisions locked with the user (so a reviewer can veto during spec review)

- **Palette:** keep `AppPalette` (the editor's neutrals). The dashboard maps onto it rather than importing the mockup's slate neutrals, avoiding two competing neutral families.
- **Right rail:** Total Projects + Exports (real counts) + System Status (honest). Everything else in the mockup rail is dropped.
- **Greeting:** keep the time-based "Good Morning/Afternoon/Evening, {firstName}".
- **Tapping a recent project** opens the editor directly, mirroring `projects_screen.dart:231`.
- **"View All"** switches the shell to the Projects tab via `navIndexProvider`.

---

## Task 1: Fix the copy and add dashboard strings

The current dashboard renders "Roman Urdu Translation". Fix it, and add every string the new widgets need, so no later task hardcodes UI text.

**Files:**
- Modify: `lib/core/constants/app_strings.dart`

- [ ] **Step 1: Fix the transliteration string and add new strings**

In `lib/core/constants/app_strings.dart`, replace line 66:

```dart
  static const String romanUrduTranslation = "Roman Urdu Translation";
```

with:

```dart
  static const String romanUrduTransliteration = "Roman Urdu Transliteration";
```

Then, immediately after the existing `online` constant (line 69), add:

```dart

  // Dashboard — upload drop zone
  static const String dashUploadTitle = "Drag & drop media to start editing";
  static const String dashUploadSubtitle =
      "Upload video or audio files to auto-generate Roman Urdu subtitles.";
  static const String dashUploadTapHint = "Tap to choose a file";
  static const String dashMaxSize = "MAX 2GB";

  // Dashboard — stat cards
  static const String dashTotalProjects = "TOTAL PROJECTS";
  static const String dashExports = "EXPORTS";

  // Dashboard — recent projects
  static const String dashRecentProjects = "RECENT PROJECTS";
  static const String dashViewAll = "View All";
  static const String dashNoProjects = "No projects yet";
  static const String dashNoProjectsHint =
      "Upload a file above to generate your first captions.";
  static const String dashProjectFlow = "Urdu → Roman Urdu";

  // Dashboard — system status
  static const String dashSystemStatus = "SYSTEM STATUS";
  static const String dashOnline = "Online";
  static const String dashUnreachable = "Unreachable";
  static const String dashTranscription = "Transcription";
  static const String dashTransliteration = "Transliteration";
  static const String dashUnknownModel = "—";
```

- [ ] **Step 2: Update the only current reference to the renamed string**

`lib/screens/dashboard/dashboard_screen.dart` is fully rebuilt in Task 9, but until then the rename must not break the build. Find the reference:

Run: `cd FrontEnd && grep -rn 'romanUrduTranslation' lib/`
Expected: one hit in `lib/screens/dashboard/dashboard_screen.dart` (the `_StatusItem` label).

Replace that `AppStrings.romanUrduTranslation` with `AppStrings.romanUrduTransliteration`.

- [ ] **Step 3: Verify the app still compiles**

Run: `cd FrontEnd && flutter analyze lib/core/constants/app_strings.dart lib/screens/dashboard/dashboard_screen.dart`
Expected: No errors (warnings about the soon-to-be-replaced dashboard are fine as long as there are no *errors*).

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/lib/core/constants/app_strings.dart FrontEnd/lib/screens/dashboard/dashboard_screen.dart
git commit -m "fix(dashboard): correct 'translation' to 'transliteration'; add dashboard strings"
```

---

## Task 2: Extract the shared base theme

`buildEditorTheme` builds a `ThemeData` (scheme, typography, divider, icon) and then attaches the editor-only `EditorTheme` extension. The dashboard needs the same base **without** the extension. Extract the base so both screens share one source instead of duplicating theme construction.

**Files:**
- Create: `lib/core/design/app_shell_theme.dart`
- Create: `test/core/design/app_shell_theme_test.dart`
- Modify: `lib/core/design/editor_theme.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/core/design/app_shell_theme_test.dart
//
// buildAppTheme is the shared base every redesigned screen wraps itself in.
// It must carry the AppPalette ColorScheme and AppTypography, and — unlike
// buildEditorTheme — must NOT attach the editor-only EditorTheme extension.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_palette.dart';
import 'package:romasubai_frontend/core/design/app_shell_theme.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';

void main() {
  test('buildAppTheme uses the AppPalette scheme for the given brightness', () {
    expect(buildAppTheme(false).colorScheme.primary, AppPalette.primary);
    expect(buildAppTheme(true).colorScheme.primary, AppPalette.primaryDark);
  });

  test('buildAppTheme does NOT carry the EditorTheme extension', () {
    expect(buildAppTheme(false).extension<EditorTheme>(), isNull);
  });

  test('buildEditorTheme still carries the EditorTheme extension', () {
    expect(buildEditorTheme(false).extension<EditorTheme>(), isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd FrontEnd && flutter test test/core/design/app_shell_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:romasubai_frontend/core/design/app_shell_theme.dart'`.

- [ ] **Step 3: Create the base theme**

```dart
// FrontEnd/lib/core/design/app_shell_theme.dart
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_typography.dart';

/// The shared base theme every redesigned screen wraps itself in.
///
/// Deliberately NOT applied app-wide: screens opt in one at a time via a
/// scoped `Theme(data: buildAppTheme(isDark), ...)`, so the un-redesigned
/// screens keep using AppColors/AppTheme. The editor extends this base with
/// its own [EditorTheme] extension in `editor_theme.dart`.
ThemeData buildAppTheme(bool isDark) {
  final scheme = AppPalette.scheme(isDark);
  final textTheme = AppTypography.textTheme(
    scheme.onSurface,
    scheme.onSurfaceVariant,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    fontFamily: AppTypography.latinFamily,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
  );
}
```

- [ ] **Step 4: Refactor `buildEditorTheme` to delegate**

In `lib/core/design/editor_theme.dart`, add the import near the top (after the existing `app_typography.dart` import):

```dart
import 'app_shell_theme.dart';
```

Replace the entire `buildEditorTheme` function body (currently lines ~121-144) with:

```dart
/// The scoped theme the editor wraps itself in: the shared [buildAppTheme]
/// base plus the editor-only [EditorTheme] extension.
///
/// Deliberately NOT applied app-wide: the un-redesigned screens still use
/// AppColors/AppTheme and are redesigned separately.
ThemeData buildEditorTheme(bool isDark) {
  return buildAppTheme(isDark).copyWith(
    extensions: <ThemeExtension<dynamic>>[
      isDark ? EditorTheme.dark : EditorTheme.light,
    ],
  );
}
```

If `app_typography.dart` is now unused in `editor_theme.dart`, remove its import to keep `flutter analyze` clean. (The `EditorTheme` class above still uses `app_palette.dart`, so keep that import.)

- [ ] **Step 5: Run the new test and the existing editor tests**

Run: `cd FrontEnd && flutter test test/core/design/app_shell_theme_test.dart test/widgets/editor/`
Expected: PASS — the base test passes and the editor widget tests still pass (proving the delegation produced an equivalent theme).

- [ ] **Step 6: Commit**

```bash
git add FrontEnd/lib/core/design/app_shell_theme.dart FrontEnd/lib/core/design/editor_theme.dart FrontEnd/test/core/design/app_shell_theme_test.dart
git commit -m "refactor(design): extract buildAppTheme base; buildEditorTheme delegates to it"
```

---

## Task 3: Move the data providers to a shared home

`projectsProvider` and `exportsProvider` live inside screen files. The dashboard needs both. Move them to `lib/providers/library_providers.dart` and re-point the screens.

**Files:**
- Create: `lib/providers/library_providers.dart`
- Modify: `lib/screens/projects/projects_screen.dart`
- Modify: `lib/screens/exports/exports_screen.dart`

- [ ] **Step 1: Create the shared providers file**

```dart
// FrontEnd/lib/providers/library_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/api_client.dart';
import '../services/api/api_config.dart';

/// Subtitle projects, newest-first, from `/subtitles/list/projects`.
/// Shared by the Projects screen and the Dashboard.
final projectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.projectsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['projects'] ?? []);
});

/// Export history, newest-first, from `/subtitles/list/exports`.
/// Shared by the Exports screen and the Dashboard.
final exportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.exportsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['exports'] ?? []);
});
```

- [ ] **Step 2: Remove the local `projectsProvider` from the projects screen**

In `lib/screens/projects/projects_screen.dart`, delete the local `projectsProvider` definition (the `FutureProvider.autoDispose<...>` block around lines 12-20, including its `/// Provider that fetches real projects...` comment). Add this import with the other imports at the top:

```dart
import '../../providers/library_providers.dart';
```

Leave every `ref.watch(projectsProvider)` / `ref.invalidate(projectsProvider)` call unchanged — they now resolve to the imported provider.

- [ ] **Step 3: Remove the local `exportsProvider` from the exports screen**

In `lib/screens/exports/exports_screen.dart`, delete the local `exportsProvider` definition (the block around lines 10-18, including its comment). Add:

```dart
import '../../providers/library_providers.dart';
```

Leave every `ref.watch(exportsProvider)` / `ref.invalidate(exportsProvider)` call unchanged.

- [ ] **Step 4: Verify both screens still analyze cleanly**

Run: `cd FrontEnd && flutter analyze lib/screens/projects/projects_screen.dart lib/screens/exports/exports_screen.dart lib/providers/library_providers.dart`
Expected: No errors. (If "unused import" appears for `api_client`/`api_config` in a screen, remove that now-unused import from the screen.)

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/providers/library_providers.dart FrontEnd/lib/screens/projects/projects_screen.dart FrontEnd/lib/screens/exports/exports_screen.dart
git commit -m "refactor(providers): move projects/exports providers to shared library_providers"
```

---

## Task 4: SystemHealth model and provider

A small value type over `GET /health`, plus a provider that returns an `unreachable` value instead of throwing, so the status card can render a red state rather than an error box.

**Files:**
- Create: `lib/models/system_health.dart`
- Create: `test/models/system_health_test.dart`
- Modify: `lib/services/api/api_config.dart`
- Modify: `lib/providers/library_providers.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/models/system_health_test.dart
//
// SystemHealth is the honest view over GET /health. Reachability is the only
// hard truth (did the call return); the model strings are the configured
// values the backend reports. `unreachable` is the red fallback.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/system_health.dart';

void main() {
  test('fromJson reads the configured model fields and is reachable', () {
    final h = SystemHealth.fromJson({
      'status': 'healthy',
      'database': 'connected',
      'whisper_model': 'whisper-large-v3-turbo',
      'm2m100_model': 'facebook/m2m100_418M',
      'transliteration_device': 'cuda',
    });

    expect(h.reachable, isTrue);
    expect(h.whisperModel, 'whisper-large-v3-turbo');
    expect(h.transliterationModel, 'facebook/m2m100_418M');
    expect(h.device, 'cuda');
  });

  test('fromJson tolerates missing model fields', () {
    final h = SystemHealth.fromJson({'status': 'healthy'});
    expect(h.reachable, isTrue);
    expect(h.whisperModel, isNull);
    expect(h.transliterationModel, isNull);
    expect(h.device, isNull);
  });

  test('unreachable is not reachable and carries no model info', () {
    const h = SystemHealth.unreachable();
    expect(h.reachable, isFalse);
    expect(h.whisperModel, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd FrontEnd && flutter test test/models/system_health_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:romasubai_frontend/models/system_health.dart'`.

- [ ] **Step 3: Create the model**

```dart
// FrontEnd/lib/models/system_health.dart

/// An honest view over `GET /health`.
///
/// The backend's `status`/`database` fields are hardcoded literals and are
/// deliberately ignored — the only real signal is whether the call returned
/// ([reachable]) plus the configured model strings it reports.
class SystemHealth {
  /// True when `GET /health` returned a response. This is the one hard fact.
  final bool reachable;

  /// Configured ASR model (e.g. "whisper-large-v3-turbo"), or null.
  final String? whisperModel;

  /// Configured transliteration model, or null.
  final String? transliterationModel;

  /// Configured transliteration device (e.g. "cpu"/"cuda"), or null.
  final String? device;

  const SystemHealth({
    required this.reachable,
    this.whisperModel,
    this.transliterationModel,
    this.device,
  });

  /// The red fallback used when the health call fails or times out.
  const SystemHealth.unreachable()
      : reachable = false,
        whisperModel = null,
        transliterationModel = null,
        device = null;

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) => v == null ? null : v.toString();
    return SystemHealth(
      reachable: true,
      whisperModel: str(json['whisper_model']),
      transliterationModel: str(json['m2m100_model']),
      device: str(json['transliteration_device']),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd FrontEnd && flutter test test/models/system_health_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Add the health path to ApiConfig**

In `lib/services/api/api_config.dart`, add alongside the other path constants (e.g. right after `authMe`):

```dart
  static const String health = '/health';
```

- [ ] **Step 6: Add the provider**

Append to `lib/providers/library_providers.dart`:

```dart

/// Honest system status from `GET /health`. Returns [SystemHealth.unreachable]
/// instead of throwing, so the UI shows a red "Unreachable" state rather than
/// an error box.
final systemHealthProvider =
    FutureProvider.autoDispose<SystemHealth>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.dio.get(ApiConfig.health);
    final data = response.data as Map<String, dynamic>;
    return SystemHealth.fromJson(data);
  } catch (_) {
    return const SystemHealth.unreachable();
  }
});
```

Add the model import at the top of `library_providers.dart`:

```dart
import '../models/system_health.dart';
```

- [ ] **Step 7: Verify analyze + tests**

Run: `cd FrontEnd && flutter analyze lib/providers/library_providers.dart lib/models/system_health.dart lib/services/api/api_config.dart && flutter test test/models/system_health_test.dart`
Expected: No analyze errors; 3 tests pass.

- [ ] **Step 8: Commit**

```bash
git add FrontEnd/lib/models/system_health.dart FrontEnd/lib/providers/library_providers.dart FrontEnd/lib/services/api/api_config.dart FrontEnd/test/models/system_health_test.dart
git commit -m "feat(dashboard): SystemHealth model + honest systemHealthProvider over /health"
```

---

## Task 5: StatCard widget

A small reusable card: an icon + uppercase label on top, a large number below. Used for Total Projects and Exports. Takes its value as a param — no Riverpod inside — so it is trivially testable.

**Files:**
- Create: `lib/widgets/dashboard/stat_card.dart`
- Create: `test/widgets/dashboard/stat_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/widgets/dashboard/stat_card_test.dart
//
// StatCard renders a label and a value. `value` is nullable so the card can
// show a placeholder while its provider is still loading.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_shell_theme.dart';
import 'package:romasubai_frontend/widgets/dashboard/stat_card.dart';

Widget _host({required String label, String? value, IconData icon = Icons.folder}) {
  return MaterialApp(
    theme: buildAppTheme(false),
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/stat_card_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create the widget**

```dart
// FrontEnd/lib/widgets/dashboard/stat_card.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

/// A single stat: icon + uppercase label, with a large number beneath.
/// [value] is null while the source is loading, shown as an em dash.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            value ?? '—',
            style: text.headlineMedium?.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/stat_card_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/widgets/dashboard/stat_card.dart FrontEnd/test/widgets/dashboard/stat_card_test.dart
git commit -m "feat(dashboard): StatCard widget"
```

---

## Task 6: SystemStatusCard widget

Renders the honest health view: a reachability dot + label, then two rows showing the configured models. Never claims more than it knows.

**Files:**
- Create: `lib/widgets/dashboard/system_status_card.dart`
- Create: `test/widgets/dashboard/system_status_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/widgets/dashboard/system_status_card_test.dart
//
// The card must be honest: green "Online" only when reachable, red
// "Unreachable" otherwise, and it must NEVER render the word "Translation"
// (this product does transliteration).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_shell_theme.dart';
import 'package:romasubai_frontend/models/system_health.dart';
import 'package:romasubai_frontend/widgets/dashboard/system_status_card.dart';

Widget _host(SystemHealth health) {
  return MaterialApp(
    theme: buildAppTheme(false),
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
    expect(find.text('facebook/m2m100_418M'), findsOneWidget);
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/system_status_card_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create the widget**

```dart
// FrontEnd/lib/widgets/dashboard/system_status_card.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';
import '../../models/system_health.dart';

/// The honest system-status card. Shows one real reachability signal and the
/// configured model strings — never a fabricated backend label, never the
/// word "Translation".
class SystemStatusCard extends StatelessWidget {
  final SystemHealth health;

  const SystemStatusCard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ok = health.reachable;
    final dotColor = ok ? AppPalette.success : scheme.error;
    final statusLabel = ok ? AppStrings.dashOnline : AppStrings.dashUnreachable;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dashSystemStatus,
                style: text.labelSmall?.copyWith(letterSpacing: 0.5),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    statusLabel,
                    style: text.bodySmall?.copyWith(
                      color: dotColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _row(context, AppStrings.dashTranscription,
              health.whisperModel ?? AppStrings.dashUnknownModel),
          const SizedBox(height: AppSizes.sm),
          _row(context, AppStrings.dashTransliteration,
              _transliterationValue()),
        ],
      ),
    );
  }

  String _transliterationValue() {
    final model = health.transliterationModel;
    if (model == null) return AppStrings.dashUnknownModel;
    final device = health.device;
    return device == null ? model : '$model · $device';
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            value,
            style: AppTypographyMono.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Small helper so the model strings render in the mono family (digits and
/// model ids read better monospaced), pulling colour from the active theme.
class AppTypographyMono {
  static TextStyle of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 12,
      height: 1.3,
      color: scheme.onSurface,
    );
  }
}
```

> Note: the mono style is inlined here rather than reaching into `AppTypography.mono` to avoid coupling the widget to the static helper's colour handling. If a later screen needs the same, promote `AppTypographyMono.of` into `app_typography.dart`. YAGNI for now.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/system_status_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/widgets/dashboard/system_status_card.dart FrontEnd/test/widgets/dashboard/system_status_card_test.dart
git commit -m "feat(dashboard): honest SystemStatusCard (reachability + configured models)"
```

---

## Task 7: RecentProjectsCard widget

A bordered card with a header ("RECENT PROJECTS" + "View All"), and up to N project rows. Renders empty and error states. Each row shows an icon (video/audio), name, the transliteration-flow subtitle, a formatted date, and a formatted duration; tapping fires `onProjectTap`.

**Files:**
- Create: `lib/widgets/dashboard/recent_projects_card.dart`
- Create: `test/widgets/dashboard/recent_projects_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/widgets/dashboard/recent_projects_card_test.dart
//
// Pins the row content (name, transliteration flow copy, duration format),
// the empty state, and the View All callback. The card takes a plain list so
// no provider/fake is needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_shell_theme.dart';
import 'package:romasubai_frontend/widgets/dashboard/recent_projects_card.dart';

Widget _host({
  required List<Map<String, dynamic>> projects,
  void Function(Map<String, dynamic>)? onProjectTap,
  VoidCallback? onViewAll,
}) {
  return MaterialApp(
    theme: buildAppTheme(false),
    home: Scaffold(
      body: RecentProjectsCard(
        projects: projects,
        onProjectTap: onProjectTap ?? (_) {},
        onViewAll: onViewAll ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders a project row with name and transliteration flow',
      (tester) async {
    await tester.pumpWidget(_host(projects: [
      {
        'file_id': 'f1',
        'project_name': 'Interview_Raw_01',
        'original_filename': 'Interview_Raw_01.mp4',
        'is_video': true,
        'file_duration': 2720, // 45:20
        'created_at': '2026-07-17T10:42:00Z',
      },
    ]));
    expect(find.text('Interview_Raw_01'), findsOneWidget);
    expect(find.text('Urdu → Roman Urdu'), findsOneWidget);
    expect(find.text('45:20'), findsOneWidget);
  });

  testWidgets('formats an hour-plus duration as H:MM:SS', (tester) async {
    await tester.pumpWidget(_host(projects: [
      {
        'file_id': 'f2',
        'project_name': 'Podcast',
        'is_video': false,
        'file_duration': 4325, // 1:12:05
        'created_at': '2026-07-16T09:00:00Z',
      },
    ]));
    expect(find.text('1:12:05'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no projects',
      (tester) async {
    await tester.pumpWidget(_host(projects: const []));
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('View All fires its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(projects: const [], onViewAll: () => tapped = true));
    await tester.tap(find.text('View All'));
    expect(tapped, isTrue);
  });

  testWidgets('tapping a row fires onProjectTap with the project', (tester) async {
    Map<String, dynamic>? got;
    await tester.pumpWidget(_host(
      projects: [
        {'file_id': 'f9', 'project_name': 'Clip', 'is_video': true, 'created_at': '2026-07-17T10:00:00Z'},
      ],
      onProjectTap: (p) => got = p,
    ));
    await tester.tap(find.text('Clip'));
    expect(got?['file_id'], 'f9');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/recent_projects_card_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Create the widget**

```dart
// FrontEnd/lib/widgets/dashboard/recent_projects_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

/// A bordered card listing the most recent subtitle projects (max [maxRows]),
/// with a "View All" action. Rows are plain maps from `/subtitles/list/projects`.
class RecentProjectsCard extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final void Function(Map<String, dynamic>) onProjectTap;
  final VoidCallback onViewAll;
  final int maxRows;

  const RecentProjectsCard({
    super.key,
    required this.projects,
    required this.onProjectTap,
    required this.onViewAll,
    this.maxRows = 4,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = projects.take(maxRows).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.md, AppSizes.sm, AppSizes.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.dashRecentProjects,
                  style: text.labelSmall?.copyWith(letterSpacing: 0.5),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(AppStrings.dashViewAll),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (rows.isEmpty)
            _empty(context)
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              _ProjectRow(project: rows[i], onTap: () => onProjectTap(rows[i])),
            ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded,
              size: AppSizes.iconLg, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSizes.sm),
          Text(AppStrings.dashNoProjects, style: text.titleMedium),
          const SizedBox(height: AppSizes.xs),
          Text(
            AppStrings.dashNoProjectsHint,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onTap;

  const _ProjectRow({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isVideo = project['is_video'] == true;
    final name = (project['project_name'] ??
            project['original_filename'] ??
            'Untitled')
        .toString();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.sm),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                isVideo ? Icons.movie_rounded : Icons.audiotrack_rounded,
                size: AppSizes.iconSm,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppStrings.dashProjectFlow,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              _formatProjectDate(project['created_at']),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSizes.md),
            Text(
              _formatDuration(project['file_duration']),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// "45:20" for < 1h, "1:12:05" for >= 1h, "--:--" when unknown.
String _formatDuration(dynamic seconds) {
  if (seconds is! num) return '--:--';
  final total = seconds.floor();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) {
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  }
  return '$m:$ss';
}

/// "Today, 10:42 AM" / "Yesterday" / "MMM d, y". Falls back to "" on bad input.
String _formatProjectDate(dynamic iso) {
  if (iso is! String) return '';
  DateTime dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return 'Today, ${DateFormat.jm().format(dt)}';
  if (diffDays == 1) return 'Yesterday';
  return DateFormat.yMMMd().format(dt);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd FrontEnd && flutter test test/widgets/dashboard/recent_projects_card_test.dart`
Expected: PASS (5 tests). If the "Today, 10:42 AM" case ever flakes on a machine in a far timezone, note it uses local time by design — the fixed test dates avoid the today/yesterday branches except where intended.

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/widgets/dashboard/recent_projects_card.dart FrontEnd/test/widgets/dashboard/recent_projects_card_test.dart
git commit -m "feat(dashboard): RecentProjectsCard with date/duration formatting + empty state"
```

---

## Task 8: UploadDropzone widget

The dashed drop zone: cloud icon, title, subtitle, format chips, and a tap target. Drag-and-drop hardware varies by platform, so this widget exposes an `onTap` (file pick) and treats the whole surface as the tap target; visual drag affordance is cosmetic.

**Files:**
- Create: `lib/widgets/dashboard/upload_dropzone.dart`

> No dedicated widget test: this widget is pure presentation over an `onTap` callback with no branching logic. It is exercised through the dashboard smoke coverage in Task 9. (Adding a test that only asserts static text renders would be low-value per the repo's testing convention.)

- [ ] **Step 1: Create the widget**

```dart
// FrontEnd/lib/widgets/dashboard/upload_dropzone.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';

/// The dashed upload target on the dashboard. Tapping anywhere fires [onTap]
/// (opens the file picker). [compact] drops the chip row on narrow layouts.
class UploadDropzone extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;

  const UploadDropzone({super.key, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: DottedBorderBox(
        color: scheme.outlineVariant,
        radius: AppSizes.radiusLg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.xl),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(Icons.cloud_upload_outlined,
                    size: 30, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSizes.md),
              Text(AppStrings.dashUploadTitle,
                  textAlign: TextAlign.center,
                  style: text.titleMedium),
              const SizedBox(height: AppSizes.xs),
              Text(
                AppStrings.dashUploadSubtitle,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSizes.md),
              if (compact)
                Text(AppStrings.dashUploadTapHint,
                    style: text.bodySmall?.copyWith(color: scheme.primary))
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    _chip(context, Icons.movie_outlined, 'MP4, MOV, MKV'),
                    _chip(context, Icons.audio_file_outlined, 'MP3, WAV'),
                    _chip(context, Icons.warning_amber_rounded,
                        AppStrings.dashMaxSize,
                        emphasize: true),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label,
      {bool emphasize = false}) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: emphasize ? AppPalette.tealSubtle : scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
            color: emphasize ? scheme.primary.withOpacity(0.2) : scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSizes.xs),
          Text(label, style: text.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// A rectangle with a dashed border, painted with a [CustomPainter] since
/// Flutter has no built-in dashed border. Keeps the drop zone read-as-droppable.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final len = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, len), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) =>
      old.color != color || old.radius != radius;
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `cd FrontEnd && flutter analyze lib/widgets/dashboard/upload_dropzone.dart`
Expected: No errors. (If `withOpacity` is deprecation-warned on this Flutter version, switch to `withValues(alpha: 0.2)` to match the editor code's convention.)

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/widgets/dashboard/upload_dropzone.dart
git commit -m "feat(dashboard): UploadDropzone with dashed border + format chips"
```

---

## Task 9: Rebuild the dashboard screen

Assemble everything: scoped `buildAppTheme` wrapper, greeting header, responsive two-column-vs-stacked body, upload zone + recent projects on the left, stat cards + system status on the right. Keep the existing `_handleFilePicker` flow intact.

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Replace the screen**

Replace the entire contents of `lib/screens/dashboard/dashboard_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_shell_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/upload_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/library_providers.dart';
import '../../services/api/api_config.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/system_status_card.dart';
import '../../widgets/dashboard/recent_projects_card.dart';
import '../../widgets/dashboard/upload_dropzone.dart';
import '../../widgets/dialogs/upload_progress_dialog.dart';

/// The Dashboard tab. Opts into the redesigned system via a scoped
/// [buildAppTheme] wrapper; the shell chrome around it keeps the old look.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _handleFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ApiConfig.allowedExtensions,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        _snack('Failed to access file path');
        return;
      }

      if (mounted) showUploadProgressDialog(context);
      await ref
          .read(uploadNotifierProvider.notifier)
          .uploadAndTranscribe(filePath, language: 'ur');
    } catch (e) {
      _snack('File picker error: ${e.toString()}');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProject(Map<String, dynamic> project) {
    AppRoutes.to(
      context,
      AppRoutes.editor,
      arguments: {'fileId': project['file_id'], 'transcription': null},
    );
  }

  void _goToProjectsTab() {
    // The Projects tab is index 1 in the shell (Dashboard, Projects, Exports,
    // Feedback, Settings). navIndexProvider drives the IndexedStack.
    ref.read(navIndexProvider.notifier).state = 1;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 17) return 'Good Evening';
    if (hour >= 12) return 'Good Afternoon';
    return 'Good Morning';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final authState = ref.watch(authNotifierProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final exportsAsync = ref.watch(exportsProvider);
    final healthAsync = ref.watch(systemHealthProvider);

    final firstName = authState.user?.firstName ?? '';
    final projects = projectsAsync.asData?.value ?? const [];

    return Theme(
      data: buildAppTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isEmpty
                        ? _greeting()
                        : '${_greeting()}, $firstName',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    AppStrings.dashUploadSubtitle,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final mainColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          UploadDropzone(
                            onTap: _handleFilePicker,
                            compact: constraints.maxWidth <
                                AppSizes.breakpointMobile,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          RecentProjectsCard(
                            projects: projects,
                            onProjectTap: _openProject,
                            onViewAll: _goToProjectsTab,
                          ),
                        ],
                      );
                      final rail = _Rail(
                        totalProjects: projectsAsync.asData?.value.length,
                        totalExports: exportsAsync.asData?.value.length,
                        health: healthAsync,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            mainColumn,
                            const SizedBox(height: AppSizes.lg),
                            rail,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mainColumn),
                          const SizedBox(width: AppSizes.lg),
                          SizedBox(width: 320, child: rail),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The right rail: two stat cards over the system-status card.
class _Rail extends StatelessWidget {
  final int? totalProjects;
  final int? totalExports;
  final AsyncValue<dynamic> health; // AsyncValue<SystemHealth>

  const _Rail({
    required this.totalProjects,
    required this.totalExports,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.folder_outlined,
                label: AppStrings.dashTotalProjects,
                value: totalProjects?.toString(),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: StatCard(
                icon: Icons.download_outlined,
                label: AppStrings.dashExports,
                value: totalExports?.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        health.when(
          data: (h) => SystemStatusCard(health: h),
          loading: () => const SystemStatusCard(
              health: SystemHealthLoadingPlaceholder.value),
          error: (_, __) => const SystemStatusCard(
              health: SystemHealthLoadingPlaceholder.unreachable),
        ),
      ],
    );
  }
}
```

> The `_Rail.health` field is typed `AsyncValue<dynamic>` only to keep this file from needing to import `SystemHealth` twice; the `.when` branches produce concrete `SystemHealth` values. If you prefer strict typing, import `SystemHealth` and type it `AsyncValue<SystemHealth>` — either compiles.

- [ ] **Step 2: Add the two placeholder constants the loading/error branches use**

The `_Rail` above references `SystemHealthLoadingPlaceholder.value` / `.unreachable`. Add them to `lib/models/system_health.dart` (end of file):

```dart

/// Convenience constants for the dashboard rail's loading/error branches,
/// so the status card always has a concrete value to render.
class SystemHealthLoadingPlaceholder {
  const SystemHealthLoadingPlaceholder._();

  /// Shown while `/health` is in flight — reachable-unknown treated as up,
  /// with no model info yet.
  static const SystemHealth value = SystemHealth(reachable: true);

  /// Shown when the provider errored outright.
  static const SystemHealth unreachable = SystemHealth.unreachable();
}
```

Then import the model in `dashboard_screen.dart` (add with the other imports):

```dart
import '../../models/system_health.dart';
```

- [ ] **Step 3: Verify `authState.user?.firstName` and `navIndexProvider` names**

The rebuild assumes `authState.user?.firstName` and `navIndexProvider` (a `StateProvider<int>`). Confirm the exact names:

Run: `cd FrontEnd && grep -rn 'firstName\|first_name' lib/providers/auth_provider.dart lib/models/ | head` and `grep -rn 'navIndexProvider' lib/providers/nav_provider.dart`
Expected: a `firstName` accessor on the user model and a `navIndexProvider` declaration.
- If the greeting field is named differently (e.g. `fullName`/`name`), adjust the `firstName` line accordingly.
- If `navIndexProvider` is a `StateProvider`, `ref.read(navIndexProvider.notifier).state = 1` is correct. If it is a `NotifierProvider` with a method (e.g. `setIndex`), call that method instead. Match the existing sidebar's navigation call in `lib/widgets/sidebar/sidebar.dart`.

- [ ] **Step 4: Analyze and run the whole suite**

Run: `cd FrontEnd && flutter analyze && flutter test`
Expected: No analyze errors; all tests pass (the earlier 41 + the new dashboard/model/theme tests).

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/screens/dashboard/dashboard_screen.dart FrontEnd/lib/models/system_health.dart
git commit -m "feat(dashboard): rebuild against design system — greeting, upload, recents, honest rail"
```

---

## Task 10: Delete the dead code

Three files are dead. Delete each only after confirming nothing imports it.

**Files:**
- Delete: `lib/providers/project_provider.dart`
- Delete: `lib/widgets/dashboard/processing_history.dart`
- Delete: `lib/widgets/dashboard/transcription_preview.dart`

- [ ] **Step 1: Confirm `project_provider.dart` is unreferenced, then delete**

Run: `cd FrontEnd && grep -rn "project_provider\|ProjectProvider" lib/ test/`
Expected: hits only inside `lib/providers/project_provider.dart` itself (its own class). No importers.
Then: `git rm FrontEnd/lib/providers/project_provider.dart`

- [ ] **Step 2: Confirm the two stubs are unreferenced, then delete**

Run: `cd FrontEnd && grep -rn "processing_history\|transcription_preview\|ProcessingHistory\|TranscriptionPreview" lib/ test/`
Expected: no hits (both files are `// Placeholder` one-liners with no class).
Then: `git rm FrontEnd/lib/widgets/dashboard/processing_history.dart FrontEnd/lib/widgets/dashboard/transcription_preview.dart`

- [ ] **Step 3: Verify nothing broke**

Run: `cd FrontEnd && flutter analyze && flutter test`
Expected: No analyze errors; all tests pass.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(dashboard): remove dead sample-data provider and placeholder stubs"
```

---

## Task 11: Verify in the running app

Tests prove logic; they do not prove the screen renders. Drive the real app.

- [ ] **Step 1: Launch and reach the dashboard**

Run: `cd FrontEnd && flutter run -d chrome` (or `-d linux`). Log in, land on the dashboard. Because fonts/assets are already bundled, no clean rebuild is needed — but if styles look stale from a prior hot-reload, do a full restart (`R`).

- [ ] **Step 2: Check against the intent**

Confirm by eye:
- Greeting shows "Good {time}, {firstName}".
- Upload drop zone has a dashed border, cloud icon, and the three format chips; clicking it opens the file picker.
- Recent Projects card lists real projects (or the empty state if none); "View All" switches to the Projects tab; clicking a row opens the editor.
- Right rail: Total Projects and Exports show real counts (numbers, not em dashes, once loaded); System Status shows a green "Online" dot and the configured model strings — and the word "Translation" appears nowhere.
- Toggle dark mode (theme toggle): the dashboard recolours via the derived dark palette without unreadable contrast.
- Narrow the window below ~900px: the rail drops beneath the main column. Below 600px: the drop zone shows the tap hint instead of chips.

- [ ] **Step 3: Note any dark-mode contrast issues**

The dark palette is derived, not designed (`app_palette.dart` header). If any dashboard surface is low-contrast in dark mode, record it for the palette review rather than patching ad hoc here.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix(dashboard): render fixes from in-app verification"
```

(Skip if nothing needed fixing.)

---

## Self-Review (completed by plan author)

**Spec coverage** — every decision from the four clarifying questions is implemented:
- Responsive (desktop row / stacked below 900 / compact drop zone below 600): Task 9.
- Fresh visual direction reusing the design system, `AppPalette` kept: Tasks 2, 5-9.
- All-screens scope is a program; this plan is the Dashboard slice of it.
- Right rail = real counts + honest status: Tasks 4, 5, 6, 9.
- Greeting kept: Task 9.
- Honest ping + configured backend: Tasks 4, 6.
- Plan-first delivery: this document.

**Placeholder scan** — no "TBD"/"handle appropriately"; every widget and test has full code. The two runtime-name checks (Task 9 Step 3: `firstName`, `navIndexProvider`) are verification steps against existing code, not invented logic — the fallbacks are spelled out.

**Type consistency** — `SystemHealth` fields (`reachable`, `whisperModel`, `transliterationModel`, `device`) are used identically in the model, provider, card, and tests. `buildAppTheme(bool)` / `buildEditorTheme(bool)` signatures match across Tasks 2 and 5-9. `projectsProvider`/`exportsProvider`/`systemHealthProvider` are defined once in `library_providers.dart` and imported everywhere else.

**Known soft spots flagged for the reviewer:**
1. Task 9 Step 3 depends on the real names of the user's first-name field and the nav provider's mutation API. Verified to exist by grep during planning (`firstName`/`first_name` and `navIndexProvider`), but the exact call shape is confirmed at implementation time against `sidebar.dart`.
2. The status card renders raw model ids (e.g. `facebook/m2m100_418M`). That is honest but not pretty; a friendly-name mapping needs a backend field and is deliberately deferred.
3. Dark palette is derived; Task 11 Step 3 routes any contrast issues to the separate palette review rather than fixing them here.
