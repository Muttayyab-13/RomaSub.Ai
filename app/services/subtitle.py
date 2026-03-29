"""
Subtitle Service for RomaSub.AI
Handles subtitle project creation, editing, and export

Pure functions for subtitle operations with in-memory project storage.
"""

import uuid
from typing import Optional, Dict, List, Tuple
from datetime import datetime

from app.services import asr as asr_service
from app.services import media as media_service
import logging

logger = logging.getLogger(__name__)


# ============================================================================
# Module-level state for subtitle projects
# ============================================================================

# In-memory storage for subtitle projects (temporary)
_subtitle_projects: Dict[str, Dict] = {}

# Maps file_id -> subtitle_id for quick lookup
_file_to_subtitle: Dict[str, str] = {}


# ============================================================================
# Validation Constants (from SRS)
# ============================================================================

MAX_SEGMENT_CHARS = 500
MIN_SEGMENT_DURATION = 0.5
MAX_SEGMENT_DURATION = 7.0
MIN_GAP_BETWEEN_SEGMENTS = 0.1


# ============================================================================
# Project Management
# ============================================================================

def create_project(
    file_id: str,
    original_filename: str,
    duration: Optional[float],
    project_name: Optional[str] = None,
    segments: Optional[List[Dict]] = None
) -> Tuple[bool, str, Dict]:
    """
    Create a new subtitle project from transcription data.

    Args:
        file_id: ID of the source media file
        original_filename: Original filename
        duration: File duration in seconds
        project_name: Optional project name
        segments: Optional pre-built segments. If None, fetched from transcription results.

    Returns:
        Tuple of (success, message, project_dict)
    """
    # Check if project already exists for this file
    if file_id in _file_to_subtitle:
        existing_id = _file_to_subtitle[file_id]
        if existing_id in _subtitle_projects:
            return True, "Project already exists", _subtitle_projects[existing_id]

    # Build segments from transcription if not provided
    if segments is None:
        transcription = asr_service.get_transcription_result(file_id)
        if not transcription:
            return False, "No transcription found for this file", {}

        roman_urdu_segments = transcription.get("roman_urdu_segments", [])
        urdu_segments = transcription.get("segments", [])

        segments = []
        for i, urdu_seg in enumerate(urdu_segments):
            roman_seg = roman_urdu_segments[i] if i < len(roman_urdu_segments) else {}
            segments.append({
                "id": i,
                "start": urdu_seg["start"],
                "end": urdu_seg["end"],
                "urdu_text": urdu_seg.get("text", ""),
                "roman_urdu_text": roman_seg.get("roman_urdu_text", ""),
                "is_edited": False
            })

        if not duration:
            duration = transcription.get("audio_duration_seconds")

    subtitle_id = str(uuid.uuid4())
    now = datetime.now().isoformat()

    project = {
        "subtitle_id": subtitle_id,
        "file_id": file_id,
        "project_name": project_name or original_filename,
        "original_filename": original_filename,
        "segments": segments,
        "segment_count": len(segments),
        "file_duration": duration,
        "created_at": now,
        "updated_at": now
    }

    _subtitle_projects[subtitle_id] = project
    _file_to_subtitle[file_id] = subtitle_id

    logger.info("Subtitle project created: %s for file: %s", subtitle_id, file_id)
    return True, "Project created", project


def get_project(subtitle_id: str) -> Optional[Dict]:
    """Get subtitle project by ID."""
    return _subtitle_projects.get(subtitle_id)


def get_project_by_file(file_id: str) -> Optional[Dict]:
    """Get subtitle project by file ID."""
    subtitle_id = _file_to_subtitle.get(file_id)
    if subtitle_id:
        return _subtitle_projects.get(subtitle_id)
    return None


def list_all_projects() -> List[Dict]:
    """List all subtitle projects (summary without full segments)."""
    projects = []
    for project in _subtitle_projects.values():
        projects.append({
            "subtitle_id": project["subtitle_id"],
            "file_id": project["file_id"],
            "project_name": project["project_name"],
            "original_filename": project["original_filename"],
            "segment_count": project["segment_count"],
            "file_duration": project.get("file_duration"),
            "created_at": project["created_at"],
            "updated_at": project["updated_at"],
        })
    # Sort by created_at descending (newest first)
    projects.sort(key=lambda p: p["created_at"], reverse=True)
    return projects


# In-memory export history
_export_history: List[Dict] = []


