# M2M100 Pluggable Backend + Offline Viva Switch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give M2M100 transliteration the same pluggable-backend treatment Whisper got, so it can run on a fast cloud GPU (Modal) by default, on a quantized local model (CTranslate2 int8) offline, or on the original transformers model — with a single `OFFLINE_MODE` flag that forces the *entire* pipeline (Whisper + M2M100) local for a viva.

**Architecture:** Mirror the Whisper backend pattern already committed in `app/services/asr.py`. The raw model call `_m2m100_batch()` in `app/services/transliteration.py` becomes a dispatcher routing to one of three backend functions based on `settings.effective_transliteration_backend`. A master `offline_mode` setting is resolved through two computed properties (`effective_whisper_backend`, `effective_transliteration_backend`) so one flag flips both services. Cloud calls fall back to local on any error, exactly like Groq→faster-whisper.

**Tech Stack:** FastAPI backend, HuggingFace `transformers` (existing fp32 path), `ctranslate2` 4.7.1 (already installed via faster-whisper) for the quantized local path, Modal (per-second serverless GPU) for the cloud path, `requests` for the HTTP client, `pytest` + `monkeypatch` for tests.

---

> **IMPLEMENTED SCOPE (2026-07-08):** Per user direction, only the **Modal cloud
> backend** and the **online/offline switch** were built. Phase 0 (benchmark) and
> Phase 2 (local CTranslate2) were **dropped** — the offline/local path uses the
> existing `transformers` fp32 backend instead of CT2. So the M2M100 backends are
> `modal` and `transformers` only, and `offline_mode` forces M2M100 →
> `transformers` (not `local`). The Phase 2 tasks below are retained for reference
> but were not executed.

---

## Prerequisites & Decisions (resolve before Phase 3)

- **Model hosting for Modal:** push the fine-tuned checkpoint to a **private HuggingFace repo** (`<username>/m2m100-ur-to-rur`) and let the Modal image pull it. This reuses the combined model+tokenizer staging from the earlier M2M100 discussion. (Alternative: a Modal Volume — not used here.)
- **CT2 conversion RAM risk:** converting loads the fp32 model (~1.9 GB) once. This machine has ~1–2 GB free. **Mitigation:** run `scripts/convert_m2m100_ct2.py` in a fresh shell with other apps closed, or run it once on Google Colab and copy the ~500 MB `models/m2m100_ur_to_rur_ct2/` back. Conversion is a one-time offline step; the app only ever loads the small int8 result.
- **`forced_bos_token_id=128105` is NOT baked into the checkpoint** (verified: `generation_config.json` has no `forced_bos_token_id`). Every backend must apply it explicitly. CT2 does this via `target_prefix`; Modal via `generate(forced_bos_token_id=...)`. Parity against the current transformers output is verified in Phase 2.

## File Structure

- `app/config.py` — add `transliteration_backend`, `offline_mode`, `m2m100_ct2_path`, `modal_endpoint_url`, `modal_auth_token`; add `effective_whisper_backend` / `effective_transliteration_backend` properties. **(modify)**
- `app/services/transliteration.py` — split `_m2m100_batch` into a dispatcher + three backend fns (`_transformers`, `_ct2`, `_modal`). **(modify)**
- `app/services/asr.py` — `transcribe_chunk` reads `effective_whisper_backend` instead of `whisper_backend`. **(modify, 1 line)**
- `modal_app/m2m100_service.py` — the Modal app (image, GPU class, POST endpoint). **(create)**
- `scripts/benchmark_m2m100.py` — time the current local path on real segments (Phase 0 gate). **(create)**
- `scripts/convert_m2m100_ct2.py` — one-time HF→CTranslate2 int8 conversion. **(create)**
- `scripts/verify_ct2_parity.py` — compare CT2 vs transformers output on samples. **(create)**
- `tests/test_transliteration_backend.py` — dispatch + fallback unit tests. **(create)**
- `tests/test_offline_mode.py` — `effective_*` property tests. **(create)**
- `.env.example` — document the new vars + the one-line viva switch. **(modify)**
- `requirements.txt` — no change (ctranslate2 present transitively; `modal` is a dev/deploy-only dep documented in the Modal app). **(no change)**

