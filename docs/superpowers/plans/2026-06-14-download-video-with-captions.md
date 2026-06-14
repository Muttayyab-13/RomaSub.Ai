# Download Video with Captions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users download their video with Roman Urdu captions attached — either burned-in (hardsub) or as a toggleable MP4 track (softsub) — from the subtitle editor's export menu.

**Architecture:** A new isolated backend service `app/services/video_export.py` owns all FFmpeg logic (pure command builders + one orchestration function). A new streaming endpoint `GET /subtitles/{id}/export-video?mode=` returns the finished MP4 via `FileResponse`. The Flutter editor toolbar gains two export-menu items that call a new Dio bytes-download method behind a non-dismissible progress dialog.

**Tech Stack:** Python / FastAPI / FFmpeg (via `static_ffmpeg`) / pytest; Flutter / Dio / Riverpod.

**Spec:** `docs/superpowers/specs/2026-06-14-download-video-with-captions-design.md`

---

## File Structure

**Backend**
- Create: `app/services/video_export.py` — pure helpers `build_output_filename`, `build_ffmpeg_command`, plus orchestration `export_video_with_subtitles`, plus error-message constants.
- Modify: `app/routers/subtitle.py` — add `GET /{subtitle_id}/export-video` returning `FileResponse`.
- Create: `tests/test_video_export.py` — unit tests for the pure helpers.
- Modify: `requirements.txt` — add `pytest`.

**Frontend**
- Modify: `FrontEnd/lib/services/api/api_config.dart` — add `subtitleExportVideo` path + `videoExportTimeout`.
- Modify: `FrontEnd/lib/services/subtitle_service.dart` — add `downloadVideoWithCaptions`.
- Modify: `FrontEnd/lib/providers/subtitle_editor_provider.dart` — add `exportVideo(mode)`.
- Modify: `FrontEnd/lib/widgets/editor/editor_toolbar.dart` — add two menu items, `_handleVideoExport`, and a progress dialog widget.

**Conventions observed in this codebase**
- Services are plain modules of functions returning tuples like `(success, message, ...)`; routers raise `HTTPException`.
- FFmpeg is invoked with `subprocess.run(cmd, capture_output=True, text=True)` and the command name `"ffmpeg"` (paths added by `static_ffmpeg.add_paths()`).
- Temp files live under `settings.temp_upload_dir`.
- `subtitle.format_as_srt(segments)` already renders `roman_urdu_text` with a fallback to `urdu_text` — reuse it; do **not** re-implement the caption-text rule.

---

## Task 1: Backend pure helpers (TDD)

The two pure functions — filename builder and FFmpeg command builder — carry the per-mode branching worth protecting with tests. They import nothing heavy, so the test runs fast.

**Files:**
- Create: `app/services/video_export.py`
- Create: `tests/test_video_export.py`
- Modify: `requirements.txt`

- [ ] **Step 1: Ensure pytest is installed**

Run:
```bash
./venv/bin/python -m pytest --version || ./venv/bin/pip install pytest
```
Expected: prints a pytest version (installs it first if missing).

- [ ] **Step 2: Add pytest to requirements.txt**

Append under the utilities section of `requirements.txt`:
```
# Testing
pytest
```

- [ ] **Step 3: Write the failing tests**

Create `tests/test_video_export.py`:
```python
import pytest

from app.services.video_export import build_output_filename, build_ffmpeg_command


def test_build_output_filename_hardsub():
    assert build_output_filename("clip.mp4", "hardsub") == "clip_roman_subtitled.mp4"


def test_build_output_filename_softsub_strips_only_last_ext():
    assert build_output_filename("My.Holiday.mkv", "softsub") == "My.Holiday_roman_softsubs.mp4"


def test_build_ffmpeg_command_hardsub_burns_subtitles():
    cmd = build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "hardsub")
    assert cmd[0] == "ffmpeg"
    assert "-vf" in cmd
    assert "subtitles=subs.srt" in cmd
    assert "libx264" in cmd
    assert cmd[-1] == "out.mp4"


def test_build_ffmpeg_command_softsub_muxes_track_without_reencode():
    cmd = build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "softsub")
    assert cmd.count("-i") == 2          # video input + srt input
    assert cmd.count("-map") == 2        # map all of input 0, plus the srt
    assert "mov_text" in cmd
    assert "copy" in cmd                 # stream copy = no re-encode
    assert cmd[-1] == "out.mp4"


def test_build_ffmpeg_command_rejects_unknown_mode():
    with pytest.raises(ValueError):
        build_ffmpeg_command("in.mp4", "subs.srt", "out.mp4", "bogus")
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `./venv/bin/python -m pytest tests/test_video_export.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.video_export'`.

