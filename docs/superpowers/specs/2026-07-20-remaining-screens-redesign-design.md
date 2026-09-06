# Remaining Screens Redesign — Design Spec

> **Scope decided with the user:** redesign only the three screens that have a Stitch design source of truth and are not yet migrated — **Recent Projects**, **Settings**, and the **Processing / Realtime Viewer**. The other 10 screens (auth flows, exports, feedback, splash) have no mockup and stay as-is.

**Goal:** Migrate these three screens onto the scoped design system (`FrontEnd/lib/core/design/`) established by the dashboard and editor, matching the intent of their Stitch mockups while showing only data/functionality the product actually has ("honest UI"). Preserve all existing real behavior; delete only invented furniture.

**Tech stack:** Flutter 3 / Dart ^3.8.1, flutter_riverpod ^2.5.1, dio, media_kit (realtime video), intl, flutter_test. No new dependencies.

---

## Shared architecture & conventions

**Working directory is `FrontEnd/`.** All `flutter` commands and Dart paths are relative to it.

**Scoped design-system migration (the established pattern).** Each screen opts into the design system through a **scoped `Theme` wrapper around its own subtree only** — the shell chrome (sidebar) and un-redesigned tabs keep the existing `AppColors`/`AppTheme` look. Mirror `lib/screens/dashboard/dashboard_screen.dart`:

```dart
Theme(
  data: buildBaseTheme(isDark),   // lib/core/design/base_theme.dart
  child: Builder(builder: (context) { ... }),
)
```

- Colours come from `Theme.of(context).colorScheme` (roles: `surface`, `onSurface`, `onSurfaceVariant`, `outlineVariant`, `primary`, `error`); semantic accents from `AppPalette` (`success`/`successDark`, `tealSubtle`/`tealSubtleDark`, `videoStage`).
- Type from `Theme.of(context).textTheme`; Urdu-script rendering from `AppTypography` (`urduFamily = 'NotoNastaliqUrdu'`, `urduScale`, `urduHeight`, RTL).
- **Spacing/radii stay on `AppSizes`** so these screens sit coherently beside sibling tabs.
- Read `isDark` once (`ref.watch(themeProvider).isDark`, or `Theme.of(context).brightness` inside the wrapper). Stop threading `isDark` through every helper — replace every `AppColors.getX(isDark)` call with a `colorScheme`/`textTheme` role.

**Honest-UI doctrine (from the dashboard plan).** The mockups are a reference, not a contract. Build only what a real backend field/endpoint or a real local mechanism supports. Never fabricate status, quotas, stats, percentages, ETAs, or — critically — **the word "Translation"** anywhere: this product does **transliteration** (script conversion, same language), never translation.

**Out of scope (all three screens):** the **sidebar / left-nav redesign**. It is shared shell chrome rendered for every tab; restyling it would change every screen at once and break the one-screen-at-a-time rollout. Also out of scope: the "Pro Editor" tier label, notification bell, and top-bar Save/Export — invented SaaS furniture already cut on the dashboard.

**Navigation facts (do not change):**
- Projects and Settings are **tabs** inside `main_shell`'s `IndexedStack` (indices 1 and 4), selected via `navIndexProvider` (a `StateProvider<int>`). They return **bare scrollable/bounded bodies — no `Scaffold`, no `AppBar`, no embedded sidebar** (the shell owns the Scaffold; `IndexedStack` uses `StackFit.expand`).
- The Realtime Viewer is **pushed full-screen over the shell** via `AppRoutes.realtimeViewer` (`/realtime-viewer`) with `{fileId, filename}`; it keeps its own `Row[Sidebar(selectedIndexOverride:-1), Expanded(...)]` structure with the sidebar left unstyled.
- Layout decisions key off **content width via `LayoutBuilder`**, not `MediaQuery` (the shell insets content by the sidebar).

**Test conventions** (`test/widgets/editor/segment_tile_test.dart`, `test/screens/dashboard/dashboard_screen_test.dart`): repo-relative path comment on line 1; a rationale block; a private `_host(...)`/`_pump(...)` builder wrapping the widget in `MaterialApp(theme: buildBaseTheme(false), home: Scaffold(body: ...))`; `find.text`/`find.byIcon`/`find.byWidgetPredicate` assertions; hand-written fakes (no mocktail/mockito). Provider-backed screens use `ProviderScope(overrides: [...])` with seeded `FutureProvider`s and the never-completing `storageServiceProvider` seam to neutralise auth.

