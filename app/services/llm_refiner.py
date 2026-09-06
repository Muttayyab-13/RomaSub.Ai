"""
Claude-based Roman Urdu Refinement Layer for RomaSub.AI

Polishes m2m100 transliteration output by sending {urdu, roman} segment pairs
to Claude Haiku 4.5 and parsing back a refined Roman Urdu array. Used on both
the streaming critical path (per audio chunk in realtime.py) and the
non-streaming batch path (transliterate_segments in transliteration.py).

Refine is purely additive — every failure path falls back to the raw m2m100
output. The user always sees a result.
"""

import json
import logging
import time

from app.config import settings

logger = logging.getLogger(__name__)


_client = None
_refiner_initialized: bool = False


_SYSTEM_PROMPT = """You are a Roman Urdu transliteration polisher.

Input: a JSON array of objects with keys "urdu" (Urdu script) and "roman" \
(a draft Roman Urdu transliteration produced by an MT model).

Output: a JSON array of strings, one per input, in the same order, each \
containing the refined Roman Urdu transliteration of the corresponding "urdu" \
string.

Rules:
- Return ONLY the JSON array. No prose, no markdown fences, no keys.
- The output array length MUST equal the input array length.
- Preserve English loanwords already present in "roman" (e.g., team, film, \
hospital) - do not re-spell them.
- Use common Roman Urdu conventions (kh, gh, q, ch, sh; double-vowels for \
long vowels; "h" for aspirated consonants).
- Do NOT translate Urdu to English.
- Do NOT add Arabic diacritics or any non-ASCII characters.
- Do NOT merge or split segments."""


def _get_client():
    global _client
    if _client is None:
        import anthropic
        _client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    return _client


def init_refiner() -> None:
    """Eager-init hook for the FastAPI lifespan. Idempotent."""
    global _refiner_initialized
    if _refiner_initialized:
        return

    if not settings.enable_llm_refine:
        logger.info("Claude refiner: disabled (enable_llm_refine=False).")
        _refiner_initialized = True
        return

    if not settings.anthropic_api_key:
        logger.warning(
            "Claude refiner: enable_llm_refine=True but ANTHROPIC_API_KEY "
            "is empty - refine calls will silently fall back to m2m100."
        )
        _refiner_initialized = True
        return

    try:
        _get_client()
        logger.info(
            "Claude refiner: initialized with model=%s.",
            settings.claude_refine_model,
        )
    except Exception as e:
        logger.warning("Claude refiner: client init failed: %s", e)

    _refiner_initialized = True


def _parse_response(text: str, expected_n: int) -> list | None:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else text
        if text.endswith("```"):
            text = text.rsplit("```", 1)[0]
        text = text.strip()

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as e:
        logger.warning("Claude refiner: JSON parse failed: %s; got: %r", e, text[:200])
        return None

    if not isinstance(parsed, list):
        logger.warning("Claude refiner: response is not a list (got %s)", type(parsed).__name__)
        return None

    if len(parsed) != expected_n:
        logger.warning(
            "Claude refiner: length mismatch (expected %d, got %d)",
            expected_n, len(parsed),
        )
        return None

    for i, item in enumerate(parsed):
        if not isinstance(item, str) or not item.strip():
            logger.warning("Claude refiner: entry %d is not a non-empty string: %r", i, item)
            return None

    return parsed


def refine_segments(segments: list[dict]) -> list[dict]:
    """
    Refine segment['roman_urdu_text'] in-place using Claude Haiku 4.5.

    No-op when settings.enable_llm_refine is False, the API key is empty,
    or segments is empty. Returns segments unchanged on any failure.
    """
    if not settings.enable_llm_refine:
        logger.info(
            "Claude refiner: SKIPPED (enable_llm_refine=False) — %d segment(s) "
            "passed through unchanged. Set ENABLE_LLM_REFINE=true in .env to enable.",
            len(segments),
        )
        return segments

    if not settings.anthropic_api_key:
        logger.warning(
            "Claude refiner: SKIPPED (ANTHROPIC_API_KEY is empty) — %d segment(s) "
            "passed through unchanged.",
            len(segments),
        )
        return segments

    if not segments:
        logger.info("Claude refiner: SKIPPED (empty segments list).")
        return segments

    pairs = [
        {"urdu": s.get("urdu_text", ""), "roman": s.get("roman_urdu_text", "")}
        for s in segments
    ]

    try:
        import anthropic
    except ImportError:
        logger.warning(
            "Claude refiner: SKIPPED ('anthropic' package not installed) — "
            "%d segment(s) passed through unchanged.",
            len(segments),
        )
        return segments

    logger.info(
        "Claude refiner: CALLING %s on %d segment(s)...",
        settings.claude_refine_model, len(pairs),
    )

    t0 = time.time()
    try:
        client = _get_client()
        response = client.messages.create(
            model=settings.claude_refine_model,
            max_tokens=2048,
            system=[{
                "type": "text",
                "text": _SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }],
            messages=[{
                "role": "user",
                "content": json.dumps(pairs, ensure_ascii=False),
            }],
        )
    except anthropic.APIError as e:
        logger.warning(
            "Claude refiner: FAILED (Anthropic API error after %.2fs) — falling back "
            "to m2m100 output for %d segment(s). Error: %s",
            time.time() - t0, len(pairs), e,
        )
        return segments
    except Exception as e:
        logger.warning(
            "Claude refiner: FAILED (unexpected %s after %.2fs) — falling back "
            "to m2m100 output for %d segment(s). Error: %s",
            type(e).__name__, time.time() - t0, len(pairs), e,
        )
        return segments

    elapsed = time.time() - t0

    text = ""
    for block in response.content:
        if getattr(block, "type", None) == "text":
            text += block.text

    refined = _parse_response(text, len(pairs))
    if refined is None:
        logger.warning(
            "Claude refiner: FAILED (response parse/validation failed after %.2fs) — "
            "falling back to m2m100 output for %d segment(s).",
            elapsed, len(pairs),
        )
        return segments

    changed = sum(1 for old, new in zip([p["roman"] for p in pairs], refined) if old != new)
    usage = response.usage
    logger.info(
        "Claude refiner: SUCCESS — refined %d/%d segment(s) in %.2fs "
        "(input=%d, output=%d, cache_write=%d, cache_read=%d)",
        changed, len(pairs), elapsed,
        usage.input_tokens, usage.output_tokens,
        getattr(usage, "cache_creation_input_tokens", 0) or 0,
        getattr(usage, "cache_read_input_tokens", 0) or 0,
    )
    if changed > 0:
        for old, new in zip([p["roman"] for p in pairs], refined):
            if old != new:
                logger.info("Claude refiner: sample diff: %r -> %r", old, new)
                break
    else:
        logger.info("Claude refiner: no changes — Claude returned identical Roman Urdu.")

    for seg, new_roman in zip(segments, refined):
        seg["roman_urdu_text"] = new_roman

    return segments