- [ ] **Step 5: Create the module with the pure helpers**

Create `app/services/video_export.py`:
```python
"""
Video Export Service for RomaSub.AI

Renders a project's video with Roman Urdu captions attached, either burned
into the pixels (hardsub) or as a toggleable MP4 subtitle track (softsub).
All FFmpeg/subprocess concerns live here, isolated from subtitle.py.
"""

import os
import uuid
import subprocess
import logging
from typing import List, Tuple

import static_ffmpeg
static_ffmpeg.add_paths()

from app.config import settings

logger = logging.getLogger(__name__)

VALID_MODES = ("hardsub", "softsub")

# Error messages — the router maps these to HTTP status codes.
MSG_BAD_MODE = "Unsupported mode. Use hardsub or softsub"
MSG_PROJECT_NOT_FOUND = "Project not found"
MSG_NO_SEGMENTS = "Project has no segments to render"
MSG_SOURCE_MISSING = "Source video no longer available. Please re-upload."
MSG_NOT_VIDEO = "Video export requires a video file"
MSG_RENDER_FAILED = "Video rendering failed"
MSG_FFMPEG_MISSING = "FFmpeg not found. Please install FFmpeg."


def build_output_filename(original_filename: str, mode: str) -> str:
    """Build a friendly download filename for the rendered MP4."""
    base = original_filename.rsplit(".", 1)[0]
    suffix = "subtitled" if mode == "hardsub" else "softsubs"
    return f"{base}_roman_{suffix}.mp4"


def build_ffmpeg_command(
    input_path: str, srt_path: str, output_path: str, mode: str
) -> List[str]:
    """Build the FFmpeg argument list for the requested mode."""
    if mode == "hardsub":
        return [
            "ffmpeg", "-y",
            "-i", input_path,
            "-vf", f"subtitles={srt_path}",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
            "-c:a", "aac",
            "-movflags", "+faststart",
            output_path,
        ]
    if mode == "softsub":
        return [
            "ffmpeg", "-y",
            "-i", input_path,
            "-i", srt_path,
            "-map", "0", "-map", "1",
            "-c", "copy",
            "-c:s", "mov_text",
            "-movflags", "+faststart",
            output_path,
        ]
    raise ValueError(f"Unsupported mode: {mode}")
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `./venv/bin/python -m pytest tests/test_video_export.py -v`
Expected: PASS — all 5 tests green.

- [ ] **Step 7: Commit**

```bash
git add app/services/video_export.py tests/test_video_export.py requirements.txt
git commit -m "feat(video-export): add FFmpeg command + filename builders with tests"
```

---

## Task 2: Backend orchestration function

Adds `export_video_with_subtitles`, which validates the request, writes a temp SRT (reusing `subtitle.format_as_srt`), runs FFmpeg, and returns the output path. This calls into the heavy ML-importing `subtitle` module, so dependencies are imported lazily inside the function (keeps Task 1's tests fast) and it is verified manually rather than unit-tested.

**Files:**
- Modify: `app/services/video_export.py`

- [ ] **Step 1: Add the orchestration function and a temp-file helper**

Append to `app/services/video_export.py`:
```python
def _safe_remove(path: str) -> None:
    try:
        if path and os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


def export_video_with_subtitles(subtitle_id: str, mode: str) -> Tuple[bool, str, str, str]:
    """
    Render the project's video with Roman Urdu captions.

    Returns (success, message, output_path, download_filename). On failure
    `message` is one of the MSG_* constants and the path/filename are empty.
    """
    # Lazy imports: subtitle pulls in heavy ASR/torch deps; keep module import light.
    from app.services import subtitle as subtitle_service
    from app.services import media as media_service

    if mode not in VALID_MODES:
        return False, MSG_BAD_MODE, "", ""

    project = subtitle_service.get_project(subtitle_id)
    if not project:
        return False, MSG_PROJECT_NOT_FOUND, "", ""

    segments = project.get("segments") or []
    if not segments:
        return False, MSG_NO_SEGMENTS, "", ""

    file_info = media_service.get_file_info(project["file_id"])
    if not file_info:
        return False, MSG_SOURCE_MISSING, "", ""
    if not file_info.get("is_video"):
        return False, MSG_NOT_VIDEO, "", ""

    input_path = file_info["file_path"]
    if not input_path or not os.path.exists(input_path):
        return False, MSG_SOURCE_MISSING, "", ""

    os.makedirs(settings.temp_upload_dir, exist_ok=True)
    token = uuid.uuid4().hex
    srt_path = os.path.join(settings.temp_upload_dir, f"{token}.srt")
    output_path = os.path.join(settings.temp_upload_dir, f"{token}_{mode}.mp4")

    # Reuse the existing formatter — it already renders roman_urdu_text with a
    # fallback to urdu_text, which is exactly the caption rule we want.
    srt_content = subtitle_service.format_as_srt(segments)
    with open(srt_path, "w", encoding="utf-8") as fh:
        fh.write(srt_content)

    command = build_ffmpeg_command(input_path, srt_path, output_path, mode)
    logger.info("Video export FFmpeg command: %s", " ".join(command))

    try:
        result = subprocess.run(command, capture_output=True, text=True)
    except FileNotFoundError:
        return False, MSG_FFMPEG_MISSING, "", ""
    finally:
        _safe_remove(srt_path)

    if result.returncode != 0 or not os.path.exists(output_path):
        logger.error("Video export failed (rc=%s): %s", result.returncode, result.stderr)
        _safe_remove(output_path)
        return False, MSG_RENDER_FAILED, "", ""

    download_filename = build_output_filename(project["original_filename"], mode)
    return True, "Export successful", output_path, download_filename
