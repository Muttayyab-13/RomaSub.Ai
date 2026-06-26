# Download Video with Captions — Design

**Date:** 2026-06-14
**Status:** Approved (design)

## Summary

Add the ability to download a **video file with its captions attached**, alongside
the existing text-only subtitle exports (SRT, VTT, TXT). The user can choose between
two attachment methods at download time:

- **Hardsub (burned-in):** subtitles are rendered permanently into the video pixels.
  Works on every player and social platform. Requires a full re-encode (slower).
- **Softsub (toggleable track):** subtitles are muxed into the MP4 as a selectable
  subtitle track. Near-instant (stream copy, no re-encode), but not all players show
  it and social platforms ignore it.

Captions use the **Roman Urdu** text variant. Processing is **synchronous** with a
progress UI on the frontend.

## Decisions

| Decision | Choice |
| --- | --- |
| Caption method | Both hardsub and softsub; user picks at download time |
| Caption text | Roman Urdu (`roman_urdu_text`), falling back to `urdu_text` only when a segment's Roman field is empty |
| Processing model | Synchronous request; frontend shows a progress/loading state |
| Output container | MP4 only |
| Surface | Editor export dropdown (`editor_toolbar.dart`), where SRT/VTT/TXT already live |

## Context (current state)

- **Backend (FastAPI):**
  - `app/services/subtitle.py` — pure text formatters (`seconds_to_srt_time`,
    `format_as_srt/vtt/txt`, `export_subtitles`) plus project CRUD. Already ~550 lines.
  - `app/routers/subtitle.py` — mounted at `/subtitles`; existing
    `GET /subtitles/{id}/export?format=` returns text content as JSON.
  - `app/services/media.py` — stores uploaded files in a temp dir keyed by `file_id`
    (in-memory metadata) and serves them via `GET /media/{file_id}/stream`. FFmpeg is
    already available through `static_ffmpeg` (used today for audio extraction).
  - A subtitle project stores `file_id`, `original_filename`, and `segments` (each
    segment has both `urdu_text` and `roman_urdu_text`).
- **Frontend (Flutter + Dio + Riverpod):**
  - `editor_toolbar.dart` — export `PopupMenuButton` offering SRT/VTT/TXT;
    `_handleExport` writes the returned text to the downloads directory.
  - `subtitle_service.dart` — `exportSubtitles(id, format)` calls the JSON export
    endpoint via `ApiClient.dio`.
  - `api_config.dart` — endpoint path builders (e.g. `subtitleExport`).

## Architecture

Chosen approach: **a new isolated `video_export` service plus one streaming endpoint.**
This keeps FFmpeg/subprocess concerns out of the already-large `subtitle.py` and in one
testable place. (Rejected: adding to `subtitle.py` — grows a large file and mixes pure
formatting with heavy subprocess work. Rejected: background job + polling — the chosen
model is synchronous.)

### 1. Backend service — `app/services/video_export.py` (new)

```
export_video_with_subtitles(subtitle_id: str, mode: str)
    -> Tuple[success: bool, message: str, output_path: str, download_filename: str]
```

Steps:

1. Resolve `subtitle_id` → project → `file_id` → media file path via `media_service`.
2. **Validate:**
   - Project exists and has at least one segment, else 400.
   - Source is a **video** file (`media_service.is_video_file` / stored `is_video`),
     else 400 ("Video export requires a video file").
   - Source file still exists on disk, else 404 ("Source video no longer available").
   - `mode` is one of `hardsub` / `softsub`, else 400.
3. Build a **temporary SRT** from each segment's `roman_urdu_text` (fallback to
   `urdu_text` only when the Roman field is empty, so captions are never blank).
   Reuse `subtitle.seconds_to_srt_time` and `subtitle.format_as_srt`.
4. Run FFmpeg (via `subprocess`, paths added by `static_ffmpeg`) to a temp `.mp4`:
   - **hardsub:** `ffmpeg -i <in> -vf subtitles=<srt> -c:v libx264 -preset veryfast
     -crf 23 -c:a aac -movflags +faststart <out>`
   - **softsub:** `ffmpeg -i <in> -i <srt> -c copy -c:s mov_text -movflags +faststart <out>`
5. On FFmpeg failure, log stderr and return `(False, message, "", "")`.
6. Return the output path and a friendly download filename:
   - hardsub → `<base>_roman_subtitled.mp4`
   - softsub → `<base>_roman_softsubs.mp4`

Temp SRT and (after streaming) temp output are cleaned up.

### 2. Backend endpoint — `app/routers/subtitle.py`

