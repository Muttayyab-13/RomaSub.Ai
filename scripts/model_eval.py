"""
Minimal raw M2M100 demo — pulls a few test samples from the Roman-Urdu-Parl
dataset, runs them through the fine-tuned M2M100 model directly (no loanword
handling, no normalization, no post-processing), and prints each sample as:

    URDU       : <Urdu input>
    REFERENCE  : <gold Roman Urdu from dataset>
    PREDICTION : <what the model produced>

Usage (from repo root, with venv active):

    python scripts/run_raw_m2m100.py            # default: 10 samples
    python scripts/run_raw_m2m100.py -n 25      # show 25 samples
"""

from __future__ import annotations

import argparse
import contextlib
import sys
from pathlib import Path

# Add the repo root to sys.path so `from app.services...` works when this
# file is launched directly from the scripts/ folder.
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def main() -> int:
    p = argparse.ArgumentParser(description="Raw M2M100 demo on Roman-Urdu-Parl test samples.")
    p.add_argument("-n", "--num-samples", type=int, default=10,
                   help="How many test samples to run (default: 10).")
    p.add_argument("--num-beams", type=int, default=4,
                   help="Beam search width (default: 4, matches production).")
    args = p.parse_args()

    # Quiet down library logs.
    import os
    os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

    # ---- 1) Pull N test samples from the Roman-Urdu-Parl dataset ----
    # First run downloads to ~/.cache/huggingface/; later runs are instant.
    from datasets import load_dataset
    print(f"Loading {args.num_samples} samples from Mavkif/Roman-Urdu-Parl-split [test] ...")
    ds = load_dataset("Mavkif/Roman-Urdu-Parl-split", split="test")
    ds = ds.select(range(min(args.num_samples, len(ds))))
    urdu_inputs = [str(x) for x in ds["Urdu text"]]
    references = [str(x) for x in ds["Roman-Urdu text"]]

    # ---- 2) Load the fine-tuned M2M100 model ----
    # Banner messages go to stderr so they don't get tangled with the results.
    import torch
    with contextlib.redirect_stdout(sys.stderr):
        from app.services.transliteration import (
            ROMAN_UR_TOKEN_ID,                  # 128105 — the "__roman-ur__" tag
            get_m2m100_model_and_tokenizer,
        )
        model, tokenizer, device = get_m2m100_model_and_tokenizer()
    tokenizer.src_lang = "ur"  # input language is Urdu

    # ---- 3) Run raw M2M100 inference on the batch ----
    inputs = tokenizer(
        urdu_inputs,
        return_tensors="pt",
        max_length=128,        # truncate anything longer than 128 tokens
        truncation=True,
        padding=True,          # pad short sentences up to the longest one
    )
    inputs = {k: v.to(device) for k, v in inputs.items()}

    # `torch.no_grad()` skips gradient bookkeeping — faster, less memory.
    with torch.no_grad():
        generated = model.generate(
            **inputs,
            forced_bos_token_id=ROMAN_UR_TOKEN_ID,  # force Roman Urdu output
            max_length=200,                         # output token cap
            num_beams=args.num_beams,               # beam search for quality
            early_stopping=True,
        )

    # Token ids → text. `skip_special_tokens=True` strips <s>, </s>, lang tags.
    predictions = [p.strip() for p in tokenizer.batch_decode(generated, skip_special_tokens=True)]

    # ---- 4) Print URDU / REFERENCE / PREDICTION for each sample ----
    print(f"\nRaw M2M100 — {len(predictions)} test samples\n" + "=" * 70)
    for i, (urdu, ref, pred) in enumerate(zip(urdu_inputs, references, predictions), start=1):
        match = "✓" if pred == ref else "✗"
        print(f"\n[{i}] {match}")
        print(f"  URDU       : {urdu}")
        print(f"  REFERENCE  : {ref}")
        print(f"  PREDICTION : {pred}")

    # ---- 5) Accuracy metrics over the whole batch ----
    # sacrebleu = BLEU + chrF (translation quality, higher is better, 0–100).
    # jiwer    = CER + WER  (error rates, LOWER is better, shown as %).
    import sacrebleu
    from jiwer import cer as compute_cer, wer as compute_wer

    bleu = sacrebleu.corpus_bleu(predictions, [references]).score
    chrf = sacrebleu.corpus_chrf(predictions, [references]).score
    cer = compute_cer(references, predictions) * 100
    wer = compute_wer(references, predictions) * 100
    correct = sum(1 for p, r in zip(predictions, references) if p == r)

    print(f"\n{'=' * 70}")
    print("Accuracy metrics:")
    print(f"  Exact match : {correct}/{len(predictions)} ({correct / len(predictions) * 100:.1f}%)")
    print(f"  BLEU        : {bleu:.2f}      (higher = better, 0–100)")
    print(f"  chrF        : {chrf:.2f}      (higher = better, 0–100)")
    print(f"  CER         : {cer:.2f}%     (lower  = better)")
    print(f"  WER         : {wer:.2f}%     (lower  = better)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
