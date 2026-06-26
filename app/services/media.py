"""
Media Service for RomaSub.AI
Handles video/audio file uploads and audio extraction

Pure functions for media operations with in-memory file registry.
"""

import os
import json
import uuid
import subprocess
from pathlib import Path
from typing import Optional, Tuple, Dict
from fastapi import UploadFile
import static_ffmpeg
static_ffmpeg.add_paths()

from app.config import settings
import logging

logger = logging.getLogger(__name__)


# ============================================================================
# Module-level state for in-memory file tracking
# ============================================================================

# In-memory storage for file metadata (temporary files only)
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


# ============================================================================
# File Validation Functions
# ============================================================================

def generate_file_id() -> str:
    """Generate unique file ID using UUID4."""
    return str(uuid.uuid4())


def get_file_extension(filename: str) -> str:
    """
    Extract file extension from filename.

    Args:
        filename: Original filename

    Returns:
        File extension without dot (e.g., 'mp4', 'wav')
    """
    return Path(filename).suffix.lower().lstrip('.')


def is_valid_extension(filename: str) -> bool:
    """
    Check if file extension is allowed.

    Args:
        filename: Filename to check

    Returns:
        True if extension is allowed
    """
    ext = get_file_extension(filename)
    return ext in settings.allowed_extensions


def is_video_file(filename: str) -> bool:
    """
    Check if file is a video based on extension.

    Args:
        filename: Filename to check

    Returns:
        True if file is a video format
    """
    ext = get_file_extension(filename)
    return ext in settings.allowed_video_extensions.split(',')


def is_audio_file(filename: str) -> bool:
    """
    Check if file is an audio file based on extension.

    Args:
        filename: Filename to check

    Returns:
        True if file is an audio format
    """
    ext = get_file_extension(filename)
    return ext in settings.allowed_audio_extensions.split(',')


# ============================================================================
# File Upload & Management
# ============================================================================

async def save_upload_file(upload_file: UploadFile) -> Tuple[bool, str, Dict]:
    """
    Save uploaded file to temporary storage with in-memory tracking.

    Args:
        upload_file: FastAPI UploadFile object

    Returns:
        Tuple of (success, message/file_id, file_info_dict)
    """
    # Validate extension
    if not is_valid_extension(upload_file.filename):
        return False, f"Invalid file type. Allowed: {settings.allowed_extensions}", {}

    # Generate unique file ID and path
    file_id = generate_file_id()
    ext = get_file_extension(upload_file.filename)

    # Ensure upload directory exists
    os.makedirs(settings.media_upload_dir, exist_ok=True)

    # Create file path
    file_path = os.path.join(settings.media_upload_dir, f"{file_id}.{ext}")

    try:
        # Save file in chunks
        with open(file_path, "wb") as buffer:
            chunk_size = 1024 * 1024  # 1MB chunks
            while True:
                chunk = await upload_file.read(chunk_size)
                if not chunk:
                    break
                buffer.write(chunk)

        # Get file size
        file_size = os.path.getsize(file_path)

        # Check file size limit
        if file_size > settings.max_file_size_bytes:
            os.remove(file_path)
            return False, f"File too large. Max size: {settings.max_file_size_mb}MB", {}

        # Determine file type
        is_video = is_video_file(upload_file.filename)

        # Store file info in memory
        file_info = {
            "file_id": file_id,
            "original_filename": upload_file.filename,
            "file_path": file_path,
            "file_size": file_size,
            "extension": ext,
            "is_video": is_video,
            "audio_path": None,
            "status": "uploaded"
        }

        _file_registry[file_id] = file_info
        _save_registry()

        logger.info("File uploaded: %s (%s bytes)", file_id, file_size)
        print(f"\n[UPLOAD] File saved: {file_path}")
        print(f"[UPLOAD] File ID: {file_id}")
        print(f"[UPLOAD] Size: {file_size / (1024*1024):.2f} MB")

        return True, file_id, file_info

    except Exception as e:
        logger.error("Failed to save file: %s", str(e))
        if os.path.exists(file_path):
            os.remove(file_path)
        return False, f"Failed to save file: {str(e)}", {}


def get_file_info(file_id: str) -> Optional[Dict]:
    """
    Get file information by ID from in-memory registry.

    Args:
        file_id: Unique file identifier

    Returns:
        File info dictionary or None if not found
    """
    return _file_registry.get(file_id)


# ============================================================================
# Audio Extraction
# ============================================================================

