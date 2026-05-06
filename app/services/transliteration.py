"""
Transliteration Service for RomaSub.AI
Handles Urdu to Roman Urdu transliteration using fine-tuned M2M100 model.

Pure functions for transliteration operations with in-memory result storage.
"""

import os
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import logging

from app.config import settings
from app.services.asr import get_transcription_result, seconds_to_srt_time

logger = logging.getLogger(__name__)


# ============================================================================
# Module-level state for M2M100 model and results
# ============================================================================

_m2m100_model = None
_m2m100_tokenizer = None
_device = None

# In-memory storage for transliteration results (temporary)
_transliteration_results: Dict[str, Dict] = {}

# Roman Urdu forced BOS token ID (from tokenizer config)
ROMAN_UR_TOKEN_ID = 128105


# ============================================================================
# M2M100 Model Management
# ============================================================================

def get_m2m100_model_and_tokenizer():
    """
    Load M2M100 model and tokenizer (lazy loading).
    Model is loaded once and reused for all transliterations.

    Returns:
        Tuple of (model, tokenizer, device)
    """
    global _m2m100_model, _m2m100_tokenizer, _device

    if _m2m100_model is None:
        print(f"\n[TRANSLITERATION] Loading M2M100 model from: {settings.m2m100_model_path}")
        print("[TRANSLITERATION] This may take a moment on first run...")

        import torch
        from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer

        # Determine device
        if settings.transliteration_device == "auto":
            _device = "cuda" if torch.cuda.is_available() else "cpu"
        else:
            _device = settings.transliteration_device

        print(f"[TRANSLITERATION] Using device: {_device}")

        # Load tokenizer
        _m2m100_tokenizer = M2M100Tokenizer.from_pretrained(
            settings.m2m100_tokenizer_path
        )

        # Load model
        _m2m100_model = M2M100ForConditionalGeneration.from_pretrained(
            settings.m2m100_model_path
        )
        _m2m100_model.to(_device)
        _m2m100_model.eval()

        print(f"[TRANSLITERATION] M2M100 model loaded successfully!")

    return _m2m100_model, _m2m100_tokenizer, _device


# ============================================================================
# Transliteration Functions
# ============================================================================

def transliterate_text(urdu_text: str) -> str:
    """
    Transliterate a single Urdu text string to Roman Urdu.

    Args:
        urdu_text: Urdu text string to transliterate

    Returns:
        Roman Urdu transliterated text
    """
    results = transliterate_batch([urdu_text])
    return results[0]