```

- [ ] **Step 2: Verify the module imports cleanly and Task 1 tests still pass**

Run:
```bash
./venv/bin/python -c "import app.services.video_export as v; print(v.VALID_MODES)"
./venv/bin/python -m pytest tests/test_video_export.py -v
```
Expected: prints `('hardsub', 'softsub')`; all 5 tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add app/services/video_export.py
git commit -m "feat(video-export): add export_video_with_subtitles orchestration"
```

---

## Task 3: Backend endpoint

Adds the streaming endpoint that calls the service, maps failures to HTTP codes, records the export, and streams the MP4 with a background cleanup of the temp output file.

**Files:**
- Modify: `app/routers/subtitle.py`

- [ ] **Step 1: Add imports**

In `app/routers/subtitle.py`, add `import os` at the top of the import block, and add these imports below the existing ones:
```python
import os
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

from app.services import video_export as video_export_service
```
(Place `import os` with the stdlib imports; the `from fastapi import ...` and `from app.services import ...` lines already exist — add the new ones alongside them.)

- [ ] **Step 2: Add the endpoint**

In `app/routers/subtitle.py`, immediately after the existing `export_subtitles` endpoint (the `@router.get("/{subtitle_id}/export", ...)` function), add:
```python
@router.get("/{subtitle_id}/export-video")
async def export_video(subtitle_id: str, mode: str = "hardsub"):
    """
    Download the project's video with Roman Urdu captions attached.

    - **mode**: `hardsub` (captions burned into the pixels) or `softsub`
      (captions as a toggleable track). Output is always MP4.
    """
    success, message, output_path, filename = (
        video_export_service.export_video_with_subtitles(subtitle_id, mode)
    )

    if not success:
        if message in (
            video_export_service.MSG_PROJECT_NOT_FOUND,
            video_export_service.MSG_SOURCE_MISSING,
        ):
            code = status.HTTP_404_NOT_FOUND
        elif message in (
            video_export_service.MSG_RENDER_FAILED,
            video_export_service.MSG_FFMPEG_MISSING,
        ):
            code = status.HTTP_500_INTERNAL_SERVER_ERROR
        else:
            code = status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=code, detail=message)

    fmt = "mp4-hardsub" if mode == "hardsub" else "mp4-softsub"
    subtitle_service.record_export(subtitle_id, fmt, filename)

    return FileResponse(
        output_path,
        media_type="video/mp4",
        filename=filename,
        background=BackgroundTask(os.remove, output_path),
    )
```

- [ ] **Step 3: Verify the app imports with the new route**

Run:
```bash
./venv/bin/python -c "from app.routers.subtitle import router; print([r.path for r in router.routes if 'export-video' in r.path])"
```
Expected: prints `['/subtitles/{subtitle_id}/export-video']`.

- [ ] **Step 4: Manual end-to-end check (hardsub + softsub)**

Start the backend (`./venv/bin/uvicorn app.main:app --reload`), upload a short video through the app, transcribe it, open the editor (creates a subtitle project), then with that `subtitle_id`:
```bash
curl -L "http://localhost:8000/subtitles/<SUBTITLE_ID>/export-video?mode=hardsub" -o /tmp/hardsub.mp4
curl -L "http://localhost:8000/subtitles/<SUBTITLE_ID>/export-video?mode=softsub" -o /tmp/softsub.mp4
```
Expected: `/tmp/hardsub.mp4` plays with captions baked into the picture; `/tmp/softsub.mp4` plays with a selectable subtitle track (e.g. in VLC). Also confirm `curl ".../export-video?mode=bogus"` returns HTTP 400.

