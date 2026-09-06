# Subtitle Editor Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new design-token layer (palette, typography, bundled Urdu font) and rebuild the Subtitle Editor against it, matching the Stitch design at `Documentation/design/screens/subtitle-editor.png`.

**Architecture:** The new design system lives in `lib/core/design/` and is applied via a **scoped `Theme` wrapper around the editor only**. The existing `AppColors`/`AppTheme` are left untouched, so the 13 un-redesigned screens keep working and looking exactly as they do today. Screens opt into the new system one at a time as they get redesigned. The editor's panel order changes from `[video | list | inspector]` to `[list | video | inspector]` with a segment timeline beneath the video.

**Tech Stack:** Flutter 3 / Dart ^3.8.1, flutter_riverpod ^2.5.1 (existing `StateNotifierProvider`s are kept as-is), media_kit, flutter_test. Fonts: Inter, JetBrains Mono, Noto Nastaliq Urdu (bundled variable TTFs, OFL).

---

## Context an implementer needs

**Working directory is `FrontEnd/`.** All `flutter` commands run there. All Dart paths below are relative to `FrontEnd/`.

**Design source of truth:**
- Screenshot: `Documentation/design/screens/subtitle-editor.png` (2560×2048)
- Markup with exact values: `Documentation/design/html/subtitle-editor.html`
- Product constraints: `Documentation/PRODUCT_OVERVIEW.md` §4

**Four things in the Stitch mockup are deliberately NOT built** (decided with the user):
1. The **waveform** in the timeline — needs a backend peaks endpoint. We build segment blocks on a time axis instead.
2. **"Pro Editor"** under the logo — invented tier, does not exist.
3. The **notification bell** — no notification system exists.
4. The **"Edit" link on the Urdu field** — Urdu is read-only by design (`PRODUCT_OVERVIEW.md` §4).

**One mockup string is factually wrong and must NOT be copied:** the mockup says *"AI Translation Active"*. This product does **transliteration**, not translation — script conversion, same language. Use **"AI Transliteration Active"**. Getting this wrong misrepresents the entire product.

**Dark mode is derived, not designed.** Stitch produced a light palette only. The dark values in Task 4 are derived using Material 3 tonal conventions from the same teal. They are a reasonable starting point, not an approved design — flag them for review rather than treating them as spec.

**Known landmines in the existing code** (verified, with line numbers):
- `test/widget_test.dart` is the unmodified `flutter create` counter template. **`flutter test` is red today.** Task 1 fixes this first — TDD is meaningless against a red baseline.
- `EditableSegment` fields are **non-final**; `EditorNotifier.updateSegmentText/Timing` mutate in place. Don't assume value equality — there is no `==` override.
- `SubtitleProject` has **no `copyWith`**; the provider hand-rebuilds all 10 fields in 3 places (`subtitle_editor_provider.dart:306`, `:349`, `:415`).
- `subtitle_list_panel.dart:32` hardcodes `index * 70.0` as tile height for auto-scroll. **Task 8 changes tile height — Task 8 must fix this too or auto-scroll silently drifts.**
- Only `SegmentTile` and `TimingAdjuster` take constructor params. The other 6 editor widgets read Riverpod directly, so widget-testing them needs `ProviderScope(overrides:)`. There is **no mocktail/mockito** — Task 6 adds a hand-written fake, matching the repo's existing no-mocks convention.
- Existing test convention (`test/transcription_complete_dialog_export_test.dart`): repo-relative path comment line 1, rationale block, private `_host({...})` builder, `find.text` assertions, callbacks stubbed as `(_) {}`.

---

## File Structure

**Create:**
| Path | Responsibility |
|---|---|
| `assets/fonts/Inter.ttf` | Latin UI text (variable wght) |
| `assets/fonts/JetBrainsMono.ttf` | Timecodes (variable wght) |
| `assets/fonts/NotoNastaliqUrdu.ttf` | Urdu script (variable wght) |
| `assets/fonts/OFL.txt` | License text for all three |
| `lib/core/design/app_palette.dart` | `AppPalette` — M3 color roles, light + dark, and `ColorScheme` builders |
| `lib/core/design/app_typography.dart` | `AppTypography` — `latin`/`mono`/`urdu` styles + `TextTheme` builder |
| `lib/core/design/editor_theme.dart` | `EditorTheme` ThemeExtension (timeline/overlay/segment colors) + `buildEditorTheme()` |
| `lib/widgets/editor/segment_timeline.dart` | `SegmentTimeline` — time axis, segment blocks, playhead, zoom |
| `test/core/design/app_typography_test.dart` | Typography unit tests |
| `test/models/editable_segment_metrics_test.dart` | CPS + overlap unit tests |
| `test/models/subtitle_project_copywith_test.dart` | `copyWith` unit tests |
| `test/widgets/editor/segment_tile_test.dart` | SegmentTile widget tests |
| `test/widgets/editor/segment_timeline_test.dart` | Timeline widget tests |

No test fake is needed: every widget this plan tests (`SegmentTile`, `SegmentTimeline`, `TimelineBlock`) takes its data as constructor params, so the repo's existing no-mocks convention holds. The Riverpod-reading widgets are modified but not newly tested — testing those would need `ProviderScope(overrides:)` against `subtitleServiceProvider`, which is a separate piece of work.

**Modify:**
| Path | Change |
|---|---|
| `test/widget_test.dart` | Replace broken template with a real smoke test |
| `pubspec.yaml` | Add `fonts:` block (none exists) + `assets/fonts/` |
| `lib/models/subtitle_project_model.dart` | Add `EditableSegment.charsPerSecond`, `overlapsNext`; add `SubtitleProject.copyWith` |
| `lib/providers/subtitle_editor_provider.dart:306,349,415` | Use the new `copyWith` |
| `lib/widgets/editor/segment_tile.dart` | Redesign; render the dead `onDelete`; add overlap warning |
| `lib/widgets/editor/subtitle_list_panel.dart:32` | Fix hardcoded 70px scroll metric |
| `lib/widgets/editor/text_editor_panel.dart` | Rebuild as Inspector; Urdu via `AppTypography.urdu`; CPS readout; correct copy |
| `lib/widgets/editor/editor_toolbar.dart` | Restyle to new palette; teal Export button |
| `lib/screens/editor/subtitle_editor_screen.dart` | Scoped theme; reorder panels; add timeline; fix stale doc comments |

---

## Task 1: Get the test suite green

`flutter test` fails today because `test/widget_test.dart` is the `flutter create` counter template pointing at a `MyApp` that has no counter, and pumps a `ConsumerWidget` without a `ProviderScope`. Every later task depends on a green baseline.

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Confirm the baseline is red**

Run: `cd FrontEnd && flutter test test/widget_test.dart`
Expected: FAIL — `Could not find the correct Provider` or `Expected: exactly one matching node ... Actual: _TextFinder:<zero widgets with text "0">`

- [ ] **Step 2: Replace the template with a real smoke test**

```dart
// FrontEnd/test/widget_test.dart
//
// Smoke test: MyApp is a ConsumerWidget that reads themeProvider in build(),
// so it must be pumped inside a ProviderScope. This replaces the flutter
// create counter template, which referenced a counter this app never had.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/main.dart';

void main() {
  testWidgets('MyApp builds a MaterialApp inside a ProviderScope',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it**

Run: `cd FrontEnd && flutter test test/widget_test.dart`
Expected: PASS (1 test)

- [ ] **Step 4: Confirm the whole suite is green**

Run: `cd FrontEnd && flutter test`
Expected: All tests pass. Baseline is 3 files — `widget_test.dart` (1), `subtitle_project_is_video_test.dart` (4), `transcription_complete_dialog_export_test.dart` (3).

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/test/widget_test.dart
git commit -m "test: replace flutter create template with a real smoke test"
```

---

## Task 2: Bundle the fonts

The app declares **no fonts at all**. Urdu currently renders via OS fallback — `fontFamilyFallback: ['Arial', 'Segoe UI', 'Microsoft Sans Serif']` (`app_theme.dart:39` et al), none of which support Nastaʿlīq. On Linux this is tofu boxes. Bundling (not `google_fonts`) because the product has an offline mode and a demo must not depend on network.

