# Design — Recents Video Playback + Export Menu Options

**Date:** 2026-06-26
**Branch:** AddDownloadFeature
**Status:** Approved (pending spec review)

Two independent defects, confirmed by root-cause investigation (systematic debugging).

---

## Issue 1 — Export menu only shows subtitle exports until "the video is opened"

### Symptom
In the subtitle editor, the Export dropdown sometimes shows only the three
subtitle formats (SRT / VTT / TXT) and omits the two captioned-video exports
("Video — burned-in captions", "Video — toggleable captions"). The user expects
the video exports to be available for any video project.

### Root cause (confirmed)
`FrontEnd/lib/widgets/editor/editor_toolbar.dart:18`

```dart
final isVideoSource =
    _isVideoSource(editorState.project?.originalFilename ?? '');
```

and `editor_toolbar.dart:146-161`: SRT/VTT/TXT are unconditional; the two video
items are wrapped in `if (isVideoSource) ...[ ... ]`.

The gate has two weaknesses:
1. It evaluates a **client-side filename parse** of `originalFilename`, which is
   `null`/empty while `loadProject` is in flight (`editorState.project == null`)
   or if the project fails to load — so the video options disappear.
2. It re-derives a fact the **backend already knows** (`media_service.is_video_file`),
   duplicating logic and tying menu correctness to string parsing.

The 16 persisted projects all have `.mp4` filenames, so the underlying media
*is* video — the menu should reliably offer video exports for them.

### Fix — drive the gate off authoritative `is_video`

**Backend**
- `app/services/subtitle.py` `create_project()` — store
  `"is_video": media_service.is_video_file(original_filename)` on the project dict
  (line ~154-164, alongside the other fields).
- `app/schemas/subtitle.py` — add `is_video: bool` to `SubtitleProjectResponse`.
- `app/routers/subtitle.py` — in every place that builds a `SubtitleProjectResponse`
  (create, get, bulk-update, fix-overlaps), set
  `is_video=media_service.is_video_file(project["original_filename"])`.
  Deriving in the response layer means **no data migration** for the 16 existing
  projects and stays correct even when the media file is gone.
- `app/services/subtitle.py` `list_all_projects()` — include `is_video` in each
  summary item (derive from `original_filename`).

**Frontend**
- `FrontEnd/lib/models/subtitle_project_model.dart` — add `final bool isVideo;`,
  parsed as `json['is_video'] as bool? ?? _deriveIsVideo(originalFilename)` where
  the helper checks the video extension set as a safety net if the backend field
  is absent.
- `FrontEnd/lib/widgets/editor/editor_toolbar.dart` — replace the line-18 gate with
  `final isVideoSource = editorState.project?.isVideo ?? false;` and remove the
  now-unused `_isVideoSource` helper.

### Resulting behavior
| Source | Export options |
|---|---|
| Video project | SRT, VTT, TXT, Video (burned-in), Video (toggleable) |
| Audio-only project | SRT, VTT, TXT |
| Project still loading | menu opens once project loads; video options appear reliably for video sources, no fragile-parse flicker |

Audio sources intentionally keep video exports hidden — burning captions into a
file with no video track is invalid and would fail at the backend.

---

## Issue 2 — Video does not play when a project is opened from recents

### Symptom
Opening a project from the recents/projects list and pressing play does nothing;
the preview panel sits on "Loading video…" forever.

### Root cause (confirmed)
A storage-lifetime mismatch between three stores:

| Store | Contents | Lifetime |
|---|---|---|
| `app/data/subtitle_state.json` (recents source) | 16 projects, each `file_id` + `.mp4` name | **Persisted** across restarts |
| `app/services/media.py:28` `_file_registry` | `file_id → file metadata` | **In-memory only** — wiped on restart |
| `temp_upload_dir = /tmp/romasub_uploads` | the media bytes | **`/tmp`** — wiped on reboot/temp cleanup |

Evidence: recents lists **16** projects but `/tmp/romasub_uploads` currently holds
files for only **2**. Opening any of the other 14 builds `/media/{file_id}/stream`,
and the backend (`app/routers/media.py:232-254`) returns:
- 404 *"File not found"* — `get_file_info()` returns `None` (registry empty after restart), or
- 404 *"File no longer exists on disk"* — file gone from `/tmp`.

