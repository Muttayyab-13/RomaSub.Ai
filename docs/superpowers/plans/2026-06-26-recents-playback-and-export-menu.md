# Recents Playback + Export Menu Options — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make captioned-video export options appear reliably for video projects, and make videos opened from recents either play (durable media) or show a clear "media unavailable" message instead of hanging.

**Architecture:** Backend gains an authoritative `is_video` field on subtitle-project responses and persists/rehydrates its media-file registry while storing uploads in a durable directory. Frontend gates the export menu on `project.isVideo` and pre-checks media availability before initializing the player, surfacing a friendly message on 404.

**Tech Stack:** FastAPI + Pydantic (Python), pytest; Flutter + Riverpod + media_kit + Dio (Dart), flutter_test.

**Spec:** `docs/superpowers/specs/2026-06-26-recents-playback-and-export-menu-design.md`

**Branch:** `AddDownloadFeature` (already checked out). Run backend tests from repo root; frontend commands from `FrontEnd/`.

---

## File Structure

**Backend**
- `app/schemas/subtitle.py` — add `is_video` to `SubtitleProjectResponse`.
- `app/services/subtitle.py` — store `is_video` on new projects; include it in `list_all_projects`.
- `app/routers/subtitle.py` — return `is_video` from every project response.
- `app/config.py` — rename `temp_upload_dir` → `media_upload_dir`, durable default path.
- `app/services/media.py` — registry JSON persistence + startup rehydrate-from-disk; update dir references.
- `.gitignore` — ignore `uploads/media/` and `app/data/file_registry.json`.

**Frontend**
- `lib/models/subtitle_project_model.dart` — add `isVideo`.
- `lib/widgets/editor/editor_toolbar.dart` — gate off `project.isVideo`; delete `_isVideoSource`.
- `lib/services/media_service.dart` — add `isMediaAvailable(fileId)`.
- `lib/providers/video_player_provider.dart` — add `mediaUnavailable` state + `markUnavailable()`.
- `lib/screens/editor/subtitle_editor_screen.dart` — pre-check availability in `_initializeEditor`.
- `lib/widgets/editor/video_preview_panel.dart` — render friendly message when unavailable.

**Tests**
- `tests/test_subtitle_is_video.py` — backend `is_video` in responses.
- `tests/test_media_registry.py` — registry persist/rehydrate.
- `FrontEnd/test/subtitle_project_is_video_test.dart` — model `isVideo` parsing.

---

## PHASE 1 — Backend: authoritative `is_video` (Issue 1)

### Task 1: Return `is_video` on subtitle-project responses

**Files:**
- Modify: `app/schemas/subtitle.py:106-117`
- Modify: `app/services/subtitle.py:154-164` (create) and `:187-200` (`list_all_projects`)
- Modify: `app/routers/subtitle.py` (every `SubtitleProjectResponse(...)` site)
- Test: `tests/test_subtitle_is_video.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_subtitle_is_video.py
from app.services import media as media_service


def test_is_video_file_true_for_mp4():
    assert media_service.is_video_file("clip.mp4") is True


def test_is_video_file_false_for_wav():
    assert media_service.is_video_file("voice.wav") is False


def test_is_video_file_handles_dotted_names():
    # WhatsApp-style names with multiple dots must still resolve to mp4
    assert media_service.is_video_file("WhatsApp Video 2026-03-29 at 4.32.01 PM.mp4") is True


def test_schema_accepts_is_video_field():
    from app.schemas.subtitle import SubtitleProjectResponse
    resp = SubtitleProjectResponse(
        subtitle_id="s1",
        file_id="f1",
        project_name="p",
        original_filename="clip.mp4",
        segments=[],
        segment_count=0,
        created_at="now",
        updated_at="now",
        is_video=True,
    )
    assert resp.is_video is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/test_subtitle_is_video.py -v`
Expected: `test_schema_accepts_is_video_field` FAILS (unexpected keyword argument `is_video`). The three `is_video_file` tests should already PASS (function exists at `app/services/media.py:67-78`).