def extract_audio(file_id: str) -> Tuple[bool, str]:
    """
    Extract audio from video file using FFmpeg.

    For audio files, returns the original file path.
    For video files, extracts audio track as WAV (16kHz, mono).

    Args:
        file_id: ID of the uploaded file

    Returns:
        Tuple of (success, audio_path or error_message)
    """
    file_info = get_file_info(file_id)
    if not file_info:
        return False, "File not found"

    # If already audio, no extraction needed
    if not file_info["is_video"]:
        file_info["audio_path"] = file_info["file_path"]
        file_info["status"] = "audio_ready"
        _save_registry()
        print(f"\n[AUDIO] File is already audio: {file_info['file_path']}")
        return True, file_info["file_path"]

    # If audio already extracted
    if file_info.get("audio_path"):
        return True, file_info["audio_path"]

    # Generate audio output path
    audio_path = os.path.join(
        settings.media_upload_dir,
        f"{file_id}_audio.wav"
    )

    try:
        print(f"\n[AUDIO] Extracting audio from: {file_info['file_path']}")
        print(f"[AUDIO] Output path: {audio_path}")

        # Use FFmpeg to extract audio
        command = [
            "ffmpeg",
            "-i", file_info["file_path"],
            "-vn",  # No video
            "-acodec", "pcm_s16le",  # WAV format
            "-ar", "16000",  # 16kHz sample rate (good for Whisper)
            "-ac", "1",  # Mono channel
            "-y",  # Overwrite output
            audio_path
        ]

        result = subprocess.run(
            command,
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            logger.error("FFmpeg error: %s", result.stderr)
            file_info["status"] = "extraction_failed"
            return False, f"Audio extraction failed: {result.stderr}"

        # Update file info in memory
        file_info["audio_path"] = audio_path
        file_info["status"] = "audio_ready"
        _save_registry()

        audio_size = os.path.getsize(audio_path)
        print(f"[AUDIO] Extraction complete: {audio_size / (1024*1024):.2f} MB")

        logger.info("Audio extracted for file: %s", file_id)
        return True, audio_path

    except FileNotFoundError:
        error_msg = "FFmpeg not found. Please install FFmpeg."
        logger.error(error_msg)
        file_info["status"] = "extraction_failed"
        return False, error_msg

    except Exception as e:
        logger.error("Audio extraction failed: %s", str(e))
        file_info["status"] = "extraction_failed"
        return False, f"Audio extraction failed: {str(e)}"


def get_audio_duration(audio_path: str) -> Optional[float]:
    """
    Get audio duration in seconds using FFprobe.

    Args:
        audio_path: Path to audio file

    Returns:
        Duration in seconds or None if failed
    """
    try:
        command = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            audio_path
        ]

        result = subprocess.run(
            command,
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            return float(result.stdout.strip())
        return None

    except Exception:
        return None


# ============================================================================
# File Cleanup
# ============================================================================

def cleanup_file(file_id: str) -> bool:
    """
    Clean up temporary files for a given file ID.

    Removes:
    - Original file from disk
    - Extracted audio (if different from original)
    - Entry from in-memory registry

    Args:
        file_id: ID of the file to clean up

    Returns:
        True if cleanup successful
    """
    file_info = get_file_info(file_id)
    if not file_info:
        return False

    try:
        # Remove original file
        if os.path.exists(file_info["file_path"]):
            os.remove(file_info["file_path"])

        # Remove extracted audio if exists and different from original
        if file_info.get("audio_path") and file_info["audio_path"] != file_info["file_path"]:
            if os.path.exists(file_info["audio_path"]):
                os.remove(file_info["audio_path"])

        # Remove from registry
        del _file_registry[file_id]
        _save_registry()

        logger.info("Cleaned up files for: %s", file_id)
        return True

    except Exception as e:
        logger.error("Cleanup failed for %s: %s", file_id, str(e))
        return False


def rehydrate_from_disk() -> int:
    """
    Rebuild registry entries for media files present on disk but missing from
    the in-memory registry (e.g. after the registry JSON was lost but the
    durable media files survived). Returns the number of entries added.

    Files are named "{file_id}.{ext}"; extracted audio is "{file_id}_audio.wav".
    original_filename is best-effort (the on-disk name) - streaming only needs
    file_path, and the frontend already has the real name from the project.
    """
    media_dir = settings.media_upload_dir
    if not os.path.isdir(media_dir):
        return 0

    added = 0
    for name in os.listdir(media_dir):
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


# Load persisted registry, then rehydrate any durable files the registry
# missed, so streaming works after a restart even if the JSON was lost.
_load_registry()
rehydrate_from_disk()