---

## Phase 0 — Benchmark first (decision gate)

### Task 0: Measure whether M2M100 is even the bottleneck

**Files:**
- Create: `scripts/benchmark_m2m100.py`

- [ ] **Step 1: Write the benchmark script**

```python
"""One-off: time the current transformers M2M100 path on real segments."""
import sys, time
from app.services import transliteration as t

# A representative set of short Urdu subtitle-like segments.
SAMPLE = [
    "میں ہسپتال گیا تھا",
    "وہ کبھی ملیں وہ کہیں ملیں",
    "ہمیں انتظار قبول ہے",
    "یہ عاشقی ہے حوث نہیں",
] * 8  # 32 segments, ~4 batches at batch_size=8

def main():
    # warm the model (excluded from timing)
    t.transliterate_batch(SAMPLE[:1])
    start = time.time()
    out = t.transliterate_batch(SAMPLE)
    dt = time.time() - start
    print(f"{len(SAMPLE)} segments in {dt:.2f}s  ->  {dt/len(SAMPLE)*1000:.0f} ms/segment")
    print("sample:", out[0])

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it**

Run: `./venv/bin/python -m scripts.benchmark_m2m100`
Expected: a timing line. **Decision:** if it is comfortably fast for a demo (e.g. < ~5s for a typical file's segment count), stop here — cloud is solving a non-problem, and only Phase 1 + Phase 2 (free local speedup) are worth doing. If it is slow, proceed through all phases.

- [ ] **Step 3: Commit**

```bash
git add scripts/benchmark_m2m100.py
git commit -m "chore(bench): add M2M100 local inference benchmark"
```

---

## Phase 1 — Backend-switch backbone + offline master switch

This phase ships working software on its own: the dispatcher defaults safely to the existing transformers path, and `offline_mode` works immediately.

### Task 1: Add settings + effective-backend properties

**Files:**
- Modify: `app/config.py`
- Test: `tests/test_offline_mode.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_offline_mode.py
from app.config import Settings

def test_offline_mode_forces_local_backends():
    s = Settings(offline_mode=True, whisper_backend="groq", transliteration_backend="modal")
    assert s.effective_whisper_backend == "faster"
    assert s.effective_transliteration_backend == "local"

def test_online_mode_passes_backends_through():
    s = Settings(offline_mode=False, whisper_backend="groq", transliteration_backend="modal")
    assert s.effective_whisper_backend == "groq"
    assert s.effective_transliteration_backend == "modal"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/python -m pytest tests/test_offline_mode.py -v`
Expected: FAIL — `AttributeError: 'Settings' object has no attribute 'effective_whisper_backend'`

- [ ] **Step 3: Add the settings and properties**

In `app/config.py`, after the existing Groq block (`groq_model: str = ...`), add:

```python
    # Transliteration backend: "modal" (cloud GPU), "local" (CTranslate2 int8),
    # or "transformers" (original fp32). Modal falls back to local on error.
    transliteration_backend: str = "transformers"
    m2m100_ct2_path: str = "models/m2m100_ur_to_rur_ct2"
    modal_endpoint_url: str = ""
    modal_auth_token: str = ""

    # Master offline switch. When True, forces the WHOLE pipeline local
    # (Whisper -> faster, M2M100 -> local CTranslate2) regardless of the
    # per-service backend settings. Flip this for the viva. See the
    # effective_* properties below.
    offline_mode: bool = False
```

Then, after the `max_file_size_bytes` property, add:

```python
    @property
    def effective_whisper_backend(self) -> str:
        """Whisper backend after applying the offline master switch."""
        return "faster" if self.offline_mode else self.whisper_backend

    @property
    def effective_transliteration_backend(self) -> str:
        """M2M100 backend after applying the offline master switch."""
        return "local" if self.offline_mode else self.transliteration_backend
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./venv/bin/python -m pytest tests/test_offline_mode.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add app/config.py tests/test_offline_mode.py
git commit -m "feat(config): transliteration backend + offline master switch"
```

### Task 2: Point Whisper dispatch at the effective backend

**Files:**
- Modify: `app/services/asr.py` (in `transcribe_chunk`)
- Test: reuse `tests/test_asr_backend.py` (add one offline case)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_asr_backend.py`:

