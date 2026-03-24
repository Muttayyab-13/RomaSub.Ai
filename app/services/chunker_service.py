"""
Audio Chunker Service for RomaSub.AI
Handles splitting audio into chunks for incremental Whisper processing.

Chunks are 30s with 2s overlap. Only metadata is pre-computed;
actual audio extraction happens one chunk at a time via FFmpeg.
"""

import os
import subprocess
from typing import List, Dict
import logging

from app.config import settings

logger = logging.getLogger(__name__)

# ============================================================================
# Constants
# ============================================================================

CHUNK_DURATION = 30.0    # seconds per chunk
OVERLAP_DURATION = 2.0   # seconds of overlap between consecutive chunks
STEP_SIZE = CHUNK_DURATION - OVERLAP_DURATION  # 28s advance per chunk


# ============================================================================
# Chunk Plan Computation
# ============================================================================

def compute_chunk_plan(total_duration: float) -> List[Dict]:
    """
    Pre-compute all chunk metadata for a given audio duration.

    Each chunk covers [start, start + CHUNK_DURATION).
    Chunks advance by STEP_SIZE (28s), creating a 2s overlap.
    For a 1-hour file: ~129 chunks.

    Args:
        total_duration: Total audio duration in seconds

    Returns:
        List of chunk metadata dicts: [{index, start, end}, ...]
    """
    if total_duration <= 0:
        return []

    chunks = []
    start = 0.0
    index = 0

    while start < total_duration:
        end = min(start + CHUNK_DURATION, total_duration)
        chunks.append({
            "index": index,
            "start": start,
            "end": end,
        })
        start += STEP_SIZE
        index += 1

        # Avoid tiny trailing chunks (< 1s)
        if total_duration - start < 1.0 and start < total_duration:
            # Extend the last chunk to cover remaining
            chunks[-1]["end"] = total_duration
            break

    logger.info(
        "Chunk plan: %d chunks for %.1fs audio (%.0fs chunks, %.0fs overlap)",
        len(chunks), total_duration, CHUNK_DURATION, OVERLAP_DURATION,
    )
    return chunks


# ============================================================================
# Chunk Audio Extraction
# ============================================================================

def extract_chunk_audio(audio_path: str, chunk: Dict, output_dir: str) -> str:
    """
    Extract a single chunk's audio to a temp WAV file using FFmpeg.

    Args:
        audio_path: Path to the full extracted audio file
        chunk: Chunk metadata dict with 'index', 'start', 'end'
        output_dir: Directory for temp chunk files

    Returns:
        Path to the chunk WAV file
    """
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(
        output_dir,
        f"chunk_{chunk['index']}_{os.path.basename(audio_path)}"
    )

    command = [
        "ffmpeg",
        "-i", audio_path,
        "-ss", str(chunk["start"]),
        "-to", str(chunk["end"]),
        "-acodec", "pcm_s16le",
        "-ar", "16000",
        "-ac", "1",
        "-y",
        output_path,
    ]

    result = subprocess.run(command, capture_output=True, text=True)

    if result.returncode != 0:
        logger.error("FFmpeg chunk extraction failed: %s", result.stderr)
        raise RuntimeError(f"Failed to extract chunk {chunk['index']}: {result.stderr}")

    logger.info(
        "Extracted chunk %d: %.1fs-%.1fs -> %s",
        chunk["index"], chunk["start"], chunk["end"], output_path,
    )
    return output_path


# ============================================================================
# Timestamp Offset & Overlap Trimming
# ============================================================================

def offset_segments(segments: List[Dict], chunk_start: float) -> List[Dict]:
    """
    Add chunk_start offset to each segment's start/end timestamps.
    Whisper returns timestamps relative to chunk start (0-based);
    this converts them to absolute positions in the original audio.

    Args:
        segments: List of segment dicts with 'start', 'end', 'text'
        chunk_start: Start time of this chunk in the original audio

    Returns:
        Segments with offset timestamps
    """
    for seg in segments:
        seg["start"] = round(seg["start"] + chunk_start, 3)
        seg["end"] = round(seg["end"] + chunk_start, 3)
    return segments


def trim_overlap_segments(
    segments: List[Dict],
    chunk_start: float,
    overlap: float = OVERLAP_DURATION,
) -> List[Dict]:
    """
    For non-first chunks: discard segments that fall within the overlap region.

    The overlap region is [chunk_start, chunk_start + overlap). Segments from
    the EARLIER chunk are authoritative for this region. We discard any segment
    from the later chunk whose start time falls within the overlap window.

    This is more reliable than timestamp-based deduplication because Whisper
    is non-deterministic at boundaries.

    Args:
        segments: Segments with already-offset timestamps
        chunk_start: Start time of this chunk
        overlap: Overlap duration in seconds

    Returns:
        Filtered segments
    """
    cutoff = chunk_start + overlap
    return [seg for seg in segments if seg["start"] >= cutoff]


def cleanup_chunk_file(chunk_path: str) -> None:
    """Remove a temporary chunk audio file."""
    try:
        if os.path.exists(chunk_path):
            os.remove(chunk_path)
    except OSError as e:
        logger.warning("Failed to cleanup chunk file %s: %s", chunk_path, e)