def _m2m100_batch(texts: List[str], batch_size: int = 8) -> List[str]:
    """
    Raw M2M100 batch inference (no loanword processing).
    Takes Urdu texts and returns Roman Urdu texts.
    """
    if not texts:
        return []

    import torch

    model, tokenizer, device = get_m2m100_model_and_tokenizer()
    tokenizer.src_lang = "ur"

    all_results = []

    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]

        inputs = tokenizer(
            batch_texts,
            return_tensors="pt",
            max_length=128,
            truncation=True,
            padding=True,
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            generated = model.generate(
                **inputs,
                forced_bos_token_id=ROMAN_UR_TOKEN_ID,
                max_length=200,
                num_beams=4,
                early_stopping=True,
            )

        decoded = tokenizer.batch_decode(generated, skip_special_tokens=True)
        all_results.extend(decoded)

        print(f"[TRANSLITERATION] Batch {i // batch_size + 1}/{(len(texts) + batch_size - 1) // batch_size} done")

    return all_results


def transliterate_batch(texts: List[str], batch_size: int = 8) -> List[str]:
    """
    Transliterate a list of Urdu texts to Roman Urdu in batches.

    Path depends on `settings.enable_loanword_dict`:
      * True  — full pipeline: loanword/names dict substitution → urduhack
                normalization → M2M100 → reconstruction → fuzzy post-process.
      * False — bypass the dictionary layer entirely. Just urduhack normalize
                each text, then run M2M100. Use this when the dict content is
                unverified (see scripts/audit_loanword_dict.py).

    Args:
        texts: List of Urdu text strings
        batch_size: Number of texts to process at once (default: 8)

    Returns:
        List of Roman Urdu transliterated texts
    """
    from app.services.urdu_preprocessor import preprocess_urdu_chunks

    if not settings.enable_loanword_dict:
        # Direct path: normalize then run the model. No dict, no reconstruction,
        # no fuzzy post-processing. Equivalent to scripts/eval_m2m100.py's
        # raw mode plus urduhack normalization.
        normalized = preprocess_urdu_chunks(texts)
        return _m2m100_batch(normalized, batch_size)

    from app.services.loanword_processor import process_batch

    def m2m100_fn(urdu_chunks: List[str]) -> List[str]:
        normalized = preprocess_urdu_chunks(urdu_chunks)
        return _m2m100_batch(normalized, batch_size)

    return process_batch(texts, m2m100_fn)


def transliterate_segments(segments: List[Dict]) -> List[Dict]:
    """
    Transliterate all segments from ASR output using batched inference.

    Args:
        segments: List of ASR segment dicts with id, start, end, text

    Returns:
        List of transliterated segment dicts with urdu_text and roman_urdu_text
    """
    texts = [seg["text"] for seg in segments]
    roman_texts = transliterate_batch(texts)

    transliterated = []
    for segment, roman_urdu in zip(segments, roman_texts):
        transliterated.append({
            "id": segment["id"],
            "start": segment["start"],
            "end": segment["end"],
            "urdu_text": segment["text"],
            "roman_urdu_text": roman_urdu,
        })

    try:
        from app.services.llm_refiner import refine_segments
        refine_segments(transliterated)
    except Exception as e:
        logger.warning(f"LLM refine failed, returning raw m2m100 output: {e}")

    return transliterated


def transliterate_transcription(file_id: str) -> Tuple[bool, str, Dict]:
    """
    Transliterate all segments from an existing ASR transcription result.

    Args:
        file_id: ID of the transcribed file

    Returns:
        Tuple of (success, message, result_dict)
    """
    # Get existing transcription
    transcription = get_transcription_result(file_id)

    if not transcription:
        return False, "Transcription not found. Please transcribe the file first.", {}

    segments = transcription.get("segments", [])
    if not segments:
        return False, "No segments found in transcription.", {}

    print(f"\n{'='*60}")
    print(f"[TRANSLITERATION] Starting transliteration for file: {file_id}")
    print(f"[TRANSLITERATION] Segments to process: {len(segments)}")
    print(f"{'='*60}")

    try:
        start_time = datetime.now()

        # Transliterate all segments
        transliterated_segments = transliterate_segments(segments)

        # Build full text from transliterated segments
        roman_urdu_full_text = " ".join(
            seg["roman_urdu_text"] for seg in transliterated_segments
        )

        end_time = datetime.now()
        processing_time = (end_time - start_time).total_seconds()

        # Create result
        result = {
            "file_id": file_id,
            "urdu_text": transcription["text"],
            "roman_urdu_text": roman_urdu_full_text,
            "segments": transliterated_segments,
            "segment_count": len(transliterated_segments),
            "processing_time_seconds": processing_time,
            "transliterated_at": datetime.now().isoformat(),
            "status": "completed"
        }

        # Store in memory
        _transliteration_results[file_id] = result

        # Print results
        print(f"\n{'='*60}")
        print("[TRANSLITERATION] TRANSLITERATION COMPLETE")
        print(f"{'='*60}")
        print(f"Processing time: {processing_time:.2f} seconds")
        print(f"Segments processed: {len(transliterated_segments)}")
        print(f"\n--- Sample Output (first 5 segments) ---")
        for seg in transliterated_segments[:5]:
            print(f"[{seg['start']:.2f}s - {seg['end']:.2f}s]:")
            print(f"  Urdu: {seg['urdu_text']}")
            print(f"  Roman: {seg['roman_urdu_text']}")
        if len(transliterated_segments) > 5:
            print(f"... and {len(transliterated_segments) - 5} more segments")
        print(f"{'='*60}\n")

        logger.info("Transliteration completed for file: %s", file_id)
        return True, "Transliteration completed", result

    except Exception as e:
        error_msg = f"Transliteration failed: {str(e)}"
        logger.error(error_msg)
        print(f"[TRANSLITERATION ERROR] {error_msg}")
        return False, error_msg, {}


def get_transliteration_result(file_id: str) -> Optional[Dict]:
    """
    Get transliteration result by file ID from in-memory storage.

    Args:
        file_id: Unique file identifier

    Returns:
        Transliteration result dictionary or None if not found
    """
    return _transliteration_results.get(file_id)


# ============================================================================
# SRT Format Functions (Roman Urdu)
# ============================================================================

def format_roman_urdu_srt(segments: List[Dict]) -> str:
    """
    Format transliterated segments as SRT subtitle format with Roman Urdu text.

    Args:
        segments: List of transliterated segment dicts with roman_urdu_text

    Returns:
        SRT formatted string
    """
    srt_lines = []

    for i, segment in enumerate(segments, 1):
        start = seconds_to_srt_time(segment["start"])
        end = seconds_to_srt_time(segment["end"])
        text = segment["roman_urdu_text"]

        srt_lines.append(f"{i}")
        srt_lines.append(f"{start} --> {end}")
        srt_lines.append(text)
        srt_lines.append("")

    return "\n".join(srt_lines)