```python
def test_transcribe_chunk_offline_mode_forces_local(monkeypatch):
    monkeypatch.setattr(asr.settings, "whisper_backend", "groq")
    monkeypatch.setattr(asr.settings, "groq_api_key", "test-key")
    monkeypatch.setattr(asr.settings, "offline_mode", True)  # viva switch on
    _stub_local(monkeypatch)
    called = {}
    monkeypatch.setattr(asr, "_transcribe_groq",
                        lambda path, language="ur": called.setdefault("groq", True))
    result = asr.transcribe_chunk("chunk.wav")
    assert result["text"] == "local"
    assert "groq" not in called  # offline must never hit the network
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/python -m pytest tests/test_asr_backend.py::test_transcribe_chunk_offline_mode_forces_local -v`
Expected: FAIL — Groq is still called (dispatch reads `whisper_backend`, not the effective one), so `"groq" in called`.

- [ ] **Step 3: Update the dispatch line**

In `app/services/asr.py`, in `transcribe_chunk`, change:

```python
    backend = (settings.whisper_backend or "faster").lower()
```
to:
```python
    backend = (settings.effective_whisper_backend or "faster").lower()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./venv/bin/python -m pytest tests/test_asr_backend.py -v`
Expected: PASS (8 passed — 7 existing + 1 new)

- [ ] **Step 5: Commit**

```bash
git add app/services/asr.py tests/test_asr_backend.py
git commit -m "feat(asr): honor offline_mode master switch in Whisper dispatch"
```

### Task 3: Split `_m2m100_batch` into a dispatcher + transformers backend

**Files:**
- Modify: `app/services/transliteration.py:98-139` (the current `_m2m100_batch`)
- Test: `tests/test_transliteration_backend.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_transliteration_backend.py
from app.services import transliteration as tr

def _stub_ct2(monkeypatch, marker="ct2"):
    monkeypatch.setattr(tr, "_m2m100_batch_ct2",
                        lambda texts, batch_size=8: [marker] * len(texts))

def test_dispatch_uses_modal_when_configured(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(tr, "_m2m100_batch_modal",
                        lambda texts, batch_size=8: ["modal"] * len(texts))
    _stub_ct2(monkeypatch)
    assert tr._m2m100_batch(["a", "b"]) == ["modal", "modal"]

def test_dispatch_falls_back_to_local_on_modal_error(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    def boom(texts, batch_size=8): raise RuntimeError("modal down")
    monkeypatch.setattr(tr, "_m2m100_batch_modal", boom)
    _stub_ct2(monkeypatch)
    assert tr._m2m100_batch(["a"]) == ["ct2"]

def test_dispatch_skips_modal_when_no_url(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "offline_mode", False)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "")
    called = {}
    monkeypatch.setattr(tr, "_m2m100_batch_modal",
                        lambda texts, batch_size=8: called.setdefault("modal", True))
    _stub_ct2(monkeypatch)
    assert tr._m2m100_batch(["a"]) == ["ct2"]
    assert "modal" not in called

def test_dispatch_offline_forces_local(monkeypatch):
    monkeypatch.setattr(tr.settings, "transliteration_backend", "modal")
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(tr.settings, "offline_mode", True)  # viva switch
    called = {}
    monkeypatch.setattr(tr, "_m2m100_batch_modal",
                        lambda texts, batch_size=8: called.setdefault("modal", True))
    _stub_ct2(monkeypatch)
    assert tr._m2m100_batch(["a"]) == ["ct2"]
    assert "modal" not in called
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py -v`
Expected: FAIL — `AttributeError: module 'app.services.transliteration' has no attribute '_m2m100_batch_ct2'`

- [ ] **Step 3: Refactor `_m2m100_batch` into dispatcher + transformers backend**

In `app/services/transliteration.py`, **rename** the current `_m2m100_batch` function body to `_m2m100_batch_transformers` (keep its code identical), then add the dispatcher and stubs above it:

```python
def _m2m100_batch(texts: List[str], batch_size: int = 8) -> List[str]:
    """Dispatch raw M2M100 inference to the configured backend.

    Backends receive already-normalized Urdu texts and return Roman Urdu.
    Modal (cloud) falls back to local CTranslate2 on any error.
    """
    if not texts:
        return []

    backend = (settings.effective_transliteration_backend or "transformers").lower()

    if backend == "modal":
        if settings.modal_endpoint_url:
            try:
                return _m2m100_batch_modal(texts, batch_size)
            except Exception as e:
                logger.warning(
                    "[TRANSLITERATION] Modal failed (%s); falling back to local CTranslate2", e
                )
        else:
            logger.warning(
                "[TRANSLITERATION] transliteration_backend='modal' but MODAL_ENDPOINT_URL is empty; using local"
            )
        return _m2m100_batch_ct2(texts, batch_size)

    if backend == "transformers":
        return _m2m100_batch_transformers(texts, batch_size)

    # Default local backend.
    return _m2m100_batch_ct2(texts, batch_size)


def _m2m100_batch_modal(texts: List[str], batch_size: int = 8) -> List[str]:
    """Placeholder — implemented in Phase 3."""
    raise NotImplementedError("Modal backend not yet implemented")


def _m2m100_batch_ct2(texts: List[str], batch_size: int = 8) -> List[str]:
    """Placeholder — implemented in Phase 2. Falls back to transformers."""
    return _m2m100_batch_transformers(texts, batch_size)
```