**Files:**
- Create: `assets/fonts/{Inter,JetBrainsMono,NotoNastaliqUrdu}.ttf`, `assets/fonts/OFL.txt`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Download the fonts**

```bash
cd /home/muttayyab/Desktop/RomaSub.Ai/FrontEnd
mkdir -p assets/fonts
curl -sSL -o assets/fonts/NotoNastaliqUrdu.ttf \
  "https://github.com/google/fonts/raw/main/ofl/notonastaliqurdu/NotoNastaliqUrdu%5Bwght%5D.ttf"
curl -sSL -o assets/fonts/Inter.ttf \
  "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
curl -sSL -o assets/fonts/JetBrainsMono.ttf \
  "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"
curl -sSL -o assets/fonts/OFL.txt \
  "https://github.com/google/fonts/raw/main/ofl/notonastaliqurdu/OFL.txt"
```

- [ ] **Step 2: Verify they are real TrueType files, not HTML error pages**

Run: `cd FrontEnd && file assets/fonts/*.ttf && du -h assets/fonts/*.ttf`
Expected: each reports `TrueType Font data`. Approx sizes: NotoNastaliqUrdu 674K, Inter 856K, JetBrainsMono 183K.

- [ ] **Step 3: Declare them in pubspec.yaml**

In `pubspec.yaml`, the `flutter:` section currently reads:

```yaml
flutter:
  uses-material-design: true
  
  assets:
    - assets/images/logos/
```

Replace with:

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/logos/
    - assets/fonts/

  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter.ttf
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono.ttf
    - family: NotoNastaliqUrdu
      fonts:
        - asset: assets/fonts/NotoNastaliqUrdu.ttf
```

These are variable fonts; Flutter maps `fontWeight` onto the `wght` axis, so one asset per family covers all weights.

- [ ] **Step 4: Verify the manifest resolves**

Run: `cd FrontEnd && flutter pub get && flutter test`
Expected: `pub get` succeeds, all tests still pass.

- [ ] **Step 5: Commit**

```bash
cd /home/muttayyab/Desktop/RomaSub.Ai
git add FrontEnd/assets/fonts FrontEnd/pubspec.yaml
git commit -m "feat(design): bundle Inter, JetBrains Mono, and Noto Nastaliq Urdu"
```

---

## Task 3: Typography

Latin and Urdu need different families, sizes, and line heights. Nastaʿlīq needs roughly double line height for its descending kerns — the current overlay uses `height: 1.3`, far too tight. Per `PRODUCT_OVERVIEW.md` §4, Urdu must render **larger** than Latin at the same nominal size to be optically equal.

**Files:**
- Create: `lib/core/design/app_typography.dart`
- Test: `test/core/design/app_typography_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/core/design/app_typography_test.dart
//
// Urdu (Nastaliq) and Latin have different metric needs. These tests pin the
// two properties that are easy to regress and that visibly break Urdu:
// the font family, and the generous line height Nastaliq descenders require.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/app_typography.dart';

