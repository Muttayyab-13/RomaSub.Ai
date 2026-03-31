"""
ASR Service for RomaSub.AI
Handles speech recognition using OpenAI Whisper

Pure functions for ASR operations with in-memory result storage.
"""

import os
from typing import Optional, Dict, List, Tuple
from datetime import datetime
from sqlalchemy.orm import Session
import json

from app.config import settings
from app.services import media as media_service
import logging

logger = logging.getLogger(__name__)


# ============================================================================
# Module-level state for Whisper model and results
# ============================================================================

# Global variable to hold loaded Whisper model
_whisper_model = None

# In-memory storage for transcription results (temporary)
_transcription_results: Dict[str, Dict] = {}


# ============================================================================
# Whisper Model Management
# ============================================================================

def get_whisper_model():
    """
    Load Whisper model (lazy loading).
    Model is loaded once and reused for all transcriptions.

    Returns:
        Loaded Whisper model instance
    """
    global _whisper_model

    if _whisper_model is None:
        print(f"\n[ASR] Loading Whisper model: {settings.whisper_model}")
        print("[ASR] This may take a moment on first run...")

        import torch
        import whisper
        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"[ASR] Using device: {device}")
        _whisper_model = whisper.load_model(settings.whisper_model, device=device)

        print(f"[ASR] Whisper model loaded successfully!")

    return _whisper_model


def transcribe_chunk(audio_path: str, language: str = "ur") -> Dict:
    """
    Transcribe an audio file/chunk and return segments.
    Used by both full-file transcription and realtime chunked processing.

    Args:
        audio_path: Path to audio file
        language: Language code (default: 'ur')

    Returns:
        Dict with 'text' and 'segments' keys
    """
    model = get_whisper_model()

    result = model.transcribe(
        audio_path,
        language=language,
        task="transcribe",
        verbose=False,
        word_timestamps=True,
        condition_on_previous_text=False,
        no_speech_threshold=0.5,
        compression_ratio_threshold=2.4,
    )

    segments = []
    for seg in result.get("segments", []):
        segments.append({
            "id": seg["id"],
            "start": seg["start"],
            "end": seg["end"],
            "text": seg["text"].strip(),
        })

    return {"text": result["text"], "segments": segments}


# ============================================================================
# Transcription Functions
# ============================================================================