---

## Screen 1 — Recent Projects (`lib/screens/projects/projects_screen.dart`)

**Target & cleanup.** Rebuild `projects_screen.dart` (the real screen, shell tab 1). **Delete `lib/screens/projects/recent_projects_screen.dart`** — it is a dead 2-line `export 'projects_screen.dart';` imported nowhere (guard the delete with `grep -rn recent_projects_screen FrontEnd/lib`). No provider moves needed: `projectsProvider` already lives in `lib/providers/library_providers.dart`.

**Layout (decided with user): a data table** in a bordered card, matching the mockup and mapping to the real per-project columns.

**Real data** — `projectsProvider` → `GET /subtitles/list/projects` → `{success, projects[]}`, newest-first. Per project: `subtitle_id`, `file_id`, `project_name`, `original_filename`, `is_video` (bool), `segment_count` (int), `file_duration` (num, **nullable**), `created_at`, `updated_at` (ISO-8601). Legitimate aggregate: `projects.length`.

**Build:**
- Page title **"All Projects"** + a mono count pill bound to `projects.length`.
- Existing **client-side search** ("Search projects…") over `project_name` + `original_filename`, case-insensitive.
- **Table** with a header row and one row per project:
  - media icon driven by real **`is_video`** (movie vs. audio),
  - **Project Name** (`project_name`),
  - **Filename** (`original_filename`),
  - **Duration** (`file_duration`, right-aligned mono, `--:--` when null),
  - **Segments** (`segment_count`, right-aligned mono),
  - **Last Edited** (`updated_at`, relative: "Today, HH:MM" / "Yesterday" / "MMM d, y").
- Tap a row → editor: `AppRoutes.to(context, AppRoutes.editor, arguments: {'fileId': p['file_id'], 'transcription': null})` (unchanged).
- Real **empty state** and **search-empty state**.
- Reuse the correct `_formatDuration` (H:MM:SS / M:SS / `--:--`) from `lib/widgets/dashboard/recent_projects_card.dart` rather than duplicating the screen's weaker inline version — extract it to a shared helper if cleaner.