The Flutter player receives the 404 but `video_preview_panel.dart:62-81` only ever
renders `playerState.error ?? 'Loading video...'`, so it reads as a silent hang.
Fresh uploads work because file + registry entry still live in the same process —
the only differentiator is whether the file survived, which rules out the
auth/timing hypotheses.

### Fix — durable storage + registry rehydration + friendly error

**Layer 1 — durable storage** (`app/config.py`)
- Rename `temp_upload_dir` → `media_upload_dir`, default value
  `uploads/media` (repo-relative, sibling of the existing `uploads/` dir), and
  update the `makedirs` at module load.
- Update the ~3 references: `app/services/media.py` `save_upload_file` (line 121)
  and `extract_audio` (line ~218). `video_export.py` reads `file_info["file_path"]`
  and needs no change.

**Layer 2 — persist + rehydrate the registry** (`app/services/media.py`)
- Mirror the subtitle service's JSON-persistence pattern:
  - `_FILE_REGISTRY_FILE = app/data/file_registry.json`.
  - `_save_registry()` — atomic temp-write-then-rename of `_file_registry`.
  - `_load_registry()` — load at import time (before first request).
  - Call `_save_registry()` after every mutation: `save_upload_file` (new entry),
    `extract_audio` (sets `audio_path`/`status`), `cleanup_file` (removes entry).
- **Startup scan fallback (defense in depth):** after `_load_registry()`, scan
  `media_upload_dir` for `{file_id}.{ext}` files; for any `file_id` present on disk
  but missing from the registry, reconstruct a `file_info` entry, using the
  persisted project's `original_filename` (cross-reference
  `subtitle_service`/`subtitle_state.json`) when available, else the on-disk name.
  This keeps recents working even if `file_registry.json` is lost but media survives.

**Layer 3 — friendly "media unavailable" UX** (Flutter)
- `FrontEnd/lib/screens/editor/subtitle_editor_screen.dart` `_initializeEditor()`:
  after `loadProject`, pre-check availability via the existing
  `GET /media/{fileId}` (`FileInfoResponse`, 404 when missing) before initializing
  the player. On 404, set an explicit "media unavailable" state and skip player init.
- `FrontEnd/lib/providers/video_player_provider.dart` — add a state flag/message for
  "media unavailable" (distinct from a generic player error).
- `FrontEnd/lib/widgets/editor/video_preview_panel.dart` — when media is
  unavailable, render a clear message:
  *"This project's media file is no longer available. Please re-upload the video to
  edit or export captions."* (instead of the indefinite "Loading video…").

**Optional one-time migration**
- Copy the 2 surviving files from `/tmp/romasub_uploads` into `uploads/media/` so
  those projects keep playing. The 14 already-deleted files cannot be recovered
  (bytes are gone) and will correctly show the friendly message. All *future*
  uploads are durable.

---

## Testing

**Backend (pytest under `tests/`)**
- Registry persistence round-trip: upload → `_save_registry` → clear in-memory dict →
  `_load_registry` → `get_file_info` resolves the same metadata.
- Restart-simulation: clear registry, leave file on disk → startup scan fallback
  rebuilds the entry → `/media/{file_id}/stream` resolves.
- `is_video` present and correct in `SubtitleProjectResponse` for both a `.mp4` and a
  `.wav` project; present in `list_all_projects` output.
- Missing-file path returns 404 with the expected detail.

**Frontend**
- Export menu: video project exposes 5 options, audio project exposes 3, gate reads
  `project.isVideo`.
- `_initializeEditor` 404 path sets the media-unavailable state and the panel renders
  the friendly message rather than spinning.

---

## Files touched (summary)

**Backend**
- `app/config.py` — rename/repoint upload dir.
- `app/services/media.py` — registry persistence + startup rehydrate + dir refs.
- `app/services/subtitle.py` — store/derive `is_video`; include in summaries.
- `app/routers/subtitle.py` — return `is_video` in responses.
- `app/schemas/subtitle.py` — `is_video` field.

**Frontend**
- `lib/models/subtitle_project_model.dart` — `isVideo` field.
- `lib/widgets/editor/editor_toolbar.dart` — gate off `project.isVideo`.
- `lib/screens/editor/subtitle_editor_screen.dart` — media-availability pre-check.
- `lib/providers/video_player_provider.dart` — media-unavailable state.
- `lib/widgets/editor/video_preview_panel.dart` — friendly message.

**Tests**
- `tests/` — backend registry + `is_video` tests.