void main() {
  group('AppTypography.latin', () {
    test('uses Inter', () {
      expect(AppTypography.latin(size: 14).fontFamily, 'Inter');
    });

    test('passes through size, weight, and height', () {
      final style = AppTypography.latin(size: 18, weight: FontWeight.w600);
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, AppTypography.latinHeight);
    });
  });

  group('AppTypography.mono', () {
    test('uses JetBrainsMono for timecodes', () {
      expect(AppTypography.mono(size: 12).fontFamily, 'JetBrainsMono');
    });
  });

  group('AppTypography.urdu', () {
    test('uses NotoNastaliqUrdu', () {
      expect(AppTypography.urdu(size: 14).fontFamily, 'NotoNastaliqUrdu');
    });

    test('applies the tall line height Nastaliq needs', () {
      expect(AppTypography.urdu(size: 14).height, AppTypography.urduHeight);
      expect(AppTypography.urduHeight, greaterThanOrEqualTo(1.8));
    });

    test('renders optically larger than Latin at the same nominal size', () {
      final latin = AppTypography.latin(size: 14);
      final urdu = AppTypography.urdu(size: 14);
      expect(urdu.fontSize, greaterThan(latin.fontSize!));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd FrontEnd && flutter test test/core/design/app_typography_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'romasubai_frontend' ... app_typography.dart` / target of URI doesn't exist.

- [ ] **Step 3: Implement**

```dart
// FrontEnd/lib/core/design/app_typography.dart
import 'package:flutter/material.dart';

/// Typography for the redesigned surfaces.
///
/// Three families, each with a distinct job:
/// - [latin] (Inter)          — all UI chrome and Roman Urdu caption text
/// - [mono] (JetBrains Mono)  — timecodes, where digit alignment matters
/// - [urdu] (Noto Nastaliq)   — native Urdu script
///
/// Urdu is not Latin with a different alphabet. Nastaliq cascades downward,
/// so it needs roughly double the line height, and at an equal nominal size
/// it reads smaller than Latin — hence [urduScale].
class AppTypography {
  const AppTypography._();

  static const String latinFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';
  static const String urduFamily = 'NotoNastaliqUrdu';

  /// Comfortable Latin line height for UI text.
  static const double latinHeight = 1.45;

  /// Nastaliq needs room for descending kerns. Below ~1.8 the script clips.
  static const double urduHeight = 2.0;

  /// Urdu renders optically smaller than Latin at the same point size.
  static const double urduScale = 1.25;

  static TextStyle latin({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: latinFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? latinHeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3,
    );
  }

  /// [size] is the *nominal* size — the Latin size this Urdu should sit
  /// beside. The returned style is scaled up by [urduScale] so the two read
  /// as equals rather than as text and footnote.
  static TextStyle urdu({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: urduFamily,
      fontSize: size * urduScale,
      fontWeight: weight,
      color: color,
      height: urduHeight,
    );
  }

  /// Material [TextTheme] for the redesigned surfaces, built from [latin].
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: latin(size: 32, weight: FontWeight.w700, color: primary),
      headlineMedium: latin(size: 24, weight: FontWeight.w600, color: primary),
      titleLarge: latin(size: 18, weight: FontWeight.w600, color: primary),
      titleMedium: latin(size: 16, weight: FontWeight.w600, color: primary),
      bodyLarge: latin(size: 16, color: primary),
      bodyMedium: latin(size: 14, color: primary),
      bodySmall: latin(size: 12, color: secondary),
      labelLarge: latin(size: 14, weight: FontWeight.w600, color: primary),
      labelMedium: latin(size: 12, weight: FontWeight.w500, color: secondary),
      labelSmall: latin(size: 11, weight: FontWeight.w500, color: secondary),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `cd FrontEnd && flutter test test/core/design/app_typography_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/core/design/app_typography.dart FrontEnd/test/core/design/app_typography_test.dart
git commit -m "feat(design): add AppTypography with Latin/mono/Urdu styles"
```

---

## Task 4: Palette

Values extracted from `Documentation/design/html/subtitle-editor.html`. **Light is from Stitch. Dark is derived** using M3 tonal conventions from the same teal — flag for review.

Note this fixes a real bug in the old system: the teal brand accent was never in either `ColorScheme` (`app_theme.dart:15-20`, `:154-159` set only 4 slots), so `colorScheme.primary` was black/white and teal only reached the UI through explicit `AppColors.accentStrong` references.

**Files:**
- Create: `lib/core/design/app_palette.dart`

- [ ] **Step 1: Implement**

```dart
// FrontEnd/lib/core/design/app_palette.dart
import 'package:flutter/material.dart';

/// Colour roles for the redesigned surfaces.
///
/// Light values come from the Stitch design
/// (`Documentation/design/html/subtitle-editor.html`).
///
/// Dark values are DERIVED, not designed — Stitch produced a light palette
/// only. They follow Material 3 tonal conventions from the same teal and are
/// a starting point pending design review.
class AppPalette {
  const AppPalette._();

  // ---- Light (from Stitch) ----
  static const Color primary = Color(0xFF00685F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF008378);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFF89F5E7);
  static const Color primaryFixedDim = Color(0xFF6BD8CB);
  static const Color tealSubtle = Color(0xFFF0FDFA);

  static const Color secondary = Color(0xFF565E74);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDAE2FD);
  static const Color onSecondaryContainer = Color(0xFF131C2B);

  static const Color background = Color(0xFFF8F9FF);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceBright = Color(0xFFF8F9FF);

  static const Color onSurface = Color(0xFF191C20);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color outline = Color(0xFF73777F);
  static const Color outlineVariant = Color(0xFFC3C7CF);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  /// The video stage — always dark, in both themes. Video is watched against
  /// black regardless of app theme.
  static const Color videoStage = Color(0xFF0B1C30);

  // ---- Dark (derived) ----
  static const Color primaryDark = Color(0xFF6BD8CB);
  static const Color onPrimaryDark = Color(0xFF00382F);
  static const Color primaryContainerDark = Color(0xFF005048);
  static const Color onPrimaryContainerDark = Color(0xFF89F5E7);
  static const Color tealSubtleDark = Color(0xFF10302C);

  static const Color secondaryDark = Color(0xFFBEC6E0);
  static const Color onSecondaryDark = Color(0xFF283141);
  static const Color secondaryContainerDark = Color(0xFF3E4759);
  static const Color onSecondaryContainerDark = Color(0xFFDAE2FD);

  static const Color backgroundDark = Color(0xFF0E1417);
  static const Color surfaceDarkColor = Color(0xFF0E1417);
  static const Color surfaceContainerLowestDark = Color(0xFF090F11);
  static const Color surfaceContainerLowDark = Color(0xFF161C1F);
  static const Color surfaceContainerDark = Color(0xFF1A2023);
  static const Color surfaceContainerHighDark = Color(0xFF242B2E);
  static const Color surfaceContainerHighestDark = Color(0xFF2F3639);
  static const Color surfaceDimDark = Color(0xFF0E1417);
  static const Color surfaceBrightDark = Color(0xFF343A3D);

  static const Color onSurfaceDark = Color(0xFFE1E3E5);
  static const Color onSurfaceVariantDark = Color(0xFFC0C8CC);
  static const Color outlineDark = Color(0xFF8A9296);
  static const Color outlineVariantDark = Color(0xFF40484C);

  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorDark = Color(0xFF690005);
  static const Color errorContainerDark = Color(0xFF93000A);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color successDark = Color(0xFF34D399);

  static ColorScheme scheme(bool isDark) =>
      isDark ? _darkScheme : _lightScheme;

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: Color(0xFF410002),
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryDark,
    onPrimary: onPrimaryDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondary: secondaryDark,
    onSecondary: onSecondaryDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    error: errorDark,
    onError: onErrorDark,
    errorContainer: errorContainerDark,
    onErrorContainer: Color(0xFFFFDAD6),
    surface: surfaceDarkColor,
    onSurface: onSurfaceDark,
    onSurfaceVariant: onSurfaceVariantDark,
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
  );
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd FrontEnd && flutter analyze lib/core/design/app_palette.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/core/design/app_palette.dart
git commit -m "feat(design): add AppPalette with M3 colour roles"
```

---

## Task 5: Scoped editor theme

The editor gets its own `Theme`, so the redesign does not leak into the 13 screens that still use `AppColors`. Editor-specific colours (timeline, overlay, segment states) that have no Material role live in a `ThemeExtension`.

**Files:**
- Create: `lib/core/design/editor_theme.dart`

- [ ] **Step 1: Implement**

```dart
// FrontEnd/lib/core/design/editor_theme.dart
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_typography.dart';

/// Editor-specific colours with no Material role.
///
/// Read via `Theme.of(context).extension<EditorTheme>()!`.
@immutable
class EditorTheme extends ThemeExtension<EditorTheme> {
  final Color videoStage;
  final Color timelineTrack;
  final Color timelineBlock;
  final Color timelineBlockSelected;
  final Color timelineBlockBorder;
  final Color playhead;
  final Color segmentActive;
  final Color segmentSelected;
  final Color editedMarker;
  final Color overlapMarker;
  final Color overlayScrim;

  const EditorTheme({
    required this.videoStage,
    required this.timelineTrack,
    required this.timelineBlock,
    required this.timelineBlockSelected,
    required this.timelineBlockBorder,
    required this.playhead,
    required this.segmentActive,
    required this.segmentSelected,
    required this.editedMarker,
    required this.overlapMarker,
    required this.overlayScrim,
  });

  static const EditorTheme light = EditorTheme(
    videoStage: AppPalette.videoStage,
    timelineTrack: AppPalette.surfaceContainerLow,
    timelineBlock: AppPalette.surfaceContainerLowest,
    timelineBlockSelected: AppPalette.tealSubtle,
    timelineBlockBorder: AppPalette.primary,
    playhead: AppPalette.error,
    segmentActive: AppPalette.tealSubtle,
    segmentSelected: AppPalette.tealSubtle,
    editedMarker: AppPalette.warning,
    overlapMarker: AppPalette.error,
    overlayScrim: Color(0xB3000000), // 70% black — PRODUCT_OVERVIEW §6.13
  );

  static const EditorTheme dark = EditorTheme(
    videoStage: AppPalette.videoStage,
    timelineTrack: AppPalette.surfaceContainerLowDark,
    timelineBlock: AppPalette.surfaceContainerHighDark,
    timelineBlockSelected: AppPalette.primaryContainerDark,
    timelineBlockBorder: AppPalette.primaryDark,
    playhead: AppPalette.errorDark,
    segmentActive: AppPalette.tealSubtleDark,
    segmentSelected: AppPalette.tealSubtleDark,
    editedMarker: AppPalette.warningDark,
    overlapMarker: AppPalette.errorDark,
    overlayScrim: Color(0xB3000000),
  );

  @override
  EditorTheme copyWith({
    Color? videoStage,
    Color? timelineTrack,
    Color? timelineBlock,
    Color? timelineBlockSelected,
    Color? timelineBlockBorder,
    Color? playhead,
    Color? segmentActive,
    Color? segmentSelected,
    Color? editedMarker,
    Color? overlapMarker,
    Color? overlayScrim,
  }) {
    return EditorTheme(
      videoStage: videoStage ?? this.videoStage,
      timelineTrack: timelineTrack ?? this.timelineTrack,
      timelineBlock: timelineBlock ?? this.timelineBlock,
      timelineBlockSelected:
          timelineBlockSelected ?? this.timelineBlockSelected,
      timelineBlockBorder: timelineBlockBorder ?? this.timelineBlockBorder,
      playhead: playhead ?? this.playhead,
      segmentActive: segmentActive ?? this.segmentActive,
      segmentSelected: segmentSelected ?? this.segmentSelected,
      editedMarker: editedMarker ?? this.editedMarker,
      overlapMarker: overlapMarker ?? this.overlapMarker,
      overlayScrim: overlayScrim ?? this.overlayScrim,
    );
  }

  @override
  EditorTheme lerp(ThemeExtension<EditorTheme>? other, double t) {
    if (other is! EditorTheme) return this;
    return EditorTheme(
      videoStage: Color.lerp(videoStage, other.videoStage, t)!,
      timelineTrack: Color.lerp(timelineTrack, other.timelineTrack, t)!,
      timelineBlock: Color.lerp(timelineBlock, other.timelineBlock, t)!,
      timelineBlockSelected:
          Color.lerp(timelineBlockSelected, other.timelineBlockSelected, t)!,
      timelineBlockBorder:
          Color.lerp(timelineBlockBorder, other.timelineBlockBorder, t)!,
      playhead: Color.lerp(playhead, other.playhead, t)!,
      segmentActive: Color.lerp(segmentActive, other.segmentActive, t)!,
      segmentSelected: Color.lerp(segmentSelected, other.segmentSelected, t)!,
      editedMarker: Color.lerp(editedMarker, other.editedMarker, t)!,
      overlapMarker: Color.lerp(overlapMarker, other.overlapMarker, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
    );
  }
}

/// The scoped theme the editor wraps itself in.
///
/// Deliberately NOT applied app-wide: the other 13 screens still use
/// AppColors/AppTheme and are redesigned separately.
ThemeData buildEditorTheme(bool isDark) {
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
    extensions: <ThemeExtension<dynamic>>[
      isDark ? EditorTheme.dark : EditorTheme.light,
    ],
  );
}
```

- [ ] **Step 2: Verify**

Run: `cd FrontEnd && flutter analyze lib/core/design/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/core/design/editor_theme.dart
git commit -m "feat(design): add scoped EditorTheme with ThemeExtension"
```

---

## Task 6: Segment metrics — CPS and overlap

The mockup shows a `21.5 CPS` readout and a red overlap warning on segment 3. Both are derivable from data already in hand — no backend work.

CPS (characters per second) is the standard subtitle-legibility metric. Roughly: under 17 is comfortable, over 21 is hard to read at speed. It matters more here than usual — this product exists to make text readable.

**Files:**
- Modify: `lib/models/subtitle_project_model.dart`
- Test: `test/models/editable_segment_metrics_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/models/editable_segment_metrics_test.dart
//
// CPS drives the editor's legibility readout, and overlap detection drives the
// warning icon in the segment list. Both are computed client-side from data we
// already hold, so they are pure and worth pinning precisely.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

EditableSegment _seg({
  int id = 1,
  double start = 0.0,
  double end = 2.0,
  String roman = '',
  String urdu = '',
}) {
  return EditableSegment(
    id: id,
    start: start,
    end: end,
    romanUrduText: roman,
    urduText: urdu,
  );
}

void main() {
  group('charsPerSecond', () {
    test('divides Roman Urdu length by duration', () {
      // 43 chars over 2.0s = 21.5
      final s = _seg(start: 0, end: 2, roman: 'a' * 43);
      expect(s.charsPerSecond, 21.5);
    });

    test('falls back to Urdu text when Roman is empty', () {
      final s = _seg(start: 0, end: 2, urdu: 'ا' * 10);
      expect(s.charsPerSecond, 5.0);
    });

    test('is zero for empty text', () {
      expect(_seg(roman: '').charsPerSecond, 0.0);
    });

    test('is zero rather than infinite for zero duration', () {
      final s = _seg(start: 5, end: 5, roman: 'hello');
      expect(s.charsPerSecond, 0.0);
    });
  });

  group('isComfortableReadingRate', () {
    test('accepts a normal rate', () {
      expect(_seg(start: 0, end: 4, roman: 'a' * 40).isComfortableReadingRate,
          isTrue);
    });

    test('rejects a rate above the threshold', () {
      expect(_seg(start: 0, end: 1, roman: 'a' * 40).isComfortableReadingRate,
          isFalse);
    });
  });

  group('overlapsNext', () {
    test('is false when the gap meets the minimum', () {
      final a = _seg(id: 1, start: 0.0, end: 2.0);
      final b = _seg(id: 2, start: 2.1, end: 4.0);
      expect(a.overlapsNext(b), isFalse);
    });

    test('is true when the next segment starts too soon', () {
      final a = _seg(id: 1, start: 0.0, end: 2.0);
      final b = _seg(id: 2, start: 2.05, end: 4.0);
      expect(a.overlapsNext(b), isTrue);
    });

    test('is true when segments genuinely overlap', () {
      final a = _seg(id: 1, start: 0.0, end: 3.0);
      final b = _seg(id: 2, start: 2.0, end: 4.0);
      expect(a.overlapsNext(b), isTrue);
    });

    test('is false against a null next segment', () {
      expect(_seg().overlapsNext(null), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd FrontEnd && flutter test test/models/editable_segment_metrics_test.dart`
Expected: FAIL — `The getter 'charsPerSecond' isn't defined for the class 'EditableSegment'`

- [ ] **Step 3: Implement**

In `lib/models/subtitle_project_model.dart`, inside `class EditableSegment`, after the `validationError` getter (currently ends at L34), add:

```dart
  /// Minimum gap the backend enforces between segments, in seconds.
  /// Mirrors MIN_GAP_BETWEEN_SEGMENTS in app/services/subtitle.py.
  static const double minGapSeconds = 0.1;

  /// Above this, captions outrun a comfortable reading pace. 21 chars/sec is
  /// the common broadcast-subtitling ceiling.
  static const double maxComfortableCps = 21.0;

  /// The text that actually reaches the viewer: Roman Urdu, falling back to
  /// Urdu. Mirrors the caption rule used everywhere else, including export.
  String get displayText =>
      romanUrduText.isNotEmpty ? romanUrduText : urduText;

  /// Reading rate in characters per second. Zero (not infinity) when the
  /// duration is zero, so the UI never has to render an infinity.
  double get charsPerSecond {
    if (duration <= 0) return 0.0;
    return displayText.length / duration;
  }

  bool get isComfortableReadingRate => charsPerSecond <= maxComfortableCps;

  /// True when [next] starts before this segment ends, or closer than the
  /// backend's minimum gap. Drives the warning marker in the segment list.
  bool overlapsNext(EditableSegment? next) {
    if (next == null) return false;
    return next.start - end < minGapSeconds;
  }
```

- [ ] **Step 4: Run the test**

Run: `cd FrontEnd && flutter test test/models/editable_segment_metrics_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/models/subtitle_project_model.dart FrontEnd/test/models/editable_segment_metrics_test.dart
git commit -m "feat(editor): add CPS and overlap metrics to EditableSegment"
```

---

## Task 7: SubtitleProject.copyWith

`SubtitleProject` has no `copyWith`, so `EditorNotifier` hand-rebuilds all 10 fields in three places (`subtitle_editor_provider.dart:306`, `:349`, `:415`). That is ~30 lines of duplication, and every new field is three places to forget. The timeline (Task 11) reads `fileDuration`, so this gets touched either way.

**Files:**
- Modify: `lib/models/subtitle_project_model.dart`
- Modify: `lib/providers/subtitle_editor_provider.dart`
- Test: `test/models/subtitle_project_copywith_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/models/subtitle_project_copywith_test.dart
//
// EditorNotifier rebuilt SubtitleProject by hand in three places (undo, redo,
// fixTimingOverlaps). copyWith replaces that duplication, so it must preserve
// every field it isn't asked to change — including the nullable fileDuration.
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

SubtitleProject _project({
  List<EditableSegment>? segments,
  double? fileDuration = 120.0,
}) {
  return SubtitleProject(
    subtitleId: 'sub-1',
    fileId: 'file-1',
    projectName: 'Documentary_Ep1_Draft',
    originalFilename: 'Documentary_Ep1_Draft.mp4',
    isVideo: true,
    segments: segments ?? [EditableSegment(id: 1, start: 0, end: 2)],
    segmentCount: segments?.length ?? 1,
    fileDuration: fileDuration,
    createdAt: '2026-07-16T10:00:00Z',
    updatedAt: '2026-07-16T10:00:00Z',
  );
}

void main() {
  test('copyWith preserves every untouched field', () {
    final original = _project();
    final copy = original.copyWith();

    expect(copy.subtitleId, original.subtitleId);
    expect(copy.fileId, original.fileId);
    expect(copy.projectName, original.projectName);
    expect(copy.originalFilename, original.originalFilename);
    expect(copy.isVideo, original.isVideo);
    expect(copy.segments, original.segments);
    expect(copy.segmentCount, original.segmentCount);
    expect(copy.fileDuration, original.fileDuration);
    expect(copy.createdAt, original.createdAt);
    expect(copy.updatedAt, original.updatedAt);
  });

  test('copyWith replaces segments and segmentCount together', () {
    final original = _project();
    final segments = [
      EditableSegment(id: 1, start: 0, end: 2),
      EditableSegment(id: 2, start: 2.5, end: 4),
    ];
    final copy = original.copyWith(
      segments: segments,
      segmentCount: segments.length,
    );

    expect(copy.segments, hasLength(2));
    expect(copy.segmentCount, 2);
    expect(copy.projectName, original.projectName);
  });

  test('copyWith keeps a null fileDuration null', () {
    final original = _project(fileDuration: null);
    expect(original.copyWith().fileDuration, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd FrontEnd && flutter test test/models/subtitle_project_copywith_test.dart`
Expected: FAIL — `The method 'copyWith' isn't defined for the class 'SubtitleProject'`

- [ ] **Step 3: Implement copyWith**

In `lib/models/subtitle_project_model.dart`, inside `class SubtitleProject`, after the constructor (currently ends L116), add:

```dart
  SubtitleProject copyWith({
    String? subtitleId,
    String? fileId,
    String? projectName,
    String? originalFilename,
    bool? isVideo,
    List<EditableSegment>? segments,
    int? segmentCount,
    double? fileDuration,
    String? createdAt,
    String? updatedAt,
  }) {
    return SubtitleProject(
      subtitleId: subtitleId ?? this.subtitleId,
      fileId: fileId ?? this.fileId,
      projectName: projectName ?? this.projectName,
      originalFilename: originalFilename ?? this.originalFilename,
      isVideo: isVideo ?? this.isVideo,
      segments: segments ?? this.segments,
      segmentCount: segmentCount ?? this.segmentCount,
      fileDuration: fileDuration ?? this.fileDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
```

- [ ] **Step 4: Run the test**

Run: `cd FrontEnd && flutter test test/models/subtitle_project_copywith_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Use it in the provider — undo()**

In `lib/providers/subtitle_editor_provider.dart`, `undo()` currently hand-builds a `SubtitleProject` at L306–L317. Replace that construction with:

```dart
      final restoredProject = state.project!.copyWith(
        segments: action.previousSegments,
        segmentCount: action.previousSegments.length,
      );
```

- [ ] **Step 6: Use it in the provider — redo()**

Same file, `redo()` at L349–L360. Replace the hand-built construction with:

```dart
      final restoredProject = state.project!.copyWith(
        segments: action.previousSegments,
        segmentCount: action.previousSegments.length,
      );
```

- [ ] **Step 7: Use it in the provider — fixTimingOverlaps()**

Same file, `fixTimingOverlaps()` at L415. Replace the hand-built construction with:

```dart
      final updatedProject = state.project!.copyWith(
        segments: fixedSegments,
        segmentCount: fixedSegments.length,
      );
```

- [ ] **Step 8: Verify nothing regressed**

Run: `cd FrontEnd && flutter analyze lib/providers/subtitle_editor_provider.dart && flutter test`
Expected: `No issues found!` and all tests pass.

- [ ] **Step 9: Commit**

```bash
git add FrontEnd/lib/models/subtitle_project_model.dart FrontEnd/lib/providers/subtitle_editor_provider.dart FrontEnd/test/models/subtitle_project_copywith_test.dart
git commit -m "refactor(editor): add SubtitleProject.copyWith and use it in EditorNotifier"
```

---

## Task 8: SegmentTile redesign

Matches the mockup's list rows: index, mono timecode range, preview text, and state markers. Three fixes ride along:
1. `onDelete` is currently **required but never rendered** — no delete affordance exists. Render it.
2. The overlap warning from the mockup (red triangle on segment 3) needs a new `hasOverlap` param.
3. Tile height becomes a **named constant**, because `subtitle_list_panel.dart:32` hardcodes `index * 70.0` for auto-scroll and will silently drift otherwise.

`SegmentTile` takes constructor params, so it is directly testable with the repo's existing no-mocks pattern.

**Files:**
- Modify: `lib/widgets/editor/segment_tile.dart`
- Modify: `lib/widgets/editor/subtitle_list_panel.dart:32`
- Test: `test/widgets/editor/segment_tile_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/widgets/editor/segment_tile_test.dart
//
// SegmentTile is one of only two editor widgets with injectable params, so it
// gets real widget tests. Pinned here: the Roman-with-Urdu-fallback caption
// rule, the overlap marker, and the delete affordance — which was a required
// callback that the old tile never rendered.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';
import 'package:romasubai_frontend/widgets/editor/segment_tile.dart';

Widget _host({
  required EditableSegment segment,
  bool isSelected = false,
  bool isActive = false,
  bool matchesSearch = false,
  bool hasOverlap = false,
  VoidCallback? onTap,
  VoidCallback? onDelete,
}) {
  return MaterialApp(
    theme: buildEditorTheme(false),
    home: Scaffold(
      body: SegmentTile(
        segment: segment,
        index: 0,
        isSelected: isSelected,
        isActive: isActive,
        matchesSearch: matchesSearch,
        hasOverlap: hasOverlap,
        onTap: onTap ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('shows the 1-based segment number', (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 7, start: 0, end: 2, romanUrduText: 'hi'),
    ));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('shows Roman Urdu when present', (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(
        id: 1, start: 0, end: 2,
        romanUrduText: 'Iski quality aur speed dono behtareen hain.',
        urduText: 'اس کی کوالٹی',
      ),
    ));
    expect(find.text('Iski quality aur speed dono behtareen hain.'),
        findsOneWidget);
  });

  testWidgets('falls back to Urdu when Roman is empty', (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(
        id: 1, start: 0, end: 2, romanUrduText: '', urduText: 'اس کی کوالٹی',
      ),
    ));
    expect(find.text('اس کی کوالٹی'), findsOneWidget);
  });

  testWidgets('shows the timecode range', (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 72.4, end: 75.2),
    ));
    expect(find.textContaining('00:01:12,400'), findsOneWidget);
    expect(find.textContaining('00:01:15,200'), findsOneWidget);
  });

  testWidgets('marks an edited segment', (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 0, end: 2, isEdited: true),
    ));
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('shows an overlap warning only when overlapping',
      (tester) async {
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 0, end: 2),
      hasOverlap: false,
    ));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 0, end: 2),
      hasOverlap: true,
    ));
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 0, end: 2, romanUrduText: 'hi'),
      onTap: () => tapped = true,
    ));
    await tester.tap(find.text('hi'));
    expect(tapped, isTrue);
  });

  testWidgets('renders a delete affordance when selected and fires onDelete',
      (tester) async {
    var deleted = false;
    await tester.pumpWidget(_host(
      segment: EditableSegment(id: 1, start: 0, end: 2),
      isSelected: true,
      onDelete: () => deleted = true,
    ));

    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    expect(deleted, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd FrontEnd && flutter test test/widgets/editor/segment_tile_test.dart`
Expected: FAIL — `No named parameter with the name 'hasOverlap'`

- [ ] **Step 3: Rewrite the tile**

Replace `lib/widgets/editor/segment_tile.dart` entirely:

```dart
// FrontEnd/lib/widgets/editor/segment_tile.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/editor_theme.dart';
import '../../models/subtitle_project_model.dart';
import '../common/pressable.dart';

/// One row in the editor's segment list.
///
/// Height is pinned by [height] because SubtitleListPanel scrolls by
/// `index * height` — the two must not drift apart.
class SegmentTile extends StatelessWidget {
  /// Fixed row height. SubtitleListPanel's auto-scroll depends on this.
  static const double height = 84.0;

  final EditableSegment segment;
  final int index;
  final bool isSelected;
  final bool isActive;
  final bool matchesSearch;
  final bool hasOverlap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SegmentTile({
    super.key,
    required this.segment,
    required this.index,
    required this.isSelected,
    required this.isActive,
    required this.matchesSearch,
    required this.hasOverlap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;

    final Color background = isSelected
        ? editor.segmentSelected
        : isActive
            ? editor.segmentActive
            : scheme.surface;

    final isUrduFallback = segment.romanUrduText.isEmpty;

    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onTap,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            left: BorderSide(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: AppTypography.mono(
                  size: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${segment.startFormatted} - ${segment.endFormatted}',
                    style: AppTypography.mono(
                      size: 11,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      segment.displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: isUrduFallback
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: isUrduFallback
                          ? AppTypography.urdu(
                              size: 12,
                              color: scheme.onSurface,
                            )
                          : AppTypography.latin(
                              size: 13,
                              color: scheme.onSurface,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            // No mainAxisSize.min here: the Spacer below needs a bounded,
            // non-shrinking column to push the delete button to the bottom.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOverlap)
                      Tooltip(
                        message: 'Overlaps the next segment',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: editor.overlapMarker,
                        ),
                      ),
                    if (segment.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: editor.editedMarker,
                        ),
                      ),
                    if (matchesSearch)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.search_rounded,
                          size: 12,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (isSelected)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      splashRadius: 14,
                      tooltip: 'Delete segment',
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: scheme.onSurfaceVariant,
                      onPressed: onDelete,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `cd FrontEnd && flutter test test/widgets/editor/segment_tile_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Fix the scroll metric and pass the new param**

In `lib/widgets/editor/subtitle_list_panel.dart`, `_scrollToIndex` (L29–L41) hardcodes the tile height. Replace the offset line:

```dart
    final offset = (index * SegmentTile.height).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
```

Then in the `ListView.builder`'s `itemBuilder` (around L170), compute overlap against the next segment and pass it:

```dart
        final segments = editorState.segments;
        final next = index + 1 < segments.length ? segments[index + 1] : null;

        return SegmentTile(
          segment: segments[index],
          index: index,
          isSelected: editorState.selectedSegmentIndex == index,
          isActive: activeSegment == index,
          matchesSearch: editorState.searchResults.contains(index),
          hasOverlap: segments[index].overlapsNext(next),
          onTap: () {
            editorNotifier.selectSegment(index);
            playerNotifier.seekToSeconds(segments[index].start);
          },
          onDelete: () => editorNotifier.deleteSegment(index),
        );
```

- [ ] **Step 6: Verify**

Run: `cd FrontEnd && flutter analyze lib/widgets/editor/ && flutter test`
Expected: `No issues found!` and all tests pass.

- [ ] **Step 7: Commit**

```bash
git add FrontEnd/lib/widgets/editor/segment_tile.dart FrontEnd/lib/widgets/editor/subtitle_list_panel.dart FrontEnd/test/widgets/editor/segment_tile_test.dart
git commit -m "feat(editor): redesign SegmentTile with overlap marker and delete affordance"
```

---

## Task 9: Segment timeline

The mockup's timeline, minus the waveform (no backend peaks data — see Context). Segment blocks on a time axis, a playhead, click-to-seek, and zoom. All from `start`/`end`, which we already have.

**Files:**
- Create: `lib/widgets/editor/segment_timeline.dart`
- Test: `test/widgets/editor/segment_timeline_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/widgets/editor/segment_timeline_test.dart
//
// The timeline maps seconds to pixels and back. That mapping is the whole
// widget, so it is tested directly: block placement, playhead position, and
// click-to-seek must agree on the same scale.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/core/design/editor_theme.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';
import 'package:romasubai_frontend/widgets/editor/segment_timeline.dart';

final _segments = [
  EditableSegment(id: 1, start: 0.0, end: 2.0, romanUrduText: 'first'),
  EditableSegment(id: 2, start: 2.5, end: 5.0, romanUrduText: 'second'),
];

Widget _host({
  double position = 0.0,
  int? selectedIndex,
  ValueChanged<double>? onSeek,
  ValueChanged<int>? onSelect,
  double pixelsPerSecond = 40.0,
}) {
  return MaterialApp(
    theme: buildEditorTheme(false),
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: SegmentTimeline.height,
        child: SegmentTimeline(
          segments: _segments,
          positionSeconds: position,
          durationSeconds: 10.0,
          selectedIndex: selectedIndex,
          pixelsPerSecond: pixelsPerSecond,
          onSeek: onSeek ?? (_) {},
          onSelect: onSelect ?? (_) {},
          onZoomIn: () {},
          onZoomOut: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a block per segment', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(TimelineBlock), findsNWidgets(2));
  });

  testWidgets('block width follows duration and scale', (tester) async {
    await tester.pumpWidget(_host(pixelsPerSecond: 40));
    // First segment: 2.0s * 40px = 80px
    final size = tester.getSize(find.byType(TimelineBlock).first);
    expect(size.width, 80.0);
  });

  testWidgets('shows the current scale', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.textContaining('Scale'), findsOneWidget);
  });

  testWidgets('tapping a block selects that segment', (tester) async {
    int? selected;
    await tester.pumpWidget(_host(onSelect: (i) => selected = i));
    await tester.tap(find.byType(TimelineBlock).last);
    expect(selected, 1);
  });

  testWidgets('exposes zoom controls', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out_rounded), findsOneWidget);
  });

  testWidgets('renders a playhead', (tester) async {
    await tester.pumpWidget(_host(position: 3.0));
    expect(find.byKey(SegmentTimeline.playheadKey), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd FrontEnd && flutter test test/widgets/editor/segment_timeline_test.dart`
Expected: FAIL — target of URI doesn't exist: `segment_timeline.dart`

- [ ] **Step 3: Implement**

```dart
// FrontEnd/lib/widgets/editor/segment_timeline.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/editor_theme.dart';
import '../../models/subtitle_project_model.dart';

/// A single segment block on the timeline.
class TimelineBlock extends StatelessWidget {
  final EditableSegment segment;
  final bool isSelected;
  final double pixelsPerSecond;
  final VoidCallback onTap;

  const TimelineBlock({
    super.key,
    required this.segment,
    required this.isSelected,
    required this.pixelsPerSecond,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: segment.duration * pixelsPerSecond,
        decoration: BoxDecoration(
          color: isSelected ? editor.timelineBlockSelected : editor.timelineBlock,
          border: Border.all(
            color: isSelected ? editor.timelineBlockBorder : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          segment.displayText,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: AppTypography.latin(size: 11, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// The editor's timeline: segment blocks on a time axis, with a playhead.
///
/// Deliberately has NO waveform. The backend exposes no peaks data, so a
/// waveform would need a new FFmpeg endpoint. Blocks give the spatial sense
/// of pacing and gaps using timings we already hold.
class SegmentTimeline extends StatelessWidget {
  static const double height = 132.0;
  static const double rulerHeight = 20.0;
  static const double blockAreaHeight = 56.0;
  static const Key playheadKey = Key('timeline-playhead');

  final List<EditableSegment> segments;
  final double positionSeconds;
  final double durationSeconds;
  final int? selectedIndex;
  final double pixelsPerSecond;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onSelect;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const SegmentTimeline({
    super.key,
    required this.segments,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.selectedIndex,
    required this.pixelsPerSecond,
    required this.onSeek,
    required this.onSelect,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  /// Tick spacing in seconds, chosen so ticks stay ~60px apart at any zoom.
  double get _tickInterval {
    const targetPx = 60.0;
    final raw = targetPx / pixelsPerSecond;
    for (final candidate in const [0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]) {
      if (raw <= candidate) return candidate;
    }
    return 300.0;
  }

  String _formatTick(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;
    final trackWidth = durationSeconds * pixelsPerSecond;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: editor.timelineTrack,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          _buildHeader(context, scheme),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  onSeek(
                    (details.localPosition.dx / pixelsPerSecond)
                        .clamp(0.0, durationSeconds),
                  );
                },
                child: SizedBox(
                  width: trackWidth,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RulerPainter(
                            interval: _tickInterval,
                            pixelsPerSecond: pixelsPerSecond,
                            duration: durationSeconds,
                            color: scheme.outlineVariant,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        height: rulerHeight,
                        left: 0,
                        right: 0,
                        child: _buildTickLabels(scheme),
                      ),
                      Positioned(
                        top: rulerHeight + 4,
                        height: blockAreaHeight,
                        left: 0,
                        right: 0,
                        child: _buildBlocks(),
                      ),
                      Positioned(
                        key: playheadKey,
                        left: (positionSeconds * pixelsPerSecond)
                            .clamp(0.0, trackWidth),
                        top: 0,
                        bottom: 0,
                        width: 2,
                        child: Container(color: editor.playhead),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        child: Row(
          children: [
            Text(
              'TIMELINE',
              style: AppTypography.latin(
                size: 11,
                weight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            IconButton(
              iconSize: 16,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in_rounded),
              onPressed: onZoomIn,
            ),
            IconButton(
              iconSize: 16,
              splashRadius: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out_rounded),
              onPressed: onZoomOut,
            ),
            const Spacer(),
            Text(
              'Scale: ${_tickInterval.toStringAsFixed(_tickInterval < 1 ? 1 : 0)}s',
              style: AppTypography.mono(
                size: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickLabels(ColorScheme scheme) {
    final labels = <Widget>[];
    for (double t = 0; t <= durationSeconds; t += _tickInterval) {
      labels.add(Positioned(
        left: t * pixelsPerSecond + 3,
        top: 2,
        child: Text(
          _formatTick(t),
          style: AppTypography.mono(size: 9, color: scheme.onSurfaceVariant),
        ),
      ));
    }
    return Stack(children: labels);
  }

  Widget _buildBlocks() {
    return Stack(
      children: [
        for (var i = 0; i < segments.length; i++)
          Positioned(
            left: segments[i].start * pixelsPerSecond,
            top: 0,
            bottom: 0,
            child: TimelineBlock(
              segment: segments[i],
              isSelected: selectedIndex == i,
              pixelsPerSecond: pixelsPerSecond,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double interval;
  final double pixelsPerSecond;
  final double duration;
  final Color color;

  _RulerPainter({
    required this.interval,
    required this.pixelsPerSecond,
    required this.duration,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double t = 0; t <= duration; t += interval) {
      final x = t * pixelsPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.interval != interval ||
      old.pixelsPerSecond != pixelsPerSecond ||
      old.duration != duration ||
      old.color != color;
}
```

- [ ] **Step 4: Run the test**

Run: `cd FrontEnd && flutter test test/widgets/editor/segment_timeline_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/widgets/editor/segment_timeline.dart FrontEnd/test/widgets/editor/segment_timeline_test.dart
git commit -m "feat(editor): add segment timeline with playhead and zoom"
```

---

## Task 10: Inspector panel

Rebuilds `TextEditorPanel` as the mockup's Inspector. The important content changes:

1. **"AI Transliteration Active"**, never "translation" (see Context).
2. Urdu renders in `AppTypography.urdu` — Nastaʿlīq, RTL, tall line height. Today it has no font family at all.
3. **No "Edit" link on the Urdu field.** Read-only by design.
4. A **CPS readout** beside the character count, red when uncomfortable.
5. Fixes `_syncControllers` (L29–L43), which only re-syncs on index change, so undo/redo of the selected segment's text silently fails to refresh the fields.

**Files:**
- Modify: `lib/widgets/editor/text_editor_panel.dart`

- [ ] **Step 1: Fix the controller sync bug**

In `lib/widgets/editor/text_editor_panel.dart`, `_syncControllers` currently guards on `currentIndex != _lastSegmentIndex`, so external mutations to the selected segment don't reach the fields. Replace the method with:

```dart
  /// Sync the text controllers from state.
  ///
  /// Syncs on index change AND when the segment's text has changed underneath
  /// us — undo/redo mutate the selected segment in place, and the old
  /// index-only guard meant those edits never reached the fields.
  void _syncControllers(EditorState editorState) {
    final currentIndex = editorState.selectedSegmentIndex;
    final segment = editorState.selectedSegment;

    if (segment == null) {
      if (_lastSegmentIndex != null) {
        _romanUrduController.clear();
        _urduController.clear();
        _lastSegmentIndex = null;
      }
      return;
    }

    final indexChanged = currentIndex != _lastSegmentIndex;
    final romanDrifted = _romanUrduController.text != segment.romanUrduText;
    final urduDrifted = _urduController.text != segment.urduText;

    if (indexChanged) {
      _romanUrduController.text = segment.romanUrduText;
      _urduController.text = segment.urduText;
      _lastSegmentIndex = currentIndex;
      return;
    }

    // Same segment, but state changed underneath us (undo/redo). Only touch
    // the controller whose text actually drifted, so we don't fight the user's
    // cursor while they type.
    if (romanDrifted && !_romanUrduFocus.hasFocus) {
      _romanUrduController.text = segment.romanUrduText;
    }
    if (urduDrifted) {
      _urduController.text = segment.urduText;
    }
  }
```

Add the focus node to the State class fields (alongside `_romanUrduController` at L18):

```dart
  final FocusNode _romanUrduFocus = FocusNode();
```

And dispose it in `dispose()` (L23–L27):

```dart
    _romanUrduFocus.dispose();
```

- [ ] **Step 2: Wire the focus node into the Roman Urdu TextField**

In the Roman Urdu `TextField`, add `focusNode: _romanUrduFocus,`.

- [ ] **Step 3: Replace the Urdu field block**

The Urdu label + `TextField` block (around L253–L280) currently renders with no font family and a `getTextSecondary` colour. Replace with:

```dart
            Row(
              children: [
                Text(
                  'Urdu Script',
                  style: AppTypography.latin(
                    size: 11,
                    weight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Tooltip(
                  message: 'Auto-generated from speech. Correct the Roman '
                      'Urdu above; the Urdu reference is read-only.',
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                segment.urduText.isEmpty ? '—' : segment.urduText,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: AppTypography.urdu(
                  size: 14,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  // Transliteration, NOT translation: same language, different
                  // script. This distinction is the entire product.
                  'AI Transliteration Active',
                  style: AppTypography.latin(
                    size: 11,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
```

Note this swaps the read-only `TextField` for a `Text` in a `Container`. A read-only `TextField` still shows a caret and takes focus, which invites editing the very thing that isn't editable.

- [ ] **Step 4: Add the CPS readout under the Roman Urdu field**

Immediately after the Roman Urdu `TextField`, add:

```dart
            const SizedBox(height: AppSizes.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${segment.romanUrduText.length} Chars',
                  style: AppTypography.mono(
                    size: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Tooltip(
                  message: segment.isComfortableReadingRate
                      ? 'Characters per second — a comfortable reading pace'
                      : 'Too fast to read comfortably. Lengthen the segment '
                          'or shorten the text.',
                  child: Text(
                    '${segment.charsPerSecond.toStringAsFixed(1)} CPS',
                    style: AppTypography.mono(
                      size: 11,
                      color: segment.isComfortableReadingRate
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                ),
              ],
            ),
```

- [ ] **Step 5: Add the imports**

At the top of `text_editor_panel.dart`, add:

```dart
import '../../core/design/app_typography.dart';
```

And inside `build()`, add near the existing `isDark` line:

```dart
    final scheme = Theme.of(context).colorScheme;
```

- [ ] **Step 6: Verify**

Run: `cd FrontEnd && flutter analyze lib/widgets/editor/text_editor_panel.dart && flutter test`
Expected: `No issues found!` and all tests pass.

- [ ] **Step 7: Commit**

```bash
git add FrontEnd/lib/widgets/editor/text_editor_panel.dart
git commit -m "feat(editor): rebuild inspector with Nastaliq Urdu, CPS readout, correct transliteration copy"
```

---

## Task 11: Toolbar restyle

The Export button currently uses `AppColors.getPrimary(isDark)` with raw `Colors.black`/`Colors.white` (`editor_toolbar.dart:164,173,181`) — black/white, not the teal the design calls for. The mockup shows a filled teal Export button and a bordered Save.

Everything functional stays: the 5 export items with 2 conditional on `isVideoSource`, undo/redo, the unsaved dot, Fix Overlaps.

**Files:**
- Modify: `lib/widgets/editor/editor_toolbar.dart`

- [ ] **Step 1: Restyle the Export button**

Replace the Export `Container` decoration (around L164–L181) with:

```dart
              Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Export',
                      style: AppTypography.latin(
                        size: 13,
                        weight: FontWeight.w600,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: scheme.onPrimary,
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 2: Style the project name and toolbar surface**

Replace the toolbar `Container` decoration with:

```dart
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
```

And the project-name `Text` style with:

```dart
                style: AppTypography.latin(
                  size: 14,
                  weight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
```

- [ ] **Step 3: Add the imports and scheme lookup**

At the top:

```dart
import '../../core/design/app_typography.dart';
```

In `build()`:

```dart
    final scheme = Theme.of(context).colorScheme;
```

- [ ] **Step 4: Verify the export menu still behaves**

Run: `cd FrontEnd && flutter analyze lib/widgets/editor/editor_toolbar.dart && flutter test`
Expected: `No issues found!` and all tests pass — including the 3 existing export-menu tests in `transcription_complete_dialog_export_test.dart`.

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/widgets/editor/editor_toolbar.dart
git commit -m "feat(editor): restyle toolbar with teal export button"
```

---

## Task 12: Editor layout

Wires it together: the scoped theme, the new panel order, and the timeline.

Panel order changes from `[video 5 | list 3 | inspector 3]` to `[list 3 | video 6 | inspector 3]`, matching the mockup — the list moves left of the video, and the video gets more room. The timeline sits under the video, inside the centre column, so it scrolls with the video stage rather than spanning the inspector.

**Also fix the three stale doc comments** at L18–L22, L157, L163, which all claim different splits and all disagree with the code.

**Files:**
- Modify: `lib/screens/editor/subtitle_editor_screen.dart`

- [ ] **Step 1: Add zoom state to the screen**

In `_SubtitleEditorScreenState`, add alongside `_focusNode` (L39):

```dart
  static const double _minPixelsPerSecond = 4.0;
  static const double _maxPixelsPerSecond = 200.0;
  double _pixelsPerSecond = 40.0;

  void _zoomIn() => setState(() {
        _pixelsPerSecond =
            (_pixelsPerSecond * 1.5).clamp(_minPixelsPerSecond, _maxPixelsPerSecond);
      });

  void _zoomOut() => setState(() {
        _pixelsPerSecond =
            (_pixelsPerSecond / 1.5).clamp(_minPixelsPerSecond, _maxPixelsPerSecond);
      });
```

- [ ] **Step 2: Replace the stale class doc comment**

Replace the doc comment at L18–L22 with:

```dart
/// The subtitle editor.
///
/// Three panels inside the app shell, left to right:
///   - Segment list (flex 3)  — navigate and search
///   - Video + timeline (flex 6) — judge the result
///   - Inspector (flex 3)     — where corrections happen
///
/// Desktop-only. See Documentation/PRODUCT_OVERVIEW.md §6.13 — a mobile
/// layout is an open design problem, not a scaling exercise.
```

- [ ] **Step 3: Replace the whole build method**

This replaces `build()` at L123–L186 entirely — scoped theme, new panel order, and timeline in one edit. The three private builders (`_buildLoadingState` L188, `_buildErrorState` L209, `_buildErrorBanner` L238) are unchanged and still called.

Two things are load-bearing:
- The **`Builder`** is required. Without it the subtree reads the *outer* theme, not `buildEditorTheme`, and nothing changes.
- The **`Sidebar` stays outside** the scoped `Theme`. It is shared with the 13 un-redesigned screens and must keep looking identical across all of them.

```dart
  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Outside the scoped theme on purpose — shared with every other screen.
        const Sidebar(selectedIndexOverride: -1),
        Expanded(
          // Scoped: the redesign applies to the editor only. Everything else
          // still uses AppTheme/AppColors until it is redesigned in turn.
          child: Theme(
            data: buildEditorTheme(isDark),
            // Builder is required: without it the subtree below reads the
            // OUTER theme, not the one we just built.
            child: Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                return Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: _handleKeyEvent,
                  child: Scaffold(
                    backgroundColor: scheme.surface,
                    body: editorState.isLoading
                        ? _buildLoadingState(isDark)
                        : (editorState.error != null &&
                                editorState.project == null)
                            ? _buildErrorState(isDark, editorState.error!)
                            : Column(
                                children: [
                                  const EditorToolbar(),
                                  if (editorState.error != null)
                                    _buildErrorBanner(
                                        isDark, editorState.error!),
                                  Expanded(child: _buildPanels(editorState)),
                                ],
                              ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanels(EditorState editorState) {
    return Row(
      children: [
        const Expanded(flex: 3, child: SubtitleListPanel()),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              const Expanded(child: VideoPreviewPanel()),
              _buildTimeline(editorState),
            ],
          ),
        ),
        // The inspector needs width for two side-by-side TimingAdjuster
        // fields showing HH:MM:SS,mmm.
        const Expanded(flex: 3, child: TextEditorPanel()),
      ],
    );
  }

  Widget _buildTimeline(EditorState editorState) {
    final playerState = ref.watch(videoPlayerNotifierProvider);

    // Prefer the project's duration: it survives the media file going away,
    // and the timeline should still render for a project whose video is gone.
    final duration =
        editorState.project?.fileDuration ?? playerState.durationSeconds;
    if (duration <= 0) return const SizedBox.shrink();

    return SegmentTimeline(
      segments: editorState.segments,
      positionSeconds: playerState.positionSeconds,
      durationSeconds: duration,
      selectedIndex: editorState.selectedSegmentIndex,
      pixelsPerSecond: _pixelsPerSecond,
      onSeek: (seconds) => ref
          .read(videoPlayerNotifierProvider.notifier)
          .seekToSeconds(seconds),
      onSelect: (index) {
        ref.read(editorNotifierProvider.notifier).selectSegment(index);
        ref
            .read(videoPlayerNotifierProvider.notifier)
            .seekToSeconds(editorState.segments[index].start);
      },
      onZoomIn: _zoomIn,
      onZoomOut: _zoomOut,
    );
  }
```

Note `build()` now watches `videoPlayerNotifierProvider` via `_buildTimeline` — previously the screen only `.read` it. That is intended: the playhead must track playback position.

- [ ] **Step 4: Remove the now-unused Scaffold background import path**

`build()` no longer calls `AppColors.getBackground(isDark)` — the scoped theme supplies it. Leave the `AppColors` import in place: `_buildLoadingState`, `_buildErrorState`, and `_buildErrorBanner` still use it.

Run: `cd FrontEnd && flutter analyze lib/screens/editor/subtitle_editor_screen.dart`
Expected: `No issues found!` — no unused-import warning.

- [ ] **Step 5: Add the imports**

```dart
import '../../core/design/editor_theme.dart';
import '../../widgets/editor/segment_timeline.dart';
```

- [ ] **Step 6: Verify**

Run: `cd FrontEnd && flutter analyze && flutter test`
Expected: `No issues found!` and all tests pass.

- [ ] **Step 7: Run the app and look at it**

Run: `cd FrontEnd && flutter run -d linux`
Expected: The editor opens with the teal palette, Inter UI text, mono timecodes, Nastaʿlīq Urdu in the inspector, and a timeline under the video. Compare side by side with `Documentation/design/screens/subtitle-editor.png`.

Verify by hand, since no test covers these:
- Urdu renders as Nastaʿlīq, not tofu boxes and not naskh
- The timeline playhead tracks playback
- Clicking a timeline block selects and seeks
- Zoom in/out changes the scale readout
- The 13 other screens are visually **unchanged** (check Dashboard and Settings)

- [ ] **Step 8: Commit**

```bash
git add FrontEnd/lib/screens/editor/subtitle_editor_screen.dart
git commit -m "feat(editor): apply scoped design system, reorder panels, add timeline"
```

---

## Verification

- [ ] `cd FrontEnd && flutter analyze` → `No issues found!`
- [ ] `cd FrontEnd && flutter test` → all pass (expect ~35 tests across 8 files)
- [ ] `cd FrontEnd && flutter run -d linux` → editor matches the mockup; Urdu is Nastaʿlīq
- [ ] Dashboard and Settings are visually unchanged (scoped theme didn't leak)
- [ ] The word "translation" appears nowhere in the editor UI

## Deliberately out of scope

Recorded so they aren't mistaken for oversights:

- **Waveform** — needs a backend peaks endpoint.
- **Drag-to-retime on the timeline** — `TimingAdjuster` covers timing; drag is a separate interaction worth its own design.
- **The 13 other screens** — they keep `AppColors` until each is redesigned.
- **Mobile layout** — the editor stays a fixed desktop `Row`. `PRODUCT_OVERVIEW.md` §8 names this the hardest open problem in the product; it needs design, not a `LayoutBuilder`.
- **Dark palette review** — Task 4's dark values are derived, not designed.
- **Pre-existing provider bugs** not in the redesign's path: `_pushUndo` firing before network calls and never popping on failure; local-only undo/redo desyncing after add/delete; `VideoPlayerState.copyWith` clearing `error` on every call; `TimingAdjuster`'s unclamped increment letting `start` pass `end`. Each deserves its own fix and test.