- [ ] **Step 3: Add `is_video` to the response schema**

In `app/schemas/subtitle.py`, change `SubtitleProjectResponse` (lines 106-117) to add the field after `updated_at`:

```python
class SubtitleProjectResponse(BaseModel):
    """Response containing full subtitle project"""
    success: bool = True
    subtitle_id: str
    file_id: str
    project_name: str
    original_filename: str
    segments: List[SubtitleSegmentSchema]
    segment_count: int
    file_duration: Optional[float] = None
    created_at: str
    updated_at: str
    is_video: bool = False
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_subtitle_is_video.py -v`
Expected: all four PASS.

- [ ] **Step 5: Store `is_video` on new projects**

In `app/services/subtitle.py`, the `project` dict in `create_project` (lines 154-164) gains an `is_video` key (computed from the filename via the already-imported `media_service`):

```python
    project = {
        "subtitle_id": subtitle_id,
        "file_id": file_id,
        "project_name": project_name or original_filename,
        "original_filename": original_filename,
        "is_video": media_service.is_video_file(original_filename),
        "segments": segments,
        "segment_count": len(segments),
        "file_duration": duration,
        "created_at": now,
        "updated_at": now
    }
```

- [ ] **Step 6: Include `is_video` in `list_all_projects`**

In `app/services/subtitle.py`, `list_all_projects` (lines 187-200) — add `is_video` to each summary item, derived from the filename so the 16 pre-existing projects (which lack the stored key) are still correct:

```python
        projects.append({
            "subtitle_id": project["subtitle_id"],
            "file_id": project["file_id"],
            "project_name": project["project_name"],
            "original_filename": project["original_filename"],
            "is_video": project.get(
                "is_video",
                media_service.is_video_file(project["original_filename"]),
            ),
            "segment_count": project["segment_count"],
            "file_duration": project.get("file_duration"),
            "created_at": project["created_at"],
            "updated_at": project["updated_at"],
        })
```

- [ ] **Step 7: Return `is_video` from every router response**

Find all response sites:

Run: `grep -n "SubtitleProjectResponse(" app/routers/subtitle.py`

For EACH `return SubtitleProjectResponse(` block (create ~73, get ~95, bulk-update ~190, and any fix-overlaps site), add this line alongside the existing fields:

```python
        is_video=media_service.is_video_file(project["original_filename"]),
```

Example — the create endpoint block (`app/routers/subtitle.py:73-83`) becomes:

```python
    return SubtitleProjectResponse(
        subtitle_id=project["subtitle_id"],
        file_id=project["file_id"],
        project_name=project["project_name"],
        original_filename=project["original_filename"],
        segments=[SubtitleSegmentSchema(**s) for s in project["segments"]],
        segment_count=project["segment_count"],
        file_duration=project.get("file_duration"),
        created_at=project["created_at"],
        updated_at=project["updated_at"],
        is_video=media_service.is_video_file(project["original_filename"]),
    )
```

- [ ] **Step 8: Add an endpoint test and run the suite**

Append to `tests/test_subtitle_is_video.py`:

```python
def test_list_projects_includes_is_video():
    from app.services import subtitle as subtitle_service
    items = subtitle_service.list_all_projects()
    # All persisted demo projects use .mp4 filenames
    for item in items:
        assert "is_video" in item
        assert item["is_video"] == subtitle_service.media_service.is_video_file(
            item["original_filename"]
        )
```

Run: `python -m pytest tests/test_subtitle_is_video.py tests/test_video_export.py -v`
Expected: all PASS (video_export tests confirm no regression).

- [ ] **Step 9: Commit**

```bash
git add app/schemas/subtitle.py app/services/subtitle.py app/routers/subtitle.py tests/test_subtitle_is_video.py
git commit -m "feat(subtitle): return authoritative is_video on project responses"
```

---

## PHASE 2 — Backend: durable media storage (Issue 2)

### Task 2: Repoint uploads to a durable directory

