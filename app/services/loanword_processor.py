"""
Loanword Processor for RomaSub.AI
Handles English loanwords and Pakistani names in Urdu text before/after
M2M100 transliteration.

Strategy: Detect English loanwords and names written in Urdu script, bypass
the model for those words, and stitch the results back in at the correct
positions. Supports multi-word matching (bigrams/trigrams).
"""

import json
import os
import re
import logging
from typing import Dict, List, Tuple, Optional

logger = logging.getLogger(__name__)

# ============================================================================
# Module-level state
# ============================================================================

_loanword_dict: Optional[Dict[str, str]] = None
_names_dict: Optional[Dict[str, str]] = None
_combined_dict: Optional[Dict[str, str]] = None
_multiword_dict: Optional[Dict[str, str]] = None  # entries with 2+ words
_max_ngram: int = 1
_english_vocab: Optional[set] = None

# Common Urdu suffixes attached to English loanwords
_URDU_SUFFIXES = [
    "وں",   # plural (logon → logo + wn)
    "یں",   # plural feminine
    "ات",   # plural formal
    "ز",    # plural (English-style)
    "ے",    # oblique
    "ی",    # feminine / adjective
    "نے",   # ergative case
    "کو",   # accusative/dative
    "سے",   # ablative
    "میں",  # locative
    "پر",   # locative
    "کا",   # possessive masc
    "کی",   # possessive fem
    "کے",   # possessive plural
]

# Suffix to English suffix mapping (for reconstruction)
_SUFFIX_TO_ENGLISH = {
    "وں": "s",
    "یں": "s",
    "ات": "s",
    "ز": "s",
    "ے": "",
    "ی": "",
}


# ============================================================================
# Dictionary Loading
# ============================================================================

