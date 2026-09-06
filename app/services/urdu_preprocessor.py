"""
Urdu Pre-processing Layer for RomaSub.AI

Normalizes Urdu text before it is passed to the M2M100 transliteration model.
Reduces input variance (mixed Unicode forms, presentation-form characters,
zero-width joiners, inconsistent whitespace) so M2M100 sees a canonical form.

Diacritization (adding aerab/harakaat) is intentionally NOT implemented:
no working off-the-shelf Urdu diacritizer exists at the time of writing.
The `enable_diacritics` flag and `load_diacritizer()` hook are kept as a
forward-compatible no-op stub so a real diacritizer can be slotted in later
without changing any call sites.
"""

import logging
import sys
import types
import importlib.util

# urduhack's `__init__.py` chains through pipeline → NER → `tf2crf`, which
# pulls deprecated `tensorflow-addons`. We only need character normalization
# (pure regex/dict tables in `urduhack.normalization.character`). Install a
# stub for the parent `urduhack` package in `sys.modules` BEFORE importing
# the leaf module — Python's import machinery treats the stub as already-
# loaded and skips running the real `urduhack/__init__.py`, while the stub's
# `__path__` still lets submodule resolution find `urduhack.normalization`.
# Do NOT replace with `import urduhack` or `from urduhack import normalize` —
# that re-triggers the broken init chain.
if "urduhack" not in sys.modules:
    _spec = importlib.util.find_spec("urduhack")
    if _spec is None or not _spec.submodule_search_locations:
        raise ImportError(
            "urduhack is not installed. Run: pip install --no-deps urduhack regex"
        )
    _stub = types.ModuleType("urduhack")
    _stub.__path__ = list(_spec.submodule_search_locations)
    sys.modules["urduhack"] = _stub

from urduhack.normalization.character import normalize as _urduhack_normalize  # noqa: E402

from app.config import settings

logger = logging.getLogger(__name__)


_diacritizer_loaded: bool = False
_diacritics_warned: bool = False


def load_diacritizer() -> None:
    """
    Eager-load hook called from the FastAPI lifespan at startup.

    Currently a logged no-op — reserved for future Urdu diacritizer model load.
    Idempotent via the `_diacritizer_loaded` flag.
    """
    global _diacritizer_loaded
    if _diacritizer_loaded:
        return

    if settings.enable_diacritics:
        logger.info(
            "Urdu preprocessor: diacritization requested but no backend is "
            "wired up; running in normalization-only mode."
        )
    else:
        logger.info("Urdu preprocessor: normalization-only mode (diacritics disabled).")

    _diacritizer_loaded = True


def preprocess_urdu_chunk(text: str) -> str:
    """
    Normalize a single Urdu text chunk for M2M100 input.

    Applies urduhack character normalization (Unicode standardization,
    presentation-form folding, punctuation canonicalization). If
    `settings.enable_diacritics` is True, logs a one-time warning and
    returns the normalized text unchanged (no diacritizer is available).
    """
    if not text:
        return text

    normalized = _urduhack_normalize(text)

    if settings.enable_diacritics:
        global _diacritics_warned
        if not _diacritics_warned:
            logger.warning(
                "diacritics requested but no Urdu diacritizer is available; "
                "returning normalized text only"
            )
            _diacritics_warned = True

    return normalized


def preprocess_urdu_chunks(texts: list[str]) -> list[str]:
    """Apply `preprocess_urdu_chunk` to each element."""
    return [preprocess_urdu_chunk(t) for t in texts]
