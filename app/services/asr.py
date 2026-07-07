"""
ASR Service for RomaSub.AI
Handles speech recognition using OpenAI Whisper

Pure functions for ASR operations with in-memory result storage.
"""

import os
import subprocess
import tempfile
from typing import Optional, Dict, List, Tuple
from datetime import datetime
from sqlalchemy.orm import Session
import json

from app.config import settings
from app.services import media as media_service  # also runs static_ffmpeg.add_paths()
import logging

logger = logging.getLogger(__name__)


# ============================================================================
# Module-level state for Whisper model and results
# ============================================================================

# Loaded local model handles (lazy). openai-whisper and faster-whisper are
# separate implementations, so they get separate globals.
_whisper_model = None          # openai-whisper
_faster_whisper_model = None   # faster-whisper (CTranslate2)
_groq_client = None            # Groq SDK client

# Stay safely under Groq's 25 MB free-tier upload limit; larger inputs get
# transcoded to 16 kHz mono FLAC before upload.
GROQ_MAX_UPLOAD_BYTES = 24 * 1024 * 1024

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

    Dispatches to the backend selected by `settings.whisper_backend`:
      * "groq"   — Groq-hosted Whisper. On any failure (offline, no key/credits,
                   file too large) it falls back to local faster-whisper so a
                   transcription is always produced.
      * "faster" — local faster-whisper.
      * "openai" — local openai-whisper.

    Args:
        audio_path: Path to audio file
        language: Language code (default: 'ur')

    Returns:
        Dict with 'text' and 'segments' keys
    """
    backend = (settings.effective_whisper_backend or "faster").lower()

    if backend == "groq":
        if settings.groq_api_key:
            try:
                return _transcribe_groq(audio_path, language)
            except Exception as e:
                logger.warning(
                    "[ASR] Groq transcription failed (%s); falling back to local faster-whisper", e
                )
        else:
            logger.warning(
                "[ASR] whisper_backend='groq' but GROQ_API_KEY is empty; using local faster-whisper"
            )
        return _transcribe_faster_whisper(audio_path, language)

    if backend == "openai":
        return _transcribe_openai_whisper(audio_path, language)

    # Default local backend.
    return _transcribe_faster_whisper(audio_path, language)


# ----------------------------------------------------------------------------
# Backend: Groq-hosted Whisper (OpenAI-compatible Audio API)
# ----------------------------------------------------------------------------

def _get_groq_client():
    """Lazily construct and cache the Groq SDK client."""
    global _groq_client
    if _groq_client is None:
        from groq import Groq
        _groq_client = Groq(api_key=settings.groq_api_key)
    return _groq_client


def _seg_value(seg, key, default):
    """Read a field from a response segment that may be an object or a dict."""
    if isinstance(seg, dict):
        return seg.get(key, default)
    return getattr(seg, key, default)


def _groq_response_to_result(resp) -> Dict:
    """
    Map a Groq verbose_json transcription response to the internal
    {"text", "segments":[{id,start,end,text}]} shape used downstream.
    Accepts either SDK objects (attribute access) or plain dicts.
    """
    text = _seg_value(resp, "text", "") or ""
    raw_segments = _seg_value(resp, "segments", []) or []

    segments = []
    for i, seg in enumerate(raw_segments):
        segments.append({
            "id": _seg_value(seg, "id", i),
            "start": float(_seg_value(seg, "start", 0.0) or 0.0),
            "end": float(_seg_value(seg, "end", 0.0) or 0.0),
            "text": (_seg_value(seg, "text", "") or "").strip(),
        })

    return {"text": text, "segments": segments}


def _compress_for_groq(audio_path: str) -> str:
    """
    Transcode audio to 16 kHz mono FLAC so large inputs stay under Groq's
    upload limit. Whisper resamples to 16 kHz mono internally, so this is
    lossless w.r.t. transcription quality. Returns a temp file path the
    caller must delete.
    """
    fd, out_path = tempfile.mkstemp(suffix=".flac", prefix="groq_asr_")
    os.close(fd)

    command = [
        "ffmpeg", "-i", audio_path,
        "-vn", "-ar", "16000", "-ac", "1",
        "-c:a", "flac",
        "-y", out_path,
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        try:
            os.remove(out_path)
        except OSError:
            pass
        raise RuntimeError(f"ffmpeg compression for Groq failed: {result.stderr}")

    return out_path


def _transcribe_groq(audio_path: str, language: str = "ur") -> Dict:
    """Transcribe via Groq-hosted Whisper, compressing first only if needed."""
    upload_path = audio_path
    tmp_path = None
    if os.path.getsize(audio_path) > GROQ_MAX_UPLOAD_BYTES:
        tmp_path = _compress_for_groq(audio_path)
        upload_path = tmp_path

    try:
        client = _get_groq_client()
        with open(upload_path, "rb") as f:
            resp = client.audio.transcriptions.create(
                file=(os.path.basename(upload_path), f.read()),
                model=settings.groq_model,
                language=language,
                response_format="verbose_json",
                temperature=0.0,
            )
        return _groq_response_to_result(resp)
    finally:
        if tmp_path:
            try:
                os.remove(tmp_path)
            except OSError:
                pass


# ----------------------------------------------------------------------------
# Backend: local faster-whisper (CTranslate2, int8) — offline, low RAM
# ----------------------------------------------------------------------------

def _get_faster_whisper_model():
    """Lazily load and cache the faster-whisper model."""
    global _faster_whisper_model
    if _faster_whisper_model is None:
        print(f"\n[ASR] Loading faster-whisper model: {settings.whisper_model} "
              f"(compute_type={settings.whisper_compute_type})")
        from faster_whisper import WhisperModel
        _faster_whisper_model = WhisperModel(
            settings.whisper_model,
            device="cpu",
            compute_type=settings.whisper_compute_type,
        )
        print("[ASR] faster-whisper model loaded successfully!")
    return _faster_whisper_model


def _transcribe_faster_whisper(audio_path: str, language: str = "ur") -> Dict:
    model = _get_faster_whisper_model()

    segment_iter, _info = model.transcribe(
        audio_path,
        language=language,
        task="transcribe",
        vad_filter=True,  # skip silence — big speedup on real speech
        condition_on_previous_text=False,
        no_speech_threshold=0.5,
        compression_ratio_threshold=2.4,
    )

    segments = []
    parts = []
    for i, seg in enumerate(segment_iter):
        text = seg.text.strip()
        segments.append({
            "id": i,
            "start": seg.start,
            "end": seg.end,
            "text": text,
        })
        parts.append(text)

    return {"text": " ".join(parts), "segments": segments}


# ----------------------------------------------------------------------------
# Backend: local openai-whisper (original implementation)
# ----------------------------------------------------------------------------

def _transcribe_openai_whisper(audio_path: str, language: str = "ur") -> Dict:
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
        # Model loading is handled lazily per-backend inside transcribe_chunk,
        # so we don't eagerly load a local model here (would waste RAM when the
        # Groq backend is active).

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

        # Create result object — stash original_filename so it survives the
        # auto-cleanup step that wipes file_info from the registry.
        transcription_result = {
            "file_id": file_id,
            "original_filename": file_info.get("original_filename"),
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

        # Auto-create a subtitle project so it shows up in Recent Projects
        # even if the user never opens the editor. Idempotent: returns the
        # existing project if create_project has already been called for this
        # file_id (e.g. when the editor is opened later).
        try:
            from app.services import subtitle as subtitle_service
            subtitle_service.create_project(
                file_id=file_id,
                original_filename=file_info.get("original_filename") or f"file_{file_id}",
                duration=duration,
            )
        except Exception as e:
            logger.warning("Auto-create subtitle project failed: %s", e)

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