**Files:**
- Modify: `app/config.py:55-85`
- Modify: `app/services/media.py:121` and `:218` (references to the dir)
- Modify: `.gitignore`

- [ ] **Step 1: Rename + repoint the setting in config**

In `app/config.py`, add a project-root constant near the top (after the imports, before `class Settings`):

```python
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
```

Replace the `# Temp directory for uploaded files` block (lines 60-61) with:

```python
    # Durable directory for uploaded media files (survives restarts/reboots).
    # Was previously /tmp/romasub_uploads, which is wiped on reboot and left
    # recents projects pointing at missing files.
    media_upload_dir: str = os.path.join(_PROJECT_ROOT, "uploads", "media")
```

Replace the bottom `makedirs` (line 85) with:

```python
# Ensure media upload directory exists
os.makedirs(settings.media_upload_dir, exist_ok=True)
```

- [ ] **Step 2: Update references in media.py**

Run: `grep -n "temp_upload_dir" app/`

In `app/services/media.py`, line 121 (`save_upload_file`):

```python
    file_path = os.path.join(settings.media_upload_dir, f"{file_id}.{ext}")
```

And line 118 (`os.makedirs(settings.temp_upload_dir, ...)` inside `save_upload_file`):

```python
    os.makedirs(settings.media_upload_dir, exist_ok=True)
```

In `extract_audio` (around line 218), update the audio output dir similarly:

```python
    audio_path = os.path.join(
        settings.media_upload_dir, f"{file_id}_audio.wav"
    )
```

Verify nothing else references the old name:

Run: `grep -rn "temp_upload_dir" app/ tests/`
Expected: no matches.

- [ ] **Step 3: Ignore the durable media dir + registry file**

In `.gitignore`, below the existing `app/data/subtitle_state.json` lines (134-135), add:

```
app/data/file_registry.json
app/data/file_registry.json.tmp
uploads/media/
```

- [ ] **Step 4: Smoke-check the app imports**

Run: `python -c "from app.config import settings; import os; print(settings.media_upload_dir); print(os.path.isdir(settings.media_upload_dir))"`
Expected: prints an absolute path ending in `/uploads/media` and `True`.

- [ ] **Step 5: Commit**

```bash
git add app/config.py app/services/media.py .gitignore
git commit -m "fix(media): store uploads in durable uploads/media dir instead of /tmp"
```

---

### Task 3: Persist the file registry to JSON

**Files:**
- Modify: `app/services/media.py:28` (registry declaration area) and the mutation sites
- Test: `tests/test_media_registry.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_media_registry.py
import importlib


def test_registry_persists_and_reloads(tmp_path, monkeypatch):
    from app.services import media as media_service

    # Redirect the registry file to a temp location
    reg_file = tmp_path / "file_registry.json"
    monkeypatch.setattr(media_service, "_FILE_REGISTRY_FILE", str(reg_file))

    media_service._file_registry.clear()
    media_service._file_registry["abc"] = {
        "file_id": "abc",
        "original_filename": "clip.mp4",
        "file_path": "/some/where/abc.mp4",
        "file_size": 123,
        "extension": "mp4",
        "is_video": True,
        "audio_path": None,
        "status": "uploaded",
    }
    media_service._save_registry()

    # Simulate a restart: wipe in-memory state, reload from disk
    media_service._file_registry.clear()
    assert media_service.get_file_info("abc") is None
    media_service._load_registry()

    info = media_service.get_file_info("abc")
    assert info is not None
    assert info["original_filename"] == "clip.mp4"
    assert info["is_video"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/test_media_registry.py -v`
Expected: FAIL — `module 'app.services.media' has no attribute '_FILE_REGISTRY_FILE'` (and `_save_registry`/`_load_registry`).

- [ ] **Step 3: Add JSON persistence to media.py**

In `app/services/media.py`, add `import json` to the imports (top of file, alongside `import os`). Then replace the registry declaration block (lines 27-28) with:

```python
# In-memory storage for file metadata
_file_registry: Dict[str, Dict] = {}

# JSON persistence so the registry survives server restarts (mirrors the
# subtitle service's subtitle_state.json). Files themselves live in
# settings.media_upload_dir.
_FILE_REGISTRY_FILE = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "data", "file_registry.json"
)


def _save_registry() -> None:
    """Persist the file registry to disk atomically."""
    try:
        os.makedirs(os.path.dirname(_FILE_REGISTRY_FILE), exist_ok=True)
        tmp_path = _FILE_REGISTRY_FILE + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(_file_registry, f, ensure_ascii=False, indent=2)
        os.replace(tmp_path, _FILE_REGISTRY_FILE)
    except Exception as e:
        logger.warning("Failed to persist file registry: %s", e)


def _load_registry() -> None:
    """Load the file registry from disk on startup."""
    if not os.path.exists(_FILE_REGISTRY_FILE):
        return
    try:
        with open(_FILE_REGISTRY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        _file_registry.update(data)
        logger.info("Loaded file registry: %d entries", len(_file_registry))
    except Exception as e:
        logger.warning("Failed to load file registry: %s", e)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_media_registry.py -v`
Expected: PASS.

- [ ] **Step 5: Save the registry on every mutation**

In `app/services/media.py`:

In `save_upload_file`, right after `_file_registry[file_id] = file_info` (line 156):

```python
        _file_registry[file_id] = file_info
        _save_registry()
```

In `extract_audio`, after the block that sets `file_info["audio_path"]` / `file_info["status"]` (both the early audio-file return path around line 208-210 and the post-extraction success path), call `_save_registry()` before returning success. For the early audio path:

```python
    if not file_info["is_video"]:
        file_info["audio_path"] = file_info["file_path"]
        file_info["status"] = "audio_ready"
        _save_registry()
        print(f"\n[AUDIO] File is already audio: {file_info['file_path']}")
        return True, file_info["file_path"]
```

And after the successful FFmpeg extraction sets `audio_path`/`status` (search for the line that assigns `file_info["audio_path"] = audio_path`), add `_save_registry()` immediately after.

In `cleanup_file`, after the entry is removed from `_file_registry` (find `del _file_registry[file_id]` or equivalent near line 309-340), add `_save_registry()`.

- [ ] **Step 6: Load the registry at import time**

At the very bottom of `app/services/media.py`, add:

```python
# Load persisted registry at import time so streaming works after a restart.
_load_registry()
```

- [ ] **Step 7: Run the full backend suite**

Run: `python -m pytest tests/ -v`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add app/services/media.py tests/test_media_registry.py
git commit -m "feat(media): persist file registry to JSON so streaming survives restarts"
```

---

### Task 4: Rehydrate the registry from disk on startup (defense in depth)

**Files:**
- Modify: `app/services/media.py` (add `rehydrate_from_disk`, call after `_load_registry`)
- Test: `tests/test_media_registry.py` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_media_registry.py`:

```python
def test_rehydrate_from_disk_rebuilds_missing_entries(tmp_path, monkeypatch):
    from app.services import media as media_service
    from app.config import settings

    # Point the media dir at a temp location with one orphaned file on disk
    monkeypatch.setattr(settings, "media_upload_dir", str(tmp_path))
    fid = "11111111-2222-3333-4444-555555555555"
    (tmp_path / f"{fid}.mp4").write_bytes(b"fake video bytes")
    (tmp_path / f"{fid}_audio.wav").write_bytes(b"fake audio")

    media_service._file_registry.clear()
    count = media_service.rehydrate_from_disk()

    assert count == 1
    info = media_service.get_file_info(fid)
    assert info is not None
    assert info["file_path"] == str(tmp_path / f"{fid}.mp4")
    assert info["is_video"] is True
    assert info["audio_path"] == str(tmp_path / f"{fid}_audio.wav")


def test_rehydrate_skips_already_registered(tmp_path, monkeypatch):
    from app.services import media as media_service
    from app.config import settings

    monkeypatch.setattr(settings, "media_upload_dir", str(tmp_path))
    fid = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    (tmp_path / f"{fid}.mp4").write_bytes(b"x")

    media_service._file_registry.clear()
    media_service._file_registry[fid] = {"file_id": fid, "file_path": "kept"}
    count = media_service.rehydrate_from_disk()

    assert count == 0
    assert media_service.get_file_info(fid)["file_path"] == "kept"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/test_media_registry.py -k rehydrate -v`