(The renamed `_m2m100_batch_transformers` keeps the existing tokenizer + `model.generate(forced_bos_token_id=ROMAN_UR_TOKEN_ID, num_beams=4, ...)` body unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Run full suite (no regressions)**

Run: `./venv/bin/python -m pytest -q`
Expected: all pass (previous 30 + new offline/backend tests)

- [ ] **Step 6: Commit**

```bash
git add app/services/transliteration.py tests/test_transliteration_backend.py
git commit -m "feat(transliteration): pluggable M2M100 backend dispatcher"
```

---

## Phase 2 — Local CTranslate2 int8 backend (free speedup)

### Task 4: One-time HF→CTranslate2 int8 conversion script

**Files:**
- Create: `scripts/convert_m2m100_ct2.py`

- [ ] **Step 1: Write the conversion script**

```python
"""One-time: convert the fine-tuned M2M100 to CTranslate2 int8.

CTranslate2's converter needs the tokenizer files ALONGSIDE the model, so we
stage a combined dir first, then convert. Output: models/m2m100_ur_to_rur_ct2/
(~500 MB int8, vs 1.9 GB fp32).

RAM note: this loads the fp32 model once. If it OOMs on this laptop, run it on
Colab and copy the output dir back.
"""
import os, shutil, subprocess, tempfile
from app.config import settings

MODEL_FILES = ["config.json", "generation_config.json", "model.safetensors"]
TOK_FILES = ["tokenizer_config.json", "added_tokens.json", "special_tokens_map.json",
             "vocab.json", "sentencepiece.bpe.model"]

def main():
    staging = tempfile.mkdtemp(prefix="m2m100_ct2_src_")
    for f in MODEL_FILES:
        shutil.copy(os.path.join(settings.m2m100_model_path, f), staging)
    for f in TOK_FILES:
        shutil.copy(os.path.join(settings.m2m100_tokenizer_path, f), staging)

    out_dir = settings.m2m100_ct2_path
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)

    subprocess.run([
        "ct2-transformers-converter",
        "--model", staging,
        "--output_dir", out_dir,
        "--quantization", "int8",
    ], check=True)
    shutil.rmtree(staging)
    print(f"Converted -> {out_dir}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the conversion**

Run: `./venv/bin/python -m scripts.convert_m2m100_ct2`
Expected: creates `models/m2m100_ur_to_rur_ct2/` containing `model.bin`, `config.json`, `shared_vocabulary.*`. If it OOMs, run on Colab and copy the dir back.

- [ ] **Step 3: Commit the script (not the model weights)**

```bash
git add scripts/convert_m2m100_ct2.py
git commit -m "chore(scripts): M2M100 -> CTranslate2 int8 conversion"
```

(Ensure `models/m2m100_ur_to_rur_ct2/` is gitignored like other model dirs.)

### Task 5: Implement the CTranslate2 runtime backend

**Files:**
- Modify: `app/services/transliteration.py` (replace the `_m2m100_batch_ct2` placeholder; add module globals + loader)
- Test: `tests/test_transliteration_backend.py` (add a fallback-when-missing test)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_transliteration_backend.py`:

```python
def test_ct2_falls_back_to_transformers_when_model_missing(monkeypatch):
    monkeypatch.setattr(tr.settings, "m2m100_ct2_path", "/nonexistent/ct2/dir")
    monkeypatch.setattr(tr, "_m2m100_batch_transformers",
                        lambda texts, batch_size=8: ["tf"] * len(texts))
    # Call the real _m2m100_batch_ct2 (placeholder removed in step 3).
    assert tr._m2m100_batch_ct2(["a", "b"]) == ["tf", "tf"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py::test_ct2_falls_back_to_transformers_when_model_missing -v`
Expected: FAIL — placeholder returns transformers output already, so it may PASS trivially; if so, this test only becomes meaningful once the real CT2 body exists. Proceed to step 3, then re-run — it must still pass via the explicit `os.path.isdir` guard.

- [ ] **Step 3: Replace the placeholder with the real CT2 backend**

In `app/services/transliteration.py`, add module globals near the top (with the other `_m2m100_*` globals):

```python
_ct2_translator = None
_ct2_tokenizer = None
```

Replace the `_m2m100_batch_ct2` placeholder with:

```python
def _get_ct2_translator():
    """Lazily load and cache the CTranslate2 translator + tokenizer."""
    global _ct2_translator, _ct2_tokenizer
    if _ct2_translator is None:
        import ctranslate2
        from transformers import M2M100Tokenizer
        print(f"[TRANSLITERATION] Loading CTranslate2 model: {settings.m2m100_ct2_path}")
        _ct2_translator = ctranslate2.Translator(
            settings.m2m100_ct2_path, device="cpu", compute_type="int8"
        )
        _ct2_tokenizer = M2M100Tokenizer.from_pretrained(settings.m2m100_tokenizer_path)
    return _ct2_translator, _ct2_tokenizer


def _m2m100_batch_ct2(texts: List[str], batch_size: int = 8) -> List[str]:
    if not texts:
        return []

    if not os.path.isdir(settings.m2m100_ct2_path):
        logger.warning(
            "[TRANSLITERATION] CTranslate2 model missing at %s; using transformers",
            settings.m2m100_ct2_path,
        )
        return _m2m100_batch_transformers(texts, batch_size)

    translator, tokenizer = _get_ct2_translator()
    tokenizer.src_lang = "ur"
    # Force Roman-Urdu by seeding the decoder with token 128105 as a prefix.
    prefix = tokenizer.convert_ids_to_tokens([ROMAN_UR_TOKEN_ID])

    results: List[str] = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        sources = [
            tokenizer.convert_ids_to_tokens(tokenizer(t)["input_ids"]) for t in batch
        ]
        outputs = translator.translate_batch(
            sources,
            target_prefix=[prefix] * len(sources),
            beam_size=4,
            max_decoding_length=200,
        )
        for res in outputs:
            hyp = res.hypotheses[0][len(prefix):]  # strip the forced prefix
            ids = tokenizer.convert_tokens_to_ids(hyp)
            results.append(tokenizer.decode(ids, skip_special_tokens=True))

    return results
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py -v`
Expected: PASS (all backend tests incl. the missing-model fallback)

- [ ] **Step 5: Commit**

```bash
git add app/services/transliteration.py tests/test_transliteration_backend.py
git commit -m "feat(transliteration): local CTranslate2 int8 backend"
```

### Task 6: Verify CT2 output parity against transformers

**Files:**
- Create: `scripts/verify_ct2_parity.py`

- [ ] **Step 1: Write the parity script**

```python
"""Compare CTranslate2 int8 output vs the transformers fp32 output.

Quantization can shift a few tokens; the goal is high agreement on real
Urdu, not byte-identity. Prints a side-by-side diff and an exact-match rate.
"""
from app.services import transliteration as tr

SAMPLES = [
    "میں ہسپتال گیا تھا",
    "وہ کبھی ملیں وہ کہیں ملیں",
    "ہمیں انتظار قبول ہے",
    "سرے دور ہو سرے حشر ہو",
    "میں انہی کا تھا میں انہی کا ہوں",
]

def main():
    tf = tr._m2m100_batch_transformers(SAMPLES)
    ct2 = tr._m2m100_batch_ct2(SAMPLES)
    exact = sum(a == b for a, b in zip(tf, ct2))
    for s, a, b in zip(SAMPLES, tf, ct2):
        flag = "OK " if a == b else "DIFF"
        print(f"[{flag}] src : {s}\n       tf  : {a}\n       ct2 : {b}\n")
    print(f"Exact match: {exact}/{len(SAMPLES)}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run and review**

Run: `./venv/bin/python -m scripts.verify_ct2_parity`
Expected: high agreement (ideally 5/5; minor differences are acceptable given the downstream fuzzy post-processor + optional Claude refine). If output is garbled (e.g. wrong script or empty), the `target_prefix` token is wrong — inspect `tokenizer.convert_ids_to_tokens([128105])` and fix before proceeding.

- [ ] **Step 3: Commit**

```bash
git add scripts/verify_ct2_parity.py
git commit -m "test(transliteration): CT2 vs transformers parity check"
```

---

## Phase 3 — Modal cloud GPU backend

### Task 7: Push the model to a private HuggingFace repo

**Files:** none (one-time CLI)

- [ ] **Step 1: Stage + push model and tokenizer into one repo**

```bash
./venv/bin/pip install -U "huggingface_hub[cli]"
huggingface-cli login   # WRITE token
mkdir -p /tmp/m2m100_push
cp models/m2m100_ur_to_rur/{config.json,generation_config.json,model.safetensors} /tmp/m2m100_push/
cp models/m2m100_tokenizer/{tokenizer_config.json,added_tokens.json,special_tokens_map.json,vocab.json,sentencepiece.bpe.model} /tmp/m2m100_push/
huggingface-cli upload <username>/m2m100-ur-to-rur /tmp/m2m100_push . --repo-type model --private
```

- [ ] **Step 2: Verify** the repo lists all 8 files at `hf.co/<username>/m2m100-ur-to-rur`.

### Task 8: Write and deploy the Modal service

**Files:**
- Create: `modal_app/m2m100_service.py`

- [ ] **Step 1: Write the Modal app**

```python
"""Modal service: M2M100 Urdu -> Roman Urdu on a per-second T4 GPU.

Deploy:  modal deploy modal_app/m2m100_service.py
Secrets (create once in the Modal dashboard):
  * huggingface        -> HF_TOKEN=<read token for the private repo>
  * romasub-modal-auth -> ROMASUB_MODAL_TOKEN=<shared secret the backend sends>
"""
import os
import modal

MODEL_REPO = "<username>/m2m100-ur-to-rur"   # <-- set to your repo
ROMAN_UR_TOKEN_ID = 128105

app = modal.App("romasub-m2m100")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("torch", "transformers>=4.45.0", "sentencepiece", "safetensors")
)