- [ ] **Step 5: Commit**

```bash
git add app/routers/subtitle.py
git commit -m "feat(video-export): add /subtitles/{id}/export-video endpoint"
```

---

## Task 4: Frontend API config + service method

Adds the endpoint path, a long receive-timeout for the slow render, and the Dio bytes-download method.

**Files:**
- Modify: `FrontEnd/lib/services/api/api_config.dart`
- Modify: `FrontEnd/lib/services/subtitle_service.dart`

- [ ] **Step 1: Add the endpoint path and timeout to api_config.dart**

In `FrontEnd/lib/services/api/api_config.dart`, add this line directly below the existing `subtitleExport` builder (around line 53):
```dart
  static String subtitleExportVideo(String subtitleId) =>
      '/subtitles/$subtitleId/export-video';
```
And add this constant next to the existing timeout constants (around line 79):
```dart
  // Video render can take minutes; use a much longer receive timeout.
  static const Duration videoExportTimeout = Duration(minutes: 10);
```

- [ ] **Step 2: Add `downloadVideoWithCaptions` to subtitle_service.dart**

In `FrontEnd/lib/services/subtitle_service.dart`, add this method to the `SubtitleService` class, directly after `exportSubtitles`:
```dart
  /// Download the project's video with Roman Urdu captions attached.
  ///
  /// [mode] is `hardsub` (burned-in) or `softsub` (toggleable track).
  /// Returns the raw MP4 bytes and a suggested filename.
  Future<({List<int> bytes, String filename})> downloadVideoWithCaptions(
    String subtitleId,
    String mode,
  ) async {
    try {
      final response = await _client.dio.get<List<int>>(
        ApiConfig.subtitleExportVideo(subtitleId),
        queryParameters: {'mode': mode},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: ApiConfig.videoExportTimeout,
          headers: {'Accept': 'video/mp4'},
        ),
      );
      final bytes = response.data ?? <int>[];
      final filename =
          _filenameFromHeaders(response.headers) ?? 'subtitled_video.mp4';
      return (bytes: bytes, filename: filename);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String? _filenameFromHeaders(Headers headers) {
    final disposition = headers.value('content-disposition');
    if (disposition == null) return null;
    final match = RegExp('filename="?([^"]+)"?').firstMatch(disposition);
    return match?.group(1);
  }
```
(`Options`, `ResponseType`, `Headers`, and `DioException` all come from the already-imported `package:dio/dio.dart`.)

- [ ] **Step 3: Verify the frontend analyzes cleanly**

Run: `cd FrontEnd && flutter analyze lib/services/subtitle_service.dart lib/services/api/api_config.dart`
Expected: "No issues found!" (or only pre-existing unrelated infos — no new errors).

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/lib/services/subtitle_service.dart FrontEnd/lib/services/api/api_config.dart
git commit -m "feat(video-export): add Dio bytes download for captioned video"
```

---

## Task 5: Frontend provider method

Adds `exportVideo(mode)` to the editor notifier, mirroring the existing `export(format)` (save-if-dirty, then call the service, surface errors).

**Files:**
- Modify: `FrontEnd/lib/providers/subtitle_editor_provider.dart`

- [ ] **Step 1: Add the `exportVideo` method**

In `FrontEnd/lib/providers/subtitle_editor_provider.dart`, add this method to `EditorNotifier`, directly after the existing `export(String format)` method (around line 475):
```dart
  /// Render and download the project's video with captions.
  ///
  /// [mode] is `hardsub` or `softsub`. Returns the bytes + filename, or null
  /// on failure (error is recorded in state).
  Future<({List<int> bytes, String filename})?> exportVideo(String mode) async {
    if (state.project == null) return null;

    // Save first so the rendered video reflects the latest edits.
    if (state.hasUnsavedChanges) await save();

    try {
      return await _subtitleService.downloadVideoWithCaptions(
        state.project!.subtitleId,
        mode,
      );
    } catch (e) {
      state = state.copyWith(error: () => 'Video export failed: $e');
      return null;
    }
  }
```

- [ ] **Step 2: Verify it analyzes cleanly**

Run: `cd FrontEnd && flutter analyze lib/providers/subtitle_editor_provider.dart`
Expected: "No issues found!" (or only pre-existing unrelated infos).

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/providers/subtitle_editor_provider.dart
git commit -m "feat(video-export): add exportVideo to editor notifier"
```

---

## Task 6: Frontend toolbar — menu items, handler, progress dialog