Expected: FAIL — `module 'app.services.media' has no attribute 'rehydrate_from_disk'`.

- [ ] **Step 3: Implement `rehydrate_from_disk`**

In `app/services/media.py`, add this function (above the bottom `_load_registry()` call). It must NOT import the subtitle service (media is imported BY subtitle — a reverse import would be circular); it derives metadata from the on-disk filename only:

```python
def rehydrate_from_disk() -> int:
    """
    Rebuild registry entries for media files present on disk but missing from
    the in-memory registry (e.g. after the registry JSON was lost but the
    durable media files survived). Returns the number of entries added.

    Files are named "{file_id}.{ext}"; extracted audio is "{file_id}_audio.wav".
    original_filename is best-effort (the on-disk name) — streaming only needs
    file_path, and the frontend already has the real name from the project.
    """
    media_dir = settings.media_upload_dir
    if not os.path.isdir(media_dir):
        return 0

    added = 0
    for name in os.listdir(media_dir):
        # Skip extracted-audio sidecars; they are linked from their parent.
        if name.endswith("_audio.wav"):
            continue
        stem, dot, ext = name.partition(".")
        if not dot or not stem or stem in _file_registry:
            continue

        full_path = os.path.join(media_dir, name)
        if not os.path.isfile(full_path):
            continue

        audio_sidecar = os.path.join(media_dir, f"{stem}_audio.wav")
        _file_registry[stem] = {
            "file_id": stem,
            "original_filename": name,
            "file_path": full_path,
            "file_size": os.path.getsize(full_path),
            "extension": ext.lower(),
            "is_video": is_video_file(name),
            "audio_path": audio_sidecar if os.path.exists(audio_sidecar) else None,
            "status": "uploaded",
        }
        added += 1

    if added:
        logger.info("Rehydrated %d media registry entries from disk", added)
        _save_registry()
    return added
```

- [ ] **Step 4: Call it at startup after `_load_registry`**

At the bottom of `app/services/media.py`, change the startup block to:

```python
# Load persisted registry, then rehydrate any durable files the registry
# missed, so streaming works after a restart even if the JSON was lost.
_load_registry()
rehydrate_from_disk()
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python -m pytest tests/test_media_registry.py -v`
Expected: all PASS.

- [ ] **Step 6: Run the full backend suite**

Run: `python -m pytest tests/ -v`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add app/services/media.py tests/test_media_registry.py
git commit -m "feat(media): rehydrate file registry from durable files on startup"
```

---

## PHASE 3 — Frontend: export menu gate (Issue 1)

### Task 5: Add `isVideo` to the SubtitleProject model

**Files:**
- Modify: `FrontEnd/lib/models/subtitle_project_model.dart:93-146`
- Test: `FrontEnd/test/subtitle_project_is_video_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// FrontEnd/test/subtitle_project_is_video_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:romasubai_frontend/models/subtitle_project_model.dart';

Map<String, dynamic> _base(Map<String, dynamic> overrides) => {
      'subtitle_id': 's1',
      'file_id': 'f1',
      'project_name': 'p',
      'original_filename': 'clip.mp4',
      'segments': <dynamic>[],
      'segment_count': 0,
      'created_at': 'now',
      'updated_at': 'now',
      ...overrides,
    };

