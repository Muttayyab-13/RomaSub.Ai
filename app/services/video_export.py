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

_SUFFIXES = {"hardsub": "subtitled", "softsub": "softsubs"}

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