@app.cls(
    image=image,
    gpu="T4",
    secrets=[
        modal.Secret.from_name("huggingface"),
        modal.Secret.from_name("romasub-modal-auth"),
    ],
    scaledown_window=120,   # stay warm 2 min after last request
    min_containers=0,       # scale to zero -> no idle cost
)
class M2M100Service:
    @modal.enter()
    def load(self):
        import torch
        from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer
        token = os.environ["HF_TOKEN"]
        self.tok = M2M100Tokenizer.from_pretrained(MODEL_REPO, token=token)
        self.model = (
            M2M100ForConditionalGeneration.from_pretrained(MODEL_REPO, token=token)
            .to("cuda").eval()
        )

    @modal.fastapi_endpoint(method="POST")
    def web(self, data: dict, authorization: str = ""):
        import torch
        from fastapi import Header, HTTPException

        expected = os.environ["ROMASUB_MODAL_TOKEN"]
        if authorization != f"Bearer {expected}":
            raise HTTPException(status_code=401, detail="unauthorized")

        texts = data.get("texts", [])
        if not texts:
            return {"transliterations": []}

        self.tok.src_lang = "ur"
        enc = self.tok(texts, return_tensors="pt", max_length=128,
                       truncation=True, padding=True).to("cuda")
        with torch.no_grad():
            gen = self.model.generate(
                **enc, forced_bos_token_id=ROMAN_UR_TOKEN_ID,
                max_length=200, num_beams=4, early_stopping=True,
            )
        return {"transliterations": self.tok.batch_decode(gen, skip_special_tokens=True)}