void main() {
  test('uses backend is_video when present', () {
    final p = SubtitleProject.fromJson(_base({'is_video': true}));
    expect(p.isVideo, isTrue);
  });

  test('false when backend says audio source', () {
    final p = SubtitleProject.fromJson(
        _base({'original_filename': 'voice.wav', 'is_video': false}));
    expect(p.isVideo, isFalse);
  });

  test('falls back to filename when is_video absent (mp4)', () {
    final json = _base({})..remove('is_video');
    final p = SubtitleProject.fromJson(json);
    expect(p.isVideo, isTrue);
  });

  test('falls back to filename when is_video absent (wav)', () {
    final json = _base({'original_filename': 'voice.wav'})..remove('is_video');
    final p = SubtitleProject.fromJson(json);
    expect(p.isVideo, isFalse);
  });
}
```

> Note: package name is `romasubai_frontend` (from `FrontEnd/pubspec.yaml`), matching the import style in `FrontEnd/test/widget_test.dart`.

- [ ] **Step 2: Run test to verify it fails**

Run (from `FrontEnd/`): `flutter test test/subtitle_project_is_video_test.dart`
Expected: FAIL — `isVideo` getter not defined on `SubtitleProject`.

- [ ] **Step 3: Add the field + derivation helper**

In `FrontEnd/lib/models/subtitle_project_model.dart`:

Add the field to the class (after `originalFilename`, line 97):

```dart
  final bool isVideo;
```

Add to the constructor (after `originalFilename`, line 108):

```dart
    required this.isVideo,
```

In `fromJson` (lines 118-130), add the parse with a filename fallback:

```dart
      isVideo: (json['is_video'] as bool?) ??
          _deriveIsVideo(json['original_filename'] as String? ?? ''),
```

In `toJson` (lines 134-144), add:

```dart
      'is_video': isVideo,
```

Add the static helper inside the class (e.g. just above `fromJson`):

```dart
  static const Set<String> _videoExtensions = {
    'mp4', 'avi', 'mkv', 'mov', 'webm',
  };

  static bool _deriveIsVideo(String filename) {
    if (!filename.contains('.')) return false;
    return _videoExtensions.contains(filename.split('.').last.toLowerCase());
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `FrontEnd/`): `flutter test test/subtitle_project_is_video_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add FrontEnd/lib/models/subtitle_project_model.dart FrontEnd/test/subtitle_project_is_video_test.dart
git commit -m "feat(model): add isVideo to SubtitleProject with filename fallback"
```

---

### Task 6: Gate the export menu on `project.isVideo`

**Files:**
- Modify: `FrontEnd/lib/widgets/editor/editor_toolbar.dart:18-19` and `:233-237`

- [ ] **Step 1: Replace the gate**

In `FrontEnd/lib/widgets/editor/editor_toolbar.dart`, replace lines 18-19:

```dart
    final isVideoSource =
        _isVideoSource(editorState.project?.originalFilename ?? '');
```

with:

```dart
    final isVideoSource = editorState.project?.isVideo ?? false;
```

- [ ] **Step 2: Delete the now-unused helper**

Remove the `_isVideoSource` method (lines 233-237):

```dart
  bool _isVideoSource(String filename) {
    if (!filename.contains('.')) return false;
    final ext = filename.split('.').last.toLowerCase();
    return const {'mp4', 'avi', 'mkv', 'mov', 'webm'}.contains(ext);
  }
```

- [ ] **Step 3: Verify the analyzer is clean**

Run (from `FrontEnd/`): `flutter analyze lib/widgets/editor/editor_toolbar.dart`
Expected: No issues (no "unused element" for `_isVideoSource`, no undefined `isVideo`).

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/lib/widgets/editor/editor_toolbar.dart
git commit -m "fix(editor): gate video export options on project.isVideo not filename parse"
```

---

## PHASE 4 — Frontend: friendly "media unavailable" UX (Issue 2)

### Task 7: Add a media-availability check to MediaService

**Files:**
- Modify: `FrontEnd/lib/services/media_service.dart`

- [ ] **Step 1: Add the method**

In `FrontEnd/lib/services/media_service.dart`, add this method to the `MediaService` class (e.g. after `uploadFile`). It returns `true` on 200, `false` on 404, and treats other errors as "available" so transient network blips don't mislabel a project as gone:

```dart
  /// Returns whether the media file for [fileId] still exists on the server.
  /// 404 -> false (file was cleaned up / lost). Other errors -> true
  /// (don't punish the user for a transient network hiccup).
  Future<bool> isMediaAvailable(String fileId) async {
    try {
      await _client.dio.get(ApiConfig.mediaInfo(fileId));
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      return true;
    }
  }
