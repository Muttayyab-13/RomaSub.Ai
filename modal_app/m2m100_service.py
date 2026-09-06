"""
Modal service: M2M100 Urdu -> Roman Urdu on a per-second T4 GPU.

This runs the SAME generation as app/services/transliteration._m2m100_batch_transformers
(forced_bos_token_id=128105, num_beams=4) but on a GPU, billed only for the
seconds it actually runs (scale-to-zero -> no idle cost).

--------------------------------------------------------------------------
ONE-TIME SETUP
--------------------------------------------------------------------------
1. Push the fine-tuned model to a PRIVATE HuggingFace repo and set MODEL_REPO
   below to match:

     pip install -U "huggingface_hub[cli]" && huggingface-cli login
     mkdir -p /tmp/m2m100_push
     cp models/m2m100_ur_to_rur/{config.json,generation_config.json,model.safetensors} /tmp/m2m100_push/
     cp models/m2m100_tokenizer/{tokenizer_config.json,added_tokens.json,special_tokens_map.json,vocab.json,sentencepiece.bpe.model} /tmp/m2m100_push/
     huggingface-cli upload <username>/m2m100-ur-to-rur /tmp/m2m100_push . --repo-type model --private

2. Install + authenticate Modal, then create two secrets:
     pip install modal && modal setup
     modal secret create huggingface HF_TOKEN=<hf-read-token>
     modal secret create romasub-modal-auth ROMASUB_MODAL_TOKEN=<pick-a-shared-secret>

3. Deploy:
     modal deploy modal_app/m2m100_service.py
   Copy the printed https://...modal.run URL into MODAL_ENDPOINT_URL in .env,
   and put the shared secret from step 2 into MODAL_AUTH_TOKEN.
"""
import os
import modal
from fastapi import Header, HTTPException

MODEL_REPO = "muttayyab23/m2m100-2gb-custom"  # <-- set to your private HF repo
ROMAN_UR_TOKEN_ID = 128105

app = modal.App("romasub-m2m100")


def _download_model():
    """Runs at IMAGE BUILD time: bake the model into the image so container
    cold starts load from local disk instead of re-downloading ~1.9 GB from HF
    on every start. This is what keeps cold starts under the client timeout."""
    import os
    from huggingface_hub import snapshot_download
    snapshot_download(MODEL_REPO, token=os.environ["HF_TOKEN"])


image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "torch",
        "transformers>=4.45.0",
        "sentencepiece",
        "safetensors",
        "huggingface_hub",
        "fastapi[standard]",  # required by @modal.fastapi_endpoint (no longer auto-installed)
    )
    .run_function(_download_model, secrets=[modal.Secret.from_name("huggingface")])
)


@app.cls(
    image=image,
    gpu="T4",
    secrets=[
        modal.Secret.from_name("huggingface"),        # provides HF_TOKEN
        modal.Secret.from_name("romasub-modal-auth"),  # provides ROMASUB_MODAL_TOKEN
    ],
    scaledown_window=120,   # stay warm 2 min after last request
    min_containers=0,       # scale to zero -> pay only while running
)
class M2M100Service:
    @modal.enter()
    def load(self):
        import torch
        from transformers import M2M100ForConditionalGeneration, M2M100Tokenizer

        # Diagnostic: confirm the attached secrets injected the expected keys
        # (prints presence only, never the values).
        print("[startup] HF_TOKEN present:", bool(os.environ.get("HF_TOKEN")))
        print("[startup] ROMASUB_MODAL_TOKEN present:",
              bool(os.environ.get("ROMASUB_MODAL_TOKEN")))

        # The model + tokenizer were uploaded preserving their local folder
        # layout, so they live in subfolders of the repo (not at the root).
        token = os.environ["HF_TOKEN"]
        self.tok = M2M100Tokenizer.from_pretrained(
            MODEL_REPO, subfolder="m2m100_tokenizer", token=token
        )
        self.model = (
            M2M100ForConditionalGeneration.from_pretrained(
                MODEL_REPO, subfolder="m2m100_ur_to_rur", token=token
            )
            .to("cuda")
            .eval()
        )

    @modal.fastapi_endpoint(method="POST")
    def web(self, data: dict, authorization: str = Header(default="")):
        # `authorization` is bound from the HTTP `Authorization` header via
        # Header(); a plain `str` default would be read as a query param and
        # never see the header the backend actually sends.
        import torch

        expected = os.environ.get("ROMASUB_MODAL_TOKEN")
        if not expected:
            raise HTTPException(
                status_code=500,
                detail="ROMASUB_MODAL_TOKEN not set — create/attach the "
                       "'romasub-modal-auth' secret with that exact key",
            )
        if authorization != f"Bearer {expected}":
            raise HTTPException(status_code=401, detail="unauthorized")

        texts = data.get("texts", [])
        if not texts:
            return {"transliterations": []}

        self.tok.src_lang = "ur"
        enc = self.tok(
            texts, return_tensors="pt", max_length=128, truncation=True, padding=True
        ).to("cuda")
        with torch.no_grad():
            gen = self.model.generate(
                **enc,
                forced_bos_token_id=ROMAN_UR_TOKEN_ID,
                max_length=200,
                num_beams=4,
                early_stopping=True,
            )
        return {"transliterations": self.tok.batch_decode(gen, skip_special_tokens=True)}