def record_export(subtitle_id: str, fmt: str, filename: str) -> Dict:
    """Record an export in the history."""
    project = get_project(subtitle_id)
    record = {
        "id": str(uuid.uuid4()),
        "subtitle_id": subtitle_id,
        "project_name": project["project_name"] if project else "Unknown",
        "filename": filename,
        "format": fmt,
        "created_at": datetime.now().isoformat(),
    }
    _export_history.insert(0, record)  # newest first
    return record


def list_exports() -> List[Dict]:
    """List all export history."""
    return _export_history


# ============================================================================
# Segment Editing
# ============================================================================

def _find_segment(project: Dict, segment_id: int) -> Optional[int]:
    """Find segment index by ID. Returns index or None."""
    for i, seg in enumerate(project["segments"]):
        if seg["id"] == segment_id:
            return i
    return None


def _resequence_ids(segments: List[Dict]) -> None:
    """Resequence segment IDs after add/delete."""
    for i, seg in enumerate(segments):
        seg["id"] = i


def _validate_segment(segment: Dict, project: Dict, index: int) -> Optional[str]:
    """Validate a segment against business rules. Returns error message or None."""
    start = segment["start"]
    end = segment["end"]
    duration = end - start

    if duration < MIN_SEGMENT_DURATION:
        return f"Segment duration ({duration:.2f}s) is below minimum ({MIN_SEGMENT_DURATION}s)"
    if duration > MAX_SEGMENT_DURATION:
        return f"Segment duration ({duration:.2f}s) exceeds maximum ({MAX_SEGMENT_DURATION}s)"

    for field in ("roman_urdu_text", "urdu_text"):
        text = segment.get(field, "")
        if len(text) > MAX_SEGMENT_CHARS:
            return f"{field} exceeds {MAX_SEGMENT_CHARS} characters"

    return None


def update_segment(
    subtitle_id: str,
    segment_id: int,
    roman_urdu_text: Optional[str] = None,
    urdu_text: Optional[str] = None,
    start: Optional[float] = None,
    end: Optional[float] = None
) -> Tuple[bool, str, Dict]:
    """
    Update a single segment's text or timing.

    Returns:
        Tuple of (success, message, updated_segment)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found", {}

    idx = _find_segment(project, segment_id)
    if idx is None:
        return False, f"Segment {segment_id} not found", {}

    segment = project["segments"][idx]

    # Apply updates
    if roman_urdu_text is not None:
        segment["roman_urdu_text"] = roman_urdu_text
    if urdu_text is not None:
        segment["urdu_text"] = urdu_text
    if start is not None:
        segment["start"] = start
    if end is not None:
        segment["end"] = end

    # Validate
    error = _validate_segment(segment, project, idx)
    if error:
        return False, error, {}

    segment["is_edited"] = True
    project["updated_at"] = datetime.now().isoformat()

    return True, "Segment updated", segment


def add_segment(
    subtitle_id: str,
    after_segment_id: int,
    start: float,
    end: float,
    roman_urdu_text: str = "",
    urdu_text: str = ""
) -> Tuple[bool, str, Dict]:
    """
    Add a new segment after the given segment ID.

    Returns:
        Tuple of (success, message, new_segment)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found", {}

    idx = _find_segment(project, after_segment_id)
    if idx is None:
        return False, f"Segment {after_segment_id} not found", {}

    new_segment = {
        "id": 0,  # will be resequenced
        "start": start,
        "end": end,
        "urdu_text": urdu_text,
        "roman_urdu_text": roman_urdu_text,
        "is_edited": True
    }

    # Validate
    error = _validate_segment(new_segment, project, idx + 1)
    if error:
        return False, error, {}

    # Insert after the target segment
    project["segments"].insert(idx + 1, new_segment)
    _resequence_ids(project["segments"])
    project["segment_count"] = len(project["segments"])
    project["updated_at"] = datetime.now().isoformat()

    return True, "Segment added", new_segment