def transcribe_audio(file_id: str, language: str = "ur", auto_cleanup: bool = True) -> Tuple[bool, str, Dict]:
    """
    Transcribe audio file using Whisper.

    Args:
        file_id: ID of the uploaded file
        language: Language code (default: 'ur' for Urdu)
        auto_cleanup: If True, delete files after transcription (default: True)

    Returns:
        Tuple of (success, message, result_dict)
    """
    # Get file info
    file_info = media_service.get_file_info(file_id)

    if not file_info:
        return False, "File not found", {}

    # Extract audio if needed
    success, audio_path = media_service.extract_audio(file_id)

    if not success:
        return False, f"Audio extraction failed: {audio_path}", {}

    print(f"\n{'='*60}")
    print(f"[ASR] Starting transcription for file: {file_id}")
    print(f"[ASR] Audio path: {audio_path}")
    print(f"[ASR] Language: {language}")
    print(f"{'='*60}")

    try:
        # Ensure model is loaded
        get_whisper_model()

        # Get audio duration
        duration = media_service.get_audio_duration(audio_path)
        if duration:
            print(f"[ASR] Audio duration: {duration:.2f} seconds")

        # Transcribe
        print("[ASR] Transcribing... (this may take a while)")
        start_time = datetime.now()

        result = transcribe_chunk(audio_path, language=language)

        end_time = datetime.now()
        processing_time = (end_time - start_time).total_seconds()

        segments = result["segments"]
        full_text = result["text"]

        # Create result object
        transcription_result = {
            "file_id": file_id,
            "language": language,
            "text": full_text,
            "segments": segments,
            "segment_count": len(segments),
            "processing_time_seconds": processing_time,
            "audio_duration_seconds": duration,
            "transcribed_at": datetime.now().isoformat(),
            "status": "completed"
        }

        # Store result in memory
        _transcription_results[file_id] = transcription_result

        # Auto-transliterate to Roman Urdu
        try:
            from app.services import transliteration as transliteration_service
            print("[ASR] Auto-transliterating to Roman Urdu...")
            success_t, msg_t, result_t = transliteration_service.transliterate_transcription(file_id)
            if success_t:
                transcription_result["roman_urdu_text"] = result_t["roman_urdu_text"]
                transcription_result["roman_urdu_segments"] = result_t["segments"]
                print("[ASR] Auto-transliteration complete!")
            else:
                print(f"[ASR] Auto-transliteration failed: {msg_t}")
                transcription_result["roman_urdu_text"] = None
                transcription_result["roman_urdu_segments"] = None
        except Exception as e:
            logger.warning("Auto-transliteration failed: %s", str(e))
            transcription_result["roman_urdu_text"] = None
            transcription_result["roman_urdu_segments"] = None

        # Print results to console
        print(f"\n{'='*60}")
        print("[ASR] TRANSCRIPTION COMPLETE")
        print(f"{'='*60}")
        print(f"Processing time: {processing_time:.2f} seconds")
        print(f"Segments found: {len(segments)}")
        print(f"\n--- Full Transcription ---")
        print(full_text)
        print(f"\n--- Segments with Timestamps ---")
        for seg in segments[:10]:  # Show first 10 segments
            print(f"[{seg['start']:.2f}s - {seg['end']:.2f}s]: {seg['text']}")
        if len(segments) > 10:
            print(f"... and {len(segments) - 10} more segments")
        print(f"{'='*60}\n")

        logger.info("Transcription completed for file: %s", file_id)

        # Auto-cleanup: Delete temporary files after transcription
        if auto_cleanup:
            print(f"[CLEANUP] Auto-deleting temporary files for: {file_id}")
            cleanup_success = media_service.cleanup_file(file_id)
            if cleanup_success:
                logger.info("Cleaned up temporary files for: %s", file_id)
                print(f"[CLEANUP] Files deleted successfully")
            else:
                logger.warning("Failed to cleanup files for: %s", file_id)
                print(f"[CLEANUP] Warning: Failed to delete some files")

        return True, "Transcription completed", transcription_result

    except Exception as e:
        error_msg = f"Transcription failed: {str(e)}"
        logger.error(error_msg)
        print(f"[ASR ERROR] {error_msg}")

        # Cleanup files even on error
        if auto_cleanup:
            print(f"[CLEANUP] Cleaning up files after error...")
            media_service.cleanup_file(file_id)

        return False, error_msg, {}


def get_transcription_result(file_id: str) -> Optional[Dict]:
    """
    Get transcription result by file ID from in-memory storage.

    Args:
        file_id: Unique file identifier

    Returns:
        Transcription result dictionary or None if not found
    """
    return _transcription_results.get(file_id)


# ============================================================================
# SRT Format Functions
# ============================================================================

def format_as_srt(segments: List[Dict]) -> str:
    """
    Format segments as SRT subtitle format.

    Args:
        segments: List of segment dictionaries with start, end, text keys

    Returns:
        SRT formatted string
    """
    srt_lines = []

    for i, segment in enumerate(segments, 1):
        start = seconds_to_srt_time(segment["start"])
        end = seconds_to_srt_time(segment["end"])
        text = segment["text"]

        srt_lines.append(f"{i}")
        srt_lines.append(f"{start} --> {end}")
        srt_lines.append(text)
        srt_lines.append("")

    return "\n".join(srt_lines)


def seconds_to_srt_time(seconds: float) -> str:
    """
    Convert seconds to SRT time format (HH:MM:SS,mmm).

    Args:
        seconds: Time in seconds

    Returns:
        SRT formatted time string
    """
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)

    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"