```

> Note: `authorization` is bound from the request header by FastAPI. If your Modal version requires it, import and use `fastapi.Header` explicitly: `authorization: str = Header(default="")`.

- [ ] **Step 2: Create the two Modal secrets** in the Modal dashboard (`huggingface` with `HF_TOKEN`, `romasub-modal-auth` with `ROMASUB_MODAL_TOKEN`).

- [ ] **Step 3: Deploy**

Run: `modal deploy modal_app/m2m100_service.py`
Expected: prints a web endpoint URL like `https://<user>--romasub-m2m100-m2m100service-web.modal.run`.

- [ ] **Step 4: Smoke-test the endpoint**

```bash
curl -s -X POST "<endpoint-url>" \
  -H "Authorization: Bearer <ROMASUB_MODAL_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"texts": ["میں ہسپتال گیا تھا"]}'
```
Expected: `{"transliterations": ["main hospital gaya tha"]}` (roughly). First call incurs the cold start; a second call is fast.

- [ ] **Step 5: Commit**

```bash
git add modal_app/m2m100_service.py
git commit -m "feat(modal): M2M100 per-second GPU service"
```

### Task 9: Implement the backend Modal HTTP client

**Files:**
- Modify: `app/services/transliteration.py` (replace the `_m2m100_batch_modal` placeholder)
- Test: `tests/test_transliteration_backend.py` (add a request-shape test with a mocked `requests.post`)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_transliteration_backend.py`:

```python
def test_modal_client_posts_texts_and_reads_transliterations(monkeypatch):
    captured = {}
    class FakeResp:
        def raise_for_status(self): pass
        def json(self): return {"transliterations": ["x", "y"]}
    def fake_post(url, headers=None, json=None, timeout=None):
        captured["url"], captured["headers"], captured["json"] = url, headers, json
        return FakeResp()
    import requests
    monkeypatch.setattr(requests, "post", fake_post)
    monkeypatch.setattr(tr.settings, "modal_endpoint_url", "https://x.modal.run")
    monkeypatch.setattr(tr.settings, "modal_auth_token", "secret")

    out = tr._m2m100_batch_modal(["a", "b"])

    assert out == ["x", "y"]
    assert captured["url"] == "https://x.modal.run"
    assert captured["headers"]["Authorization"] == "Bearer secret"
    assert captured["json"] == {"texts": ["a", "b"]}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py::test_modal_client_posts_texts_and_reads_transliterations -v`
Expected: FAIL — `NotImplementedError` from the placeholder.

- [ ] **Step 3: Replace the placeholder**

```python
def _m2m100_batch_modal(texts: List[str], batch_size: int = 8) -> List[str]:
    if not texts:
        return []
    import requests

    results: List[str] = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        resp = requests.post(
            settings.modal_endpoint_url,
            headers={"Authorization": f"Bearer {settings.modal_auth_token}"},
            json={"texts": batch},
            timeout=60,
        )
        resp.raise_for_status()
        results.extend(resp.json()["transliterations"])
    return results
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./venv/bin/python -m pytest tests/test_transliteration_backend.py -v`
Expected: PASS (all)

- [ ] **Step 5: Real end-to-end check (with the deployed endpoint)**

Set `MODAL_ENDPOINT_URL`, `MODAL_AUTH_TOKEN`, `TRANSLITERATION_BACKEND=modal` in `.env`, then:

Run: `./venv/bin/python -c "from app.services import transliteration as t; print(t.transliterate_batch(['میں ہسپتال گیا تھا']))"`
Expected: a Roman-Urdu string via the real Modal call.

- [ ] **Step 6: Commit**

```bash
git add app/services/transliteration.py tests/test_transliteration_backend.py
git commit -m "feat(transliteration): Modal HTTP client backend"
```

---

## Phase 4 — Wire the switch, verify both modes, document

### Task 10: Set cloud-by-default and document the viva switch

**Files:**
- Modify: `.env.example`

- [ ] **Step 1: Flip the default and document**

In `.env.example`, add after the Whisper/Groq block:

```bash
# ── Transliteration (M2M100) ─────────────────────────────────
# TRANSLITERATION_BACKEND:
#   modal        Modal per-second GPU (fast; needs MODAL_* below). Falls back
#                to local CTranslate2 on any error.
#   local        local CTranslate2 int8 (offline, low RAM).
#   transformers original fp32 model (slowest).
TRANSLITERATION_BACKEND=modal
M2M100_CT2_PATH=models/m2m100_ur_to_rur_ct2
MODAL_ENDPOINT_URL=https://your-workspace--romasub-m2m100-m2m100service-web.modal.run
MODAL_AUTH_TOKEN=your-shared-secret