```

- [ ] **Step 2: Verify analyzer**

Run (from `FrontEnd/`): `flutter analyze lib/services/media_service.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add FrontEnd/lib/services/media_service.dart
git commit -m "feat(media-service): add isMediaAvailable(fileId) 404 check"
```

---

### Task 8: Add a `mediaUnavailable` state to the video player

**Files:**
- Modify: `FrontEnd/lib/providers/video_player_provider.dart:8-63` (state) and add a notifier method

- [ ] **Step 1: Add the state field**

In `FrontEnd/lib/providers/video_player_provider.dart`, `VideoPlayerState`:

Add the field (after `error`, line 18):

```dart
  final bool mediaUnavailable;
```

Add to the constructor (after `this.error`, line 30):

```dart
    this.mediaUnavailable = false,
```

Add to `copyWith` params (after `String? error,`, line 46):

```dart
    bool? mediaUnavailable,
```

And to the returned object (after `error: error,`, line 58):

```dart
      mediaUnavailable: mediaUnavailable ?? this.mediaUnavailable,
```

- [ ] **Step 2: Add a notifier method to mark unavailable**

In `VideoPlayerNotifier`, add (near `initialize`):

```dart
  /// Mark the project's media as gone from the server so the UI can show a
  /// clear "re-upload" message instead of an endless "Loading video...".
  void markUnavailable() {
    state = state.copyWith(
      mediaUnavailable: true,
      error: 'Media unavailable',
    );
  }
```

- [ ] **Step 3: Verify analyzer**

Run (from `FrontEnd/`): `flutter analyze lib/providers/video_player_provider.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/lib/providers/video_player_provider.dart
git commit -m "feat(player): add mediaUnavailable state + markUnavailable()"
```

---

### Task 9: Pre-check availability and show the friendly message

**Files:**
- Modify: `FrontEnd/lib/screens/editor/subtitle_editor_screen.dart:51-61`
- Modify: `FrontEnd/lib/widgets/editor/video_preview_panel.dart:62-81`

- [ ] **Step 1: Pre-check before initializing the player**

In `FrontEnd/lib/screens/editor/subtitle_editor_screen.dart`, add the import (with the other service imports, near line 10):

```dart
import '../../services/media_service.dart';
```

Replace `_initializeEditor` (lines 51-61) with:

```dart
  Future<void> _initializeEditor() async {
    // Load subtitle project from backend
    await ref.read(editorNotifierProvider.notifier).loadProject(
          widget.fileId,
          widget.transcription,
        );

    // If the media file no longer exists on the server (e.g. an old recents
    // project whose temp file was cleaned up), show a clear message instead
    // of letting the player spin forever.
    final available =
        await ref.read(mediaServiceProvider).isMediaAvailable(widget.fileId);
    if (!available) {
      ref.read(videoPlayerNotifierProvider.notifier).markUnavailable();
      return;
    }

    // Initialize video player with streaming URL
    final videoUrl = ApiConfig.mediaStreamUrl(widget.fileId);
    await ref.read(videoPlayerNotifierProvider.notifier).initialize(videoUrl);
  }
