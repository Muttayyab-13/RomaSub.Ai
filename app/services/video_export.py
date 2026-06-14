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

# Hard ceiling so a hung FFmpeg can't pin a request worker forever.
VIDEO_EXPORT_TIMEOUT_SECONDS = 1800

_SUFFIXES = {"hardsub": "subtitled", "softsub": "softsubs"}

# Error messages — the router maps these to HTTP status codes.
MSG_BAD_MODE = "Unsupported mode. Use hardsub or softsub"
MSG_PROJECT_NOT_FOUND = "Project not found"
MSG_NO_SEGMENTS = "Project has no segments to render"
MSG_SOURCE_MISSING = "Source video no longer available. Please re-upload."
MSG_NOT_VIDEO = "Video export requires a video file"
MSG_RENDER_FAILED = "Video rendering failed"
MSG_FFMPEG_MISSING = "FFmpeg not found. Please install FFmpeg."
MSG_EXPORT_OK = "Export successful"


def build_output_filename(original_filename: str, mode: str) -> str:
    """Build a friendly download filename for the rendered MP4."""
    suffix = _SUFFIXES.get(mode)
    if suffix is None:
        raise ValueError(f"Unsupported mode: {mode}")
    base = original_filename.rsplit(".", 1)[0]
    return f"{base}_roman_{suffix}.mp4"


def build_ffmpeg_command(
    input_path: str, srt_path: str, output_path: str, mode: str
) -> List[str]:
    """Build the FFmpeg argument list for the requested mode."""
    if mode == "hardsub":
        escaped_srt = srt_path.replace("\\", "\\\\").replace("'", "\\'").replace(":", "\\:")
        return [
            "ffmpeg", "-y",
            "-i", input_path,
            "-vf", f"subtitles='{escaped_srt}'",
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
    logger.info("Rendering video export (mode=%s, token=%s)", mode, token)
    logger.debug("Video export FFmpeg command: %s", " ".join(command))

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=VIDEO_EXPORT_TIMEOUT_SECONDS,
        )
    except FileNotFoundError:
        return False, MSG_FFMPEG_MISSING, "", ""
    except subprocess.TimeoutExpired:
        logger.error("Video export timed out after %ss", VIDEO_EXPORT_TIMEOUT_SECONDS)
        _safe_remove(output_path)
        return False, MSG_RENDER_FAILED, "", ""
    finally:
        _safe_remove(srt_path)

    if result.returncode != 0 or not os.path.exists(output_path):
        stderr_tail = result.stderr[-2000:] if result.stderr else ""
        logger.error("Video export failed (rc=%s): %s", result.returncode, stderr_tail)
        _safe_remove(output_path)
        return False, MSG_RENDER_FAILED, "", ""

    download_filename = build_output_filename(project["original_filename"], mode)
    return True, MSG_EXPORT_OK, output_path, download_filename