**Cut (no backend):**
- **Status column + all four badges** (Editing / Completed / Processing / Failed) and the red "error" row icon — no `status` field exists on projects. (Direct analog of dashboard cut #7.)
- **"Status" filter** button — cannot filter a nonexistent field.
- **Select-all + per-row checkboxes** — no bulk endpoint exists.
- **Per-row `more_vert` kebab** — no project rename/delete endpoint exists.
- Notification bell, help icon, top-bar Save/Export, "Pro Editor" label, grid/list toggle.

**Landmines:** must return a bounded-height layout (the current `Column` with an `Expanded` inside the `IndexedStack`); keep `_searchController` local (survives tab switches because `IndexedStack` keeps tabs alive); this screen is the dashboard "View All" target — it is the exhaustive list, not a truncated subset.

---

## Screen 2 — Settings (`lib/screens/settings/settings_screen.dart`)

**Target.** Rebuild `settings_screen.dart` (shell tab 4). **This is a live, fully-wired screen** — the redesign is largely a design-system migration, **not** a behavior change. Preserve the three real handlers (`_handleSaveProfile`, `_handleChangePassword`, `_handlePickImage`) with their `mounted`/loading/error-snackbar patterns. Returns a bare scrollable body (no `Scaffold`).

**Real functionality (all endpoints/mechanisms already exist — reuse):**

| Setting | Mechanism |
|---|---|
| Avatar upload / delete | `authNotifier.uploadProfilePicture` → `POST /users/profile-picture`; `deleteProfilePicture` → `DELETE`. NetworkImage uses `${ApiConfig.baseUrl}${user.profilePictureUrl}`. |
| First / Last name (editable) | `authNotifier.updateProfile(first, last)` → `PUT /users/profile`. |
| Email | Display only — backend `UpdateProfileRequest` accepts only first/last; **render read-only/disabled**. |
| Password change | `authNotifier.changePassword(current, new)` → `POST /auth/change-password`. Email accounts only. |
| Dark Mode | `themeProvider.toggleTheme()`, persisted to `is_dark_mode`. |
| Account facts (read-only) | `UserModel.isVerified`, `googleId`, `createdAt` from `/auth/me`. |

**Build** — a single-column "Profile Settings" page (H1 `AppStrings.profileSettings`), a vertical stack of real sections:
1. **Avatar** row — 64px circular avatar (initials fallback), **Change** (picker + upload) / remove. Copy: "This image will be displayed on your profile." (drop "team workspaces").
2. **Name** — First/Last, editable via an Edit → Save/Cancel flow (real save). Gated: only for email accounts (`user.googleId == null`).
3. **Email** — read-only field showing `user.email`; honest note ("Signed in with Google" or "contact support to change") instead of the billing helper copy.
4. **Security → password change** — Current/New/Confirm + Update, gated to `googleId == null`; Google accounts see a "You signed in with Google" state instead of dead fields.
5. **Appearance → Dark Mode** — a real `Switch` bound to `themeProvider`.
6. **Account** (read-only density) — Account Type (Google/Email), Verified/Pending, Member Since (`createdAt`).

**Cut (no backend):** notification bell, top-bar Save/Export, "Search settings", help icon, the right-panel **"Pro Tip" billing card**, all **billing/invoice/team** copy, **delete-account / danger zone** (no route exposes `delete_user`), **language selector**, **editable email**, "Pro Editor" label. The mockup's dead inner-nav tabs (Profile/Security/Appearance/Account with empty panes) → replace with a plain vertical stack of the real sections above.

**Landmines:** the **Google-account branch is load-bearing** — hide/replace name-edit and password for Google users (a `UserModel.isGoogleUser` helper exists); never render email as a live input; no `Scaffold`/`AppBar`; keep the `${ApiConfig.baseUrl}` avatar prefix and multipart upload.

---

## Screen 3 — Processing / Realtime Viewer (`lib/screens/realtime/realtime_viewer_screen.dart`)

**Target.** Rebuild `realtime_viewer_screen.dart` (pushed full-screen over the shell; params `fileId`, `filename`). Migrate the content column (right of the sidebar) onto `buildBaseTheme(isDark)`; the reused `video_controls.dart` and `subtitle_overlay.dart` do not need `EditorTheme`, so `buildBaseTheme` suffices. Replace the 24 `AppColors.getX(isDark)` calls with `colorScheme`/`textTheme` roles.

**Real streaming data** — SSE parsed in `realtime_stream_service.dart`; state in `realtimeNotifierProvider` (`RealtimePhase`: idle→connecting→buffering→streaming→complete→error). Events:
- `chunk_ready` → `{chunk_index, segments[], processed_through, chunks_done, chunks_total}`; each segment `{id, start, end, urdu_text, roman_urdu_text, is_edited}` — **arrives fully formed** (both texts together; no token-level/in-progress streaming).
- `buffer_ready` → `{playback_start, processed_seconds, total_duration, ...}` — flips to `streaming`, sets `totalDuration`.
- `stream_complete` → `{total_segments, total_duration, processing_time_seconds}` (elapsed, not ETA).
- `error` → `{message}`.

Real: incremental segments, a "done" signal, **determinate chunk-fraction** (`chunks_done/chunks_total`), `processed_through` (media seconds processed) and `total_duration`. **Not** available: any ETA/remaining time, per-segment in-progress state, audio-extraction %, and **any English translation** (only `urdu_text` + `roman_urdu_text`).

**Build:**
- Header: filename + live/processing status (pulse dot only when `streaming`), close/back.
- Video player + live caption overlay (`SubtitleOverlay`, which switches on `realtimeState.canPlay && editorState.project == null` — preserve).
- **Live Transcript** panel: rows of mono timecode + Roman-Urdu + **Urdu script (Nastaliq, RTL)**; auto-scroll as segments append. A current-playback highlight is fine if driven by real `getSegmentAtTime(currentTime)`.
- **Honest progress:** **indeterminate** while connecting/buffering (`chunks_total == 0`), then **determinate chunk fraction** labeled **"N/M chunks"** (never a fabricated %). Handle the **fast path** (`_emit_cached_results`): the common post-upload case fires all events instantly (`chunks_total == 1`), so progress may jump 0→1 in one frame and the buffering UI may flash once.
- Optional processed-buffer scrubber band from `processed_through/total_duration` (once known); a "Buffer: Xs" pill only if wired live to `processed_through − currentTime`.
- "Open Subtitle Editor" on `complete` → `createProjectForEditor(filename)` then `AppRoutes.replace(editor, {fileId, transcription: null})` (keep; not in mockup but honest).

**Cut / fix (no backend / forbidden):**
- The **English "gloss" second line** in the overlay and transcript rows — it is *translation*; **replace with the real Urdu-script line** (Nastaliq).
- The **"Translating…" active-segment affordance** (spinner + blinking cursor) — no per-segment in-progress signal, and "Translating" is forbidden. Remove the fake live-typing.
- The upload overlay's **"Extracting audio — 45%"** and literal step percentages — no such signal → honest indeterminate "Preparing…".
- The hardcoded **"Buffer: 45s"** literal; top-bar Save/Export/bell/"Pro Editor".

**Landmines:** the **video stage must stay dark in both themes** — use `AppPalette.videoStage`/black, not `colorScheme.surface`. `realtimeNotifierProvider` is `autoDispose` (SSE cancels on navigate-away). `notifySeek` (debounced 300 ms) only fires in `streaming` for targets beyond `processed_through` — keep. Desktop-first `Row[Sidebar, …]`; no mobile layout (known repo-wide limit).

---

## File structure

**Create:**
| Path | Responsibility |
|---|---|
| `lib/widgets/projects/projects_table.dart` | The projects data-table widget (header + rows), data via constructor params |
| `test/screens/projects/projects_screen_test.dart` | Composition test: table rows from seeded `projectsProvider`, counts pill, search, empty states, no "Status"/"Translation" |
| `test/widgets/projects/projects_table_test.dart` | Table widget tests (columns, `is_video` icon, `--:--` duration, tap callback) |
| `test/screens/settings/settings_screen_test.dart` | Settings composition: real sections render, Google vs email branch, no billing/delete/"Translation" |
| `test/screens/realtime/realtime_viewer_test.dart` | Realtime states: connecting (indeterminate), streaming (N/M chunks + Urdu-script rows), complete (Open Editor), no English gloss / no "Translating"/"Translation" |

**Modify:**
| Path | Change |
|---|---|
| `lib/screens/projects/projects_screen.dart` | Rebuild as scoped-theme data table; drop status/checkbox/kebab |
| `lib/screens/settings/settings_screen.dart` | Scoped-theme migration; honest sections; preserve handlers + Google branch |
| `lib/screens/realtime/realtime_viewer_screen.dart` | Scoped-theme migration; Urdu-script line; honest progress; cut Translating/45% |
| `lib/core/constants/app_strings.dart` | Add any new strings these screens need |

**Delete (grep-guarded):**
| Path | Why |
|---|---|
| `lib/screens/projects/recent_projects_screen.dart` | Dead re-export, imported nowhere |

**Note:** existing widget assets to reuse — `recent_projects_card.dart` (`_formatDuration`), `video_controls.dart`, `subtitle_overlay.dart`, `AppTextField`, `AppSnackbar`, `Validators`.

---

## Testing strategy

Per screen: a composition/widget test asserting the **real** content renders and the **honest-UI invariants hold** — in particular `find.textContaining('Translation') findsNothing` on all three, no Status badges on projects, no billing/delete on settings, no English gloss / "Translating" on realtime. Follow the dashboard's `ProviderScope`-override + never-completing-`storageServiceProvider` seam for auth. Target: whole suite stays green (`flutter test`), scoped `dart analyze` on changed files clean.

## Out of scope
- The 10 undesigned screens (auth, exports, feedback, splash).
- The sidebar / left-nav redesign (shared chrome).
- Any new backend endpoints (delete-account, email change, notifications, billing, language) — the honest-UI cuts exist precisely because these don't exist.