```

> `mediaServiceProvider` is defined in `lib/services/media_service.dart` (the existing provider near line 148).

- [ ] **Step 2: Render the friendly message in the preview panel**

In `FrontEnd/lib/widgets/editor/video_preview_panel.dart`, replace the fallback `Center(...)` block (lines 62-81, the `: Center(` branch) with a version that swaps icon + text when media is unavailable:

```dart
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              playerState.mediaUnavailable
                                  ? Icons.cloud_off_rounded
                                  : Icons.videocam_off_rounded,
                              size: AppSizes.iconXl,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              playerState.mediaUnavailable
                                  ? 'This project\'s media file is no longer '
                                      'available. Please re-upload the video to '
                                      'edit or export captions.'
                                  : (playerState.error ?? 'Loading video...'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: AppSizes.fontSm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
```

- [ ] **Step 3: Verify analyzer**

Run (from `FrontEnd/`): `flutter analyze lib/screens/editor/subtitle_editor_screen.dart lib/widgets/editor/video_preview_panel.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/editor/subtitle_editor_screen.dart FrontEnd/lib/widgets/editor/video_preview_panel.dart
git commit -m "feat(editor): show 'media unavailable' message when stream is gone"
```

---

## PHASE 5 — Optional migration + end-to-end verification

### Task 10 (OPTIONAL): Migrate the 2 surviving /tmp files

Only do this if the `/tmp/romasub_uploads` files still exist and you want those
specific demo projects to keep playing. The 14 already-deleted files cannot be
recovered.

- [ ] **Step 1: Copy surviving files into the durable dir**

```bash
mkdir -p uploads/media
cp -n /tmp/romasub_uploads/* uploads/media/ 2>/dev/null || true
ls uploads/media/
```

- [ ] **Step 2: Confirm rehydrate will pick them up**

Run: `python -c "from app.services import media as m; m._file_registry.clear(); print('rehydrated:', m.rehydrate_from_disk()); print('sample:', next(iter(m._file_registry), None))"`
Expected: prints `rehydrated: N` (N>0) and a sample file_id.

No commit (media files are gitignored).

---

### Task 11: Full verification

- [ ] **Step 1: Backend tests + import smoke**

Run: `python -m pytest tests/ -v`
Expected: all PASS.

Run: `python -c "import app.main"` (or the actual app entrypoint — check `README.md`/`SETUP.md` for the uvicorn target)
Expected: imports without error.

- [ ] **Step 2: Frontend analyze + tests**

Run (from `FrontEnd/`): `flutter analyze`
Expected: No new issues introduced by these changes.

Run (from `FrontEnd/`): `flutter test`
Expected: all PASS.

- [ ] **Step 3: Manual end-to-end (with backend running)**

Per `SETUP.md`, start the backend and run the Flutter app. Verify:

1. **Export menu (video project):** open a project whose source is `.mp4` → Export dropdown shows SRT, VTT, TXT **and** both "Video — …" options.
2. **Export menu (audio project):** if an audio-only project exists, it shows only SRT/VTT/TXT.
3. **Recents playback (present file):** open a project whose media exists in `uploads/media/` → video plays.
4. **Recents playback (missing file):** open one of the older projects whose media is gone → preview shows *"This project's media file is no longer available. Please re-upload…"* (not an endless spinner).
5. **Restart durability:** upload a new video, stop and restart the backend, open that project from recents → it still plays (durable storage + registry reload).

- [ ] **Step 4: Final review + completion**

Use `superpowers:requesting-code-review` (or `/code-review`) on the branch diff, then `superpowers:finishing-a-development-branch` to decide how to land it.

---

## Self-Review (completed by plan author)

- **Spec coverage:** Issue 1 → Tasks 1, 5, 6. Issue 2 durable storage → Task 2; registry persist → Task 3; rehydrate → Task 4; friendly UX → Tasks 7-9; optional migration → Task 10. All spec sections mapped.
- **Type consistency:** backend `is_video` (snake_case) ↔ frontend `isVideo` / `json['is_video']`; `media_upload_dir` used consistently; `_FILE_REGISTRY_FILE`, `_save_registry`, `_load_registry`, `rehydrate_from_disk` names consistent across tasks; `mediaUnavailable` + `markUnavailable()` consistent between Task 8 and Task 9.
- **Placeholders:** none — every code step shows real code. The one parameterized note (Dart package name in Task 5) is explicit with how to resolve it.