Adds the two export-menu items (only for video sources), routes them to a new handler that shows a non-dismissible progress dialog and writes the returned bytes to the downloads directory.

**Files:**
- Modify: `FrontEnd/lib/widgets/editor/editor_toolbar.dart`

- [ ] **Step 1: Compute whether the source is a video, in `build`**

In `FrontEnd/lib/widgets/editor/editor_toolbar.dart`, inside `build`, just after the line `final isDark = Theme.of(context).brightness == Brightness.dark;` (line 17), add:
```dart
    final isVideoSource =
        _isVideoSource(editorState.project?.originalFilename ?? '');
```

- [ ] **Step 2: Replace the export `PopupMenuButton`'s `onSelected` and `itemBuilder`**

Replace the existing `onSelected:` and `itemBuilder:` lines (currently lines 135-140) with:
```dart
            onSelected: (value) {
              if (value == 'video_hardsub') {
                _handleVideoExport(context, ref, 'hardsub');
              } else if (value == 'video_softsub') {
                _handleVideoExport(context, ref, 'softsub');
              } else {
                _handleExport(context, ref, value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'srt', child: Text('Export as SRT')),
              const PopupMenuItem(value: 'vtt', child: Text('Export as VTT')),
              const PopupMenuItem(value: 'txt', child: Text('Export as TXT')),
              if (isVideoSource) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'video_hardsub',
                  child: Text('Video — burned-in captions'),
                ),
                const PopupMenuItem(
                  value: 'video_softsub',
                  child: Text('Video — toggleable captions'),
                ),
              ],
            ],
```

- [ ] **Step 3: Add the helper, handler, and progress dialog**

In the same file, add the `_isVideoSource` helper and `_handleVideoExport` method inside the `EditorToolbar` class, directly after the existing `_handleExport` method (after line 210, before the closing brace of the class):
```dart
  bool _isVideoSource(String filename) {
    if (!filename.contains('.')) return false;
    final ext = filename.split('.').last.toLowerCase();
    return const {'mp4', 'avi', 'mkv', 'mov', 'webm'}.contains(ext);
  }

  Future<void> _handleVideoExport(
    BuildContext context,
    WidgetRef ref,
    String mode,
  ) async {
    final editorNotifier = ref.read(editorNotifierProvider.notifier);

    // Block the UI with a progress dialog while FFmpeg renders.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VideoExportProgressDialog(),
    );

    ({List<int> bytes, String filename})? result;
    try {
      result = await editorNotifier.exportVideo(mode);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video export failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${result.filename}';
      await File(filePath).writeAsBytes(result.bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
```

- [ ] **Step 4: Add the progress dialog widget**

At the end of the file (after the `_ToolbarButton` class), add:
```dart
class _VideoExportProgressDialog extends StatelessWidget {
  const _VideoExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Flexible(
              child: Text(
                'Rendering video with captions…\nThis can take a few minutes.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify it analyzes cleanly**

Run: `cd FrontEnd && flutter analyze lib/widgets/editor/editor_toolbar.dart`
Expected: "No issues found!" (or only pre-existing unrelated infos — no new errors).

- [ ] **Step 6: Manual UI check**

Run the app, open the subtitle editor for a **video** project, click **Export**: confirm the two new "Video — …" items appear below the divider (and do **not** appear for an audio-only project). Pick "Video — burned-in captions": confirm the progress dialog appears, then a success snackbar with the saved path, and the file in the downloads dir plays with captions. Repeat for "toggleable captions".

- [ ] **Step 7: Commit**

```bash
git add FrontEnd/lib/widgets/editor/editor_toolbar.dart
git commit -m "feat(video-export): add captioned-video items to editor export menu"
```

---

## Final Verification

- [ ] Backend tests pass: `./venv/bin/python -m pytest tests/test_video_export.py -v`
- [ ] Frontend analyzes: `cd FrontEnd && flutter analyze` (no new errors in the four touched files)
- [ ] End-to-end: a real short video → hardsub download plays with baked-in captions; softsub download plays with a toggleable track; both appear on the Recent Exports page without crashing the export card.
- [ ] Audio-only project does **not** show the video export options, and the endpoint returns 400 for an audio file / 400 for an unknown `mode`.

---

## Notes / Known Limitations (from the spec)

- MP4 output only; captions are Roman Urdu only; editor menu only (not the dashboard exports surface); no caption styling controls.
- Media metadata is in-memory: if the backend restarts between editing and export, the `file_id` lookup fails and the endpoint returns 404 ("Source video no longer available"). This matches the existing video-streaming behavior and is acceptable for v1.