def _load_json_dict(filename: str) -> Dict[str, str]:
    """Load a JSON dictionary from app/data/."""
    dict_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)),
        "data", filename
    )
    with open(dict_path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def get_loanword_dict() -> Dict[str, str]:
    """Load the loanword dictionary (lazy, singleton)."""
    global _loanword_dict
    if _loanword_dict is None:
        _loanword_dict = _load_json_dict("loanword_dict.json")
        logger.info("Loaded %d loanword entries", len(_loanword_dict))
    return _loanword_dict


def get_names_dict() -> Dict[str, str]:
    """Load the Pakistani names dictionary (lazy, singleton)."""
    global _names_dict
    if _names_dict is None:
        _names_dict = _load_json_dict("names_dict.json")
        logger.info("Loaded %d name entries", len(_names_dict))
    return _names_dict


def get_combined_dict() -> Dict[str, str]:
    """Get merged loanword + names dictionary."""
    global _combined_dict, _multiword_dict, _max_ngram
    if _combined_dict is None:
        _combined_dict = {}
        _multiword_dict = {}

        # Names first (lower priority), then loanwords (higher priority overrides)
        _combined_dict.update(get_names_dict())
        _combined_dict.update(get_loanword_dict())

        # Separate multi-word entries and compute max n-gram size
        for key, val in _combined_dict.items():
            n = len(key.split())
            if n > 1:
                _multiword_dict[key] = val
            if n > _max_ngram:
                _max_ngram = n

        logger.info(
            "Combined dict: %d entries (%d multi-word, max %d-gram)",
            len(_combined_dict), len(_multiword_dict), _max_ngram
        )
    return _combined_dict


def get_english_vocab() -> set:
    """Get a set of common English words for post-processing fuzzy matching."""
    global _english_vocab
    if _english_vocab is None:
        combined = get_combined_dict()
        _english_vocab = set(v.lower() for v in combined.values())
        _english_vocab.update({
            "the", "is", "are", "was", "were", "have", "has", "had",
            "very", "much", "also", "just", "only", "but", "and", "or",
            "yes", "no", "ok", "okay", "sorry", "please", "thank",
            "good", "bad", "nice", "great", "best", "worst",
            "new", "old", "big", "small", "fast", "slow",
            "right", "wrong", "sure", "clear", "simple",
        })
    return _english_vocab


# ============================================================================
# Pre-Processing: Detect and Extract Loanwords + Names (with n-gram matching)
# ============================================================================

def _lookup_single(word: str) -> Optional[str]:
    """
    Look up a single word in the combined dictionary.
    Tries exact match first, then strips Urdu suffixes.
    """
    d = get_combined_dict()

    if word in d:
        return d[word]

    # Try stripping suffixes
    for suffix in _URDU_SUFFIXES:
        if word.endswith(suffix) and len(word) > len(suffix) + 1:
            stem = word[:-len(suffix)]
            if stem in d:
                english = d[stem]
                eng_suffix = _SUFFIX_TO_ENGLISH.get(suffix, "")
                if eng_suffix and not english.endswith("s"):
                    return english + eng_suffix
                return english

    return None


def preprocess(urdu_text: str) -> Tuple[List[Tuple[str, Optional[str]]], List[str]]:
    """
    Split Urdu text into tokens. Detect English loanwords and names,
    including multi-word entries (bigrams, trigrams).

    Uses greedy longest-match: tries trigram first, then bigram, then unigram.

    Returns:
        tokens: [(urdu_word_or_phrase, english_or_None), ...] — positional map
        urdu_chunks: Urdu-only text segments to send through M2M100
    """
    d = get_combined_dict()
    words = urdu_text.split()
    n = len(words)
    tokens = []
    i = 0

    while i < n:
        matched = False

        # Try longest n-gram first (greedy)
        for gram_size in range(min(_max_ngram, n - i), 1, -1):
            phrase = " ".join(words[i:i + gram_size])
            if phrase in d:
                tokens.append((phrase, d[phrase]))
                i += gram_size
                matched = True
                break

        if not matched:
            # Try single word (with suffix stripping)
            english = _lookup_single(words[i])
            tokens.append((words[i], english))
            i += 1

    # Build Urdu-only chunks (consecutive Urdu words grouped together)
    urdu_chunks = []
    current_chunk = []

    for word, english in tokens:
        if english is None:
            current_chunk.append(word)
        else:
            if current_chunk:
                urdu_chunks.append(" ".join(current_chunk))
                current_chunk = []

    if current_chunk:
        urdu_chunks.append(" ".join(current_chunk))

    return tokens, urdu_chunks


# ============================================================================
# Reconstruction: Merge Transliterated Urdu with English Words
# ============================================================================

def reconstruct(tokens: List[Tuple[str, Optional[str]]],
                transliterated_chunks: List[str]) -> str:
    """
    Merge transliterated Urdu chunks with English loanwords
    at their original positions.

    Args:
        tokens: [(urdu_word, english_or_None), ...] from preprocess()
        transliterated_chunks: M2M100 output for Urdu-only chunks

    Returns:
        Merged Roman Urdu text with English loanwords preserved
    """
    result_words = []
    chunk_idx = 0
    chunk_word_buffer = []

    for word, english in tokens:
        if english is not None:
            # Flush any pending transliterated words
            if not chunk_word_buffer and chunk_idx < len(transliterated_chunks):
                # Split the next chunk into words for word-by-word consumption
                chunk_text = transliterated_chunks[chunk_idx].strip()
                if chunk_text:
                    chunk_word_buffer = chunk_text.split()
                chunk_idx += 1

            # Insert English word
            result_words.append(english)
        else:
            # Consume from transliterated chunk
            if not chunk_word_buffer:
                if chunk_idx < len(transliterated_chunks):
                    chunk_text = transliterated_chunks[chunk_idx].strip()
                    if chunk_text:
                        chunk_word_buffer = chunk_text.split()
                    chunk_idx += 1

            if chunk_word_buffer:
                result_words.append(chunk_word_buffer.pop(0))
            # If buffer is empty (model produced fewer words), skip

    # Append any remaining words from the last chunk
    result_words.extend(chunk_word_buffer)

    return " ".join(result_words)


# ============================================================================
# Post-Processing: Fix Remaining Mangled English Words
# ============================================================================

_VOWELS = set("aeiouAEIOU")


def _is_mangled_english(word: str) -> bool:
    """
    Heuristic: detect if a Roman Urdu word looks like mangled English.

    A word is suspicious if:
    - Length >= 4 and vowel ratio < 0.2
    - Has 3+ consecutive consonants
    """
    if len(word) < 4:
        return False

    # Vowel ratio check
    vowel_count = sum(1 for c in word if c in _VOWELS)
    if len(word) > 0 and vowel_count / len(word) < 0.15:
        return True

    # Consecutive consonants check
    consec = 0
    for c in word.lower():
        if c.isalpha() and c not in _VOWELS:
            consec += 1
            if consec >= 4:
                return True
        else:
            consec = 0

    return False


def postprocess(roman_urdu_text: str) -> str:
    """
    Scan transliteration output for mangled English words.
    If detected and a high-confidence match exists, replace.
    """
    try:
        from rapidfuzz import fuzz, process
    except ImportError:
        # rapidfuzz not installed, skip post-processing
        return roman_urdu_text

    vocab = get_english_vocab()
    words = roman_urdu_text.split()
    result = []

    for word in words:
        if _is_mangled_english(word):
            # Try fuzzy match against English vocab
            match = process.extractOne(
                word.lower(),
                vocab,
                scorer=fuzz.ratio,
                score_cutoff=75,
            )
            if match:
                matched_word, score, _ = match
                # Only replace if high confidence
                if score >= 80:
                    result.append(matched_word)
                    logger.debug("Fuzzy fix: '%s' → '%s' (score=%d)", word, matched_word, score)
                    continue

        result.append(word)

    return " ".join(result)


# ============================================================================
# Full Pipeline Entry Point
# ============================================================================

def process_text(urdu_text: str, transliterate_fn) -> str:
    """
    Full loanword-aware transliteration pipeline for a single text.

    Args:
        urdu_text: Urdu text (may contain English loanwords in Urdu script)
        transliterate_fn: Function that takes List[str] and returns List[str]
                          (the M2M100 batch transliteration)

    Returns:
        Clean Roman Urdu text with English loanwords preserved
    """
    tokens, urdu_chunks = preprocess(urdu_text)

    # If no Urdu chunks (all loanwords), just return English
    if not urdu_chunks:
        return " ".join(eng for _, eng in tokens if eng)

    # Transliterate only the Urdu chunks
    transliterated = transliterate_fn(urdu_chunks)

    # Reconstruct
    merged = reconstruct(tokens, transliterated)

    # Post-process for any remaining mangled words
    merged = postprocess(merged)

    return merged


def process_batch(urdu_texts: List[str], transliterate_fn) -> List[str]:
    """
    Batch version: process multiple texts, collecting all Urdu chunks
    for a single batched M2M100 call.

    Args:
        urdu_texts: List of Urdu texts
        transliterate_fn: Function that takes List[str] and returns List[str]

    Returns:
        List of processed Roman Urdu texts
    """
    all_preprocessed = []
    all_urdu_chunks = []
    chunk_counts = []

    for text in urdu_texts:
        tokens, urdu_chunks = preprocess(text)
        all_preprocessed.append(tokens)
        chunk_counts.append(len(urdu_chunks))
        all_urdu_chunks.extend(urdu_chunks)

    # Single batched M2M100 call for all Urdu chunks
    if all_urdu_chunks:
        all_transliterated = transliterate_fn(all_urdu_chunks)
    else:
        all_transliterated = []

    # Reconstruct each text
    results = []
    offset = 0
    for i, tokens in enumerate(all_preprocessed):
        n = chunk_counts[i]
        my_chunks = all_transliterated[offset:offset + n]
        offset += n

        if not any(eng is None for _, eng in tokens):
            # All words are loanwords
            merged = " ".join(eng for _, eng in tokens if eng)
        else:
            merged = reconstruct(tokens, my_chunks)

        merged = postprocess(merged)
        results.append(merged)

    return results