```
GET /subtitles/{subtitle_id}/export-video?mode=hardsub|softsub
    -> FileResponse(output_path, media_type="video/mp4", filename=download_filename)
```

- Validates `mode`; calls `video_export.export_video_with_subtitles`.
- On failure maps to the appropriate HTTP error (400/404/500) with the service message.
- Records the export via `subtitle_service.record_export` with fmt `mp4-hardsub` /
  `mp4-softsub` so it appears on the Recent Exports page.
- Cleans up the temp SRT (output is handed to `FileResponse`).

### 3. Frontend — `editor_toolbar.dart`

- Add two items below the text formats in the export `PopupMenuButton`:
  - value `video_hardsub` → "Video — burned-in captions"
  - value `video_softsub` → "Video — toggleable captions"
- Shown only when the project source is a video (guard client-side by filename
  extension; backend validation is the source of truth).
- `onSelected` routes `video_*` values to a new `_handleVideoExport(context, ref, mode)`
  which:
  - Opens a **non-dismissible progress dialog** ("Rendering video with captions — this
    can take a few minutes").
  - Calls the new notifier/service method, writes the returned bytes to the downloads
    directory, closes the dialog, and shows the existing success/failure snackbar.

### 4. Frontend — `subtitle_service.dart` + `api_config.dart`

- `api_config.dart`: add `subtitleExportVideo(subtitleId)` →
  `'/subtitles/$subtitleId/export-video'`.
- `subtitle_service.dart`: add
  `Future<({List<int> bytes, String filename})> downloadVideoWithCaptions(
      String subtitleId, String mode)` using `dio.get` with
  `ResponseType.bytes` and an **extended receive timeout** (rendering can take minutes).
  Derives the filename from the `content-disposition` header (fallback to a default).
- Wire through the editor notifier/provider so the toolbar can invoke it.

## Error handling

| Condition | Result |
| --- | --- |
| Unknown `mode` | 400 |
| Project missing / no segments | 400 |
| Source is audio-only | 400 ("Video export requires a video file") |
| Source file missing on disk | 404 ("Source video no longer available") |
| FFmpeg non-zero exit | 500; stderr logged server-side, generic message to client |
| Frontend request error/timeout | progress dialog closed, failure snackbar shown |

## Testing

- **Unit:** SRT builder uses `roman_urdu_text` with the empty→`urdu_text` fallback;
  FFmpeg command construction for each mode (build the arg list via a pure helper so it
  can be asserted without running FFmpeg).
- **Manual end-to-end:** burn and mux a short real clip; confirm hardsub shows baked-in
  captions everywhere and softsub shows a toggleable track in a player that supports it.

## Scope / non-goals (v1)

- MP4 output only.
- Captions are Roman Urdu only (no Urdu/both/English choice).
- Wired into the editor export menu only (not the dashboard exports surface).
- No caption styling controls — sensible readable FFmpeg/libass defaults.
- No background job / progress percentage — a single synchronous request with an
  indeterminate progress indicator.

## Known limitations

- Media metadata is in-memory; if the backend restarts between editing and export, the
  `file_id` mapping is lost and export returns 404. This matches the existing behavior
  of the video player/streaming endpoint and is acceptable for v1.

## As-shipped notes (post-review deltas)

The implementation follows this design; the following refinements were added during code
review and are reflected in the shipped code:

- **Render timeout.** `subprocess.run` uses a 30-minute (`1800s`) ceiling so a hung
  FFmpeg can't pin a worker forever; a `TimeoutExpired` is treated as a render failure
  and cleans up the partial output. The frontend Dio receive timeout is 10 minutes.
- **Softsub stream mapping.** The softsub command maps `-map 0:v -map 0:a? -map 1`
  (video + optional audio + the new SRT) rather than `-map 0`, so embedded subtitle/data
  streams from an MKV source can't break `mov_text` muxing into MP4.
- **Hardsub path escaping.** The `subtitles=` filtergraph value is single-quoted and
  escaped (`\`, `'`, `:`) so a temp path with special characters can't break the filter.
- **Best-effort export history.** The endpoint builds the `FileResponse` (registering the
  temp-file cleanup) before recording the export, and the `record_export` call is wrapped
  so a history-write failure neither discards the download nor leaks the temp file.
- **Error surfacing.** `_handleError` decodes the JSON error body even for binary
  (`ResponseType.bytes`) responses and surfaces the server's 404 detail (e.g. "Source
  video no longer available. Please re-upload."). On failure the editor records the error
  in state (shown via the editor's error banner), matching how text exports report
  failures — no duplicate snackbar.