def delete_segment(subtitle_id: str, segment_id: int) -> Tuple[bool, str]:
    """
    Delete a segment by ID.

    Returns:
        Tuple of (success, message)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found"

    idx = _find_segment(project, segment_id)
    if idx is None:
        return False, f"Segment {segment_id} not found"

    project["segments"].pop(idx)
    _resequence_ids(project["segments"])
    project["segment_count"] = len(project["segments"])
    project["updated_at"] = datetime.now().isoformat()

    return True, "Segment deleted"


def bulk_update(subtitle_id: str, segments: List[Dict]) -> Tuple[bool, str, Dict]:
    """
    Replace all segments (used for auto-save).

    Returns:
        Tuple of (success, message, project)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found", {}

    # Resequence incoming segments
    for i, seg in enumerate(segments):
        seg["id"] = i

    project["segments"] = segments
    project["segment_count"] = len(segments)
    project["updated_at"] = datetime.now().isoformat()

    return True, "Segments updated", project


def fix_overlaps(subtitle_id: str) -> Tuple[bool, str, List[Dict]]:
    """
    Auto-fix timing overlaps between segments.
    Ensures MIN_GAP_BETWEEN_SEGMENTS gap between consecutive segments.

    Returns:
        Tuple of (success, message, fixed_segments)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found", []

    segments = project["segments"]
    if len(segments) < 2:
        return True, "No overlaps to fix", segments

    # Sort by start time
    segments.sort(key=lambda s: s["start"])
    fixes = 0

    for i in range(1, len(segments)):
        prev_end = segments[i - 1]["end"]
        curr_start = segments[i]["start"]
        gap = curr_start - prev_end

        if gap < MIN_GAP_BETWEEN_SEGMENTS:
            # Adjust current segment start to create minimum gap
            segments[i]["start"] = prev_end + MIN_GAP_BETWEEN_SEGMENTS
            # If this makes start >= end, adjust end too
            if segments[i]["start"] >= segments[i]["end"]:
                segments[i]["end"] = segments[i]["start"] + MIN_SEGMENT_DURATION
            segments[i]["is_edited"] = True
            fixes += 1

    _resequence_ids(segments)
    project["updated_at"] = datetime.now().isoformat()

    return True, f"Fixed {fixes} overlap(s)", segments


# ============================================================================
# Export Functions
# ============================================================================

def seconds_to_srt_time(seconds: float) -> str:
    """Convert seconds to SRT time format (HH:MM:SS,mmm)."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def seconds_to_vtt_time(seconds: float) -> str:
    """Convert seconds to VTT time format (HH:MM:SS.mmm)."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def format_as_srt(segments: List[Dict]) -> str:
    """Format segments as SRT subtitle format."""
    lines = []
    for i, seg in enumerate(segments, 1):
        start = seconds_to_srt_time(seg["start"])
        end = seconds_to_srt_time(seg["end"])
        text = seg.get("roman_urdu_text", "") or seg.get("urdu_text", "")
        lines.append(f"{i}")
        lines.append(f"{start} --> {end}")
        lines.append(text)
        lines.append("")
    return "\n".join(lines)


def format_as_vtt(segments: List[Dict]) -> str:
    """Format segments as WebVTT subtitle format."""
    lines = ["WEBVTT", ""]
    for i, seg in enumerate(segments, 1):
        start = seconds_to_vtt_time(seg["start"])
        end = seconds_to_vtt_time(seg["end"])
        text = seg.get("roman_urdu_text", "") or seg.get("urdu_text", "")
        lines.append(f"{i}")
        lines.append(f"{start} --> {end}")
        lines.append(text)
        lines.append("")
    return "\n".join(lines)


def format_as_txt(segments: List[Dict]) -> str:
    """Format segments as plain text (no timestamps)."""
    lines = []
    for seg in segments:
        text = seg.get("roman_urdu_text", "") or seg.get("urdu_text", "")
        if text:
            lines.append(text)
    return "\n".join(lines)


def export_subtitles(subtitle_id: str, fmt: str = "srt") -> Tuple[bool, str, str, str]:
    """
    Export subtitles in the specified format.

    Args:
        subtitle_id: Project ID
        fmt: Export format ('srt', 'vtt', 'txt')

    Returns:
        Tuple of (success, message, content, filename)
    """
    project = get_project(subtitle_id)
    if not project:
        return False, "Project not found", "", ""

    segments = project["segments"]
    base_name = project["original_filename"].rsplit(".", 1)[0]

    formatters = {
        "srt": format_as_srt,
        "vtt": format_as_vtt,
        "txt": format_as_txt,
    }

    formatter = formatters.get(fmt)
    if not formatter:
        return False, f"Unsupported format: {fmt}. Use srt, vtt, or txt", "", ""

    content = formatter(segments)
    filename = f"{base_name}_roman_urdu.{fmt}"

    return True, "Export successful", content, filename