# ── ONE-LINE VIVA SWITCH ─────────────────────────────────────
# Set to true to force the WHOLE pipeline local (Whisper -> faster-whisper,
# M2M100 -> local CTranslate2). No network needed. Flip this before a demo so
# a flaky room wifi can never break the presentation.
OFFLINE_MODE=false
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "docs(env): document transliteration backend + OFFLINE_MODE viva switch"
```

### Task 11: End-to-end verification of both modes

**Files:** none (verification only)

- [ ] **Step 1: Verify ONLINE mode** — with `OFFLINE_MODE=false`, `WHISPER_BACKEND=groq`, `TRANSLITERATION_BACKEND=modal`:

Run: `./venv/bin/python -c "from app.config import settings as s; print('whisper=', s.effective_whisper_backend, 'm2m100=', s.effective_transliteration_backend)"`
Expected: `whisper= groq m2m100= modal`

- [ ] **Step 2: Verify VIVA mode** — set `OFFLINE_MODE=true`, re-run the same command.
Expected: `whisper= faster m2m100= local` (one flag flipped both).

- [ ] **Step 3: Full offline transcribe+transliterate on a real sample** (with `OFFLINE_MODE=true`, wifi off if you want to prove it):

Run: `./venv/bin/python -c "from app.services import asr; r=asr.transcribe_chunk('uploads/media/0e47bb3f-fac7-4ff4-82f3-9328f4375143_audio.wav'); print(r['segments'][0]); from app.services import transliteration as t; print(t.transliterate_batch([r['segments'][0]['text']]))"`
Expected: a segment dict + a Roman-Urdu transliteration, entirely local, no network.

- [ ] **Step 4: Full test suite**

Run: `./venv/bin/python -m pytest -q`
Expected: all pass.

---

## Risks & Mitigations

- **CT2 conversion OOM on this laptop** → convert on Colab, copy `models/m2m100_ur_to_rur_ct2/` back (Task 4 note).
- **CT2 `target_prefix` token wrong → garbled output** → caught by the parity script (Task 6) before any wiring is trusted.
- **Modal cold start (~seconds–1 min) on first demo call** → pre-warm with one dummy request 2–3 min before presenting; or set `OFFLINE_MODE=true` for the viva and skip Modal entirely.
- **Behavior change:** default `TRANSLITERATION_BACKEND` becomes `modal` in Task 10. Until Modal is deployed, an empty `MODAL_ENDPOINT_URL` makes the dispatcher log and fall back to local/transformers — safe, but set the URL or use `transformers`/`local` explicitly in the meantime.

## Self-Review Notes

- **Spec coverage:** cloud default (Modal, Tasks 8–9) ✅; free local speedup (CT2, Tasks 4–6) ✅; one-line viva switch (`offline_mode` + `effective_*`, Tasks 1–3, wired across Whisper in Task 2 and M2M100 in Task 3, verified Task 11) ✅.
- **Type consistency:** backend string values `"modal" | "local" | "transformers"`; fns `_m2m100_batch_{modal,ct2,transformers}`; endpoint contract `{"texts": [...]}` → `{"transliterations": [...]}` used identically in the Modal app (Task 8) and the client (Task 9).
- **Fallback symmetry with Whisper:** `modal → ct2` mirrors committed `groq → faster-whisper`.
