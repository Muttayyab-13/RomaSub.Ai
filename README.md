# RomaSub.AI

**Urdu speech in → readable Roman Urdu captions out.**

RomaSub.AI is a desktop-first captioning tool that listens to Urdu audio or video and produces
subtitles in **Roman Urdu** — the Latin-script Urdu that Pakistani audiences actually type, read,
and search in every day.

This is **transliteration, not translation**. The words stay Urdu; only the script changes:

> `میں ٹھیک ہوں` → `main theek hoon`  *(not "I am fine")*

Almost every automatic captioning tool offers exactly two outputs — native Nastaʿlīq, or an English
translation. Neither is what this audience wants. RomaSub.AI fills that gap, then hands the result to
a human editor for the last mile.

The repository contains **both halves of the product**:

| Part | Stack | Location |
|---|---|---|
| **Backend API** | FastAPI + Whisper + fine-tuned M2M100 | `app/`, `modal_app/` |
| **Client app** | Flutter, desktop-first (Linux / Windows / macOS) | `FrontEnd/` |

---

## Screenshots

| Login | Dashboard |
|---|---|
| ![Login](Screenshots/Screenshot%20from%202026-08-26%2015-06-52.png) | ![Dashboard](Screenshots/Screenshot%20from%202026-08-26%2015-07-26.png) |

| Subtitle editor — segment detail + timeline | Segment list |
|---|---|
| ![Editor](Screenshots/Screenshot%20from%202026-08-26%2015-09-26.png) | ![Segments](Screenshots/Screenshot%20from%202026-08-26%2015-09-06.png) |

| Realtime viewer — live captions while processing | Projects |
|---|---|
| ![Realtime](Screenshots/Screenshot%20from%202026-08-26%2015-15-36.png) | ![Projects](Screenshots/Screenshot%20from%202026-08-26%2015-07-33.png) |

| Exports | Full transcript viewer |
|---|---|
| ![Exports](Screenshots/Screenshot%20from%202026-08-26%2015-07-39.png) | ![Full text](Screenshots/Screenshot%20from%202026-08-26%2015-13-46.png) |

---

## What it does

- **Accounts** — email/password with mandatory email verification (6-digit OTP, 15-minute validity),
  Google OAuth (mobile/web ID-token flow *and* a desktop authorization-code flow), forgot-password
  wizard, profile + picture management. JWTs last 24 hours with no refresh.
- **Upload** — video (`mp4, avi, mkv, mov, webm`) or audio (`mp3, wav, m4a, flac, ogg`), up to **2 GB**.
- **Transcribe** — Whisper locked to Urdu, producing timed segments. Runs on Groq's hosted
  `whisper-large-v3-turbo` by default, with automatic fallback to a local model.
- **Transliterate** — a fine-tuned M2M100 pipeline (below) turns each Urdu segment into Roman Urdu.
  This is automatic; there is no "now transliterate" button, and the subtitle project creates itself.
- **Edit** — a three-panel editor: video preview with a live caption overlay, a searchable
  auto-scrolling segment list, and a detail pane showing **editable Roman Urdu (LTR)** beside
  **read-only Urdu (RTL)**. 50-level undo/redo, auto-save every 30 s, keyboard shortcuts
  (`Ctrl+Z` / `Ctrl+Y` / `Ctrl+S`, space to play/pause), and a one-click "fix overlaps".
- **Watch live** — for long files, an escape hatch out of the wait: the realtime viewer streams
  captions over SSE as each 30-second chunk finishes and plays the video while the rest is still
  processing. Offered from the upload dialog as "Skip wait — Watch with Live Subtitles".
- **Export** — SRT, WebVTT, plain text, or the original **video with captions attached** —
  burned in (`hardsub`) or as a toggleable track (`softsub`).
- **Feedback** — 1–5 star rating plus an optional comment, stored in Postgres.

### Segment rules enforced by the backend

500 characters max per segment · 0.5–7 s duration · 0.1 s minimum gap between segments.
Timings display as `HH:MM:SS,mmm`.

### Deliberately absent

No caption styling, no language picker (only Urdu has a romanization path), no progress percentage
for video export (rendering is synchronous), and no background jobs — long operations hold their screen.

---

## The transliteration pipeline

Each Urdu segment from Whisper passes through seven layers before it reaches the client:

1. **Loanword & name detection** (`app/services/loanword_processor.py`) — greedy longest-match up to
   bigrams, with Urdu suffix stripping, against curated dictionaries of **1,041 English loanwords**
   (`app/data/loanword_dict.json`) and **189 Pakistani names** (`app/data/names_dict.json`). Matches
   bypass the model so `ہسپتال` comes out as `hospital`, spelled the way a reader expects.
   Gated by `ENABLE_LOANWORD_DICT` (off by default).
2. **Urdu normalization** (`app/services/urdu_preprocessor.py`) — folds Arabic presentation forms
   (`ﮨﮯ` → `ہے`), normalizes combine forms, strips stray diacritics via `urduhack`, so the model sees
   canonical script.
3. **M2M100 transliteration** (`app/services/transliteration.py`) — the fine-tuned `m2m100_ur_to_rur`
   model with a custom Roman Urdu target token (`forced_bos_token_id=128105`), beam width 4.
4. **Reconstruction** — the bypassed loanwords and names are reinserted at their original positions.
5. **Fuzzy post-process** — `rapidfuzz` snaps mangled English-looking words back to known dictionary
   entries (score ≥ 80).
6. **Claude refinement** *(optional)* (`app/services/llm_refiner.py`) — sends `(urdu, roman)` pairs to
   Claude Haiku 4.5 for polish. Purely additive: every failure path (API error, parse failure, length
   mismatch, missing dependency) logs one `WARNING` and returns the raw M2M100 output unchanged.
7. **Segment assembly** — timed segments, SRT/VTT formatting, subtitle project creation.

Every refine call is logged with a `Claude refiner:` prefix — grep for it to see `SKIPPED` (with
reason), `CALLING`, `SUCCESS` (with token usage and a before/after sample), or `FAILED`.

**Every layer degrades gracefully.** If refinement is unavailable you get layer 5's output; if a
hosted model is down it falls back to local. The user always gets a result.

---

## Where the models run

Two independent backend switches, plus one master override:

| Setting | Options | Default | Behaviour |
|---|---|---|---|
| `WHISPER_BACKEND` | `groq` · `faster` · `openai` | `groq` | `groq` = hosted `whisper-large-v3-turbo` (fastest, needs `GROQ_API_KEY`), auto-falls back to local `faster-whisper` on any error, no network, no credit, or oversized file. `faster` = local CTranslate2 int8 (offline, low RAM). `openai` = local `openai-whisper`. |
| `TRANSLITERATION_BACKEND` | `modal` · `transformers` | `modal` | `modal` = per-second T4 GPU service (`modal_app/m2m100_service.py`), scale-to-zero so there's no idle cost; falls back to the local path on any error or missing URL. `transformers` = local fp32 model. |
| `OFFLINE_MODE` | `true` · `false` | `false` | **One-line demo switch.** `true` forces the *whole* pipeline local (Whisper → `faster-whisper`, M2M100 → `transformers`) regardless of the two settings above. Flip it before a presentation so flaky wifi can't break anything. |

Deploying the Modal GPU service is documented in the header of `modal_app/m2m100_service.py`
(push the model to a private HF repo → `modal secret create` → `modal deploy`).

---

## Realtime streaming

`app/services/chunker_service.py` + `app/services/session_manager.py` back the "watch while it
processes" path:

- Audio is sliced into **30-second chunks with 2 seconds of overlap** (28 s advance per chunk).
- Playback begins once **three chunks are buffered**; captions then appear as each chunk finishes.
- Seeking forward **reprioritizes** the chunks around the seek target so they jump the queue.
- Phases surfaced to the client: `connecting → buffering → streaming → complete`.

Events arrive over SSE at `GET /realtime/stream/{file_id}` as `chunk_ready`, `buffer_ready`, and
`stream_complete`.

---

## Captioned-video export

`app/services/video_export.py`, exposed at `GET /subtitles/{subtitle_id}/export-video?mode=`:

- **`hardsub`** — captions burned into the pixels via an FFmpeg re-encode (`libx264` + AAC). Plays
  everywhere including social platforms; slow, because it re-encodes.
- **`softsub`** — captions muxed into the MP4 as a toggleable `mov_text` track by stream copy
  (no re-encode), so it is near-instant and the viewer can switch captions off.

Captions use each segment's Roman Urdu text, falling back to native Urdu only where a segment has no
Roman version, and reuse the same `format_as_srt` formatter as the text exports. Only video sources
are eligible — the endpoint returns `400` for audio-only files and `404` if the source video is no
longer on disk. Rendering is synchronous, bounded by a 30-minute FFmpeg timeout, and the temporary
SRT plus output file are cleaned up on every path. Output is always MP4.

---

## Audio enhancement

When `ENABLE_AUDIO_ENHANCE=true` (the default), the extracted 16 kHz mono WAV is run through a
conservative FFmpeg filter chain *before* ASR sees it: `highpass=f=80` (rumble/handling noise) →
`afftdn=nf=-25` (broadband denoise) → `dynaudnorm` (level the quiet parts). It is applied in
`extract_audio`, so both the batch path and the realtime path (which slices chunks from that same
WAV) receive cleaned audio. Optional stronger neural denoise via RNNoise (`arnndn`) is available
behind `AUDIO_ENHANCE_USE_RNNOISE` + `AUDIO_RNNOISE_MODEL`, and transparently falls back to `afftdn`
when the model file is missing.

---

## Repository layout

```
RomaSub.Ai/
├── app/                          # FastAPI backend
│   ├── main.py                   # App entry point, CORS, routers, /health
│   ├── config.py                 # Pydantic settings (all env vars)
│   ├── database.py               # SQLAlchemy engine + init_db()
│   ├── data/                     # Loanword + names dictionaries, runtime JSON state
│   ├── models/                   # SQLAlchemy models (user, media, feedback)
│   ├── repositories/             # DB access layer
│   ├── routers/                  # auth, user, media, asr, transliteration,
│   │                             #   subtitle, realtime, feedback
│   ├── schemas/                  # Pydantic request/response schemas
│   ├── services/                 # asr, transliteration, loanword_processor,
│   │                             #   urdu_preprocessor, llm_refiner, subtitle,
│   │                             #   video_export, chunker, session_manager,
│   │                             #   media, auth, email
│   └── utils/security.py         # Password hashing, JWT
├── FrontEnd/                     # Flutter client (see FrontEnd/CLAUDE.md)
│   └── lib/
│       ├── core/                 # Theme, design tokens, routes, constants, utils
│       ├── models/               # Data models
│       ├── providers/            # Riverpod state (auth, upload, editor, realtime…)
│       ├── screens/              # Splash, auth, dashboard, projects, exports,
│       │                         #   feedback, settings, editor, realtime viewer
│       ├── services/             # API client + per-domain services
│       └── widgets/              # Shell, sidebar, editor panels, cards, dialogs
├── modal_app/m2m100_service.py   # Modal GPU transliteration service
├── models/                       # Fine-tuned M2M100 weights (gitignored — see SETUP.md §3)
├── demo/demo_ui.py               # Streamlit smoke-test UI for the API
├── scripts/model_eval.py         # BLEU/chrF/WER/CER evaluation harness
├── eval_results/                 # Recorded evaluation runs (JSON + prediction CSVs)
├── tests/                        # pytest suite (44 tests)
├── Documentation/                # SRS, SDD, product overview, diagrams
├── Screenshots/
├── Dockerfile / docker-compose.yml
├── SETUP.md                      # Full local setup guide
└── .env.example
```

---

## Quick start

> **Before you start:** the fine-tuned M2M100 model (~1.9 GB) is **gitignored** and not in the repo.
> See [SETUP.md §3](SETUP.md) for how to obtain and place it — without it the transliteration
> endpoints will fail to load.

**Prerequisites:** Python 3.11, PostgreSQL 15+, FFmpeg, and (for the client) Flutter 3.8+.

### Backend

```bash
python3.11 -m venv venv && source venv/bin/activate    # Windows: venv\Scripts\activate
pip install -r requirements.txt

sudo -u postgres psql -c "CREATE DATABASE romasub_ai;"  # tables auto-create on first run

cp .env.example .env      # then fill in DATABASE_URL, SECRET_KEY, and any API keys
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger UI: <http://localhost:8000/docs> · Health check: `curl http://localhost:8000/health`

### Flutter client

```bash
cd FrontEnd
flutter pub get
flutter run -d linux                                    # or -d windows / -d macos
```

Android, iOS and web project scaffolding exists, but the `media_kit` video libraries are only bundled
for the three desktop platforms — the player will not work elsewhere without adding them.

The client defaults to `http://localhost:8000`. Point it elsewhere at build time:

```bash
flutter run --dart-define=BASE_URL=http://192.168.1.10:8000
```

### Docker (backend + Postgres)

```bash
cp .env.docker .env
docker compose up --build
```

Named volumes keep uploaded media (`media_data`), runtime JSON state (`app_data`), the database
(`postgres_data`), and Whisper weights (`whisper_cache`) alive across redeploys. `./models` is
mounted in from the host. `docker compose down -v` wipes everything.

### Streamlit demo UI (optional API smoke test)

```bash
streamlit run demo/demo_ui.py       # http://localhost:8501
```

Full walkthrough, troubleshooting table, and data-persistence notes: **[SETUP.md](SETUP.md)**.

---

## Configuration

All settings live in `.env` (see `.env.example` for the annotated version). The ones worth knowing:

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/romasub_ai` | Postgres connection string. |
| `SECRET_KEY` | *(placeholder — change it)* | JWT signing key. |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | Token lifetime (24 h, no refresh). |
| `WHISPER_BACKEND` | `groq` | `groq` · `faster` · `openai` — see [Where the models run](#where-the-models-run). |
| `WHISPER_MODEL` | `medium` | Local model for the `faster`/`openai` backends and the Groq fallback. |
| `WHISPER_COMPUTE_TYPE` | `int8` | `faster-whisper` CPU quantization. |
| `GROQ_API_KEY` / `GROQ_MODEL` | *(empty)* / `whisper-large-v3-turbo` | Required for the `groq` backend. |
| `TRANSLITERATION_BACKEND` | `modal` | `modal` · `transformers`. |
| `MODAL_ENDPOINT_URL` / `MODAL_AUTH_TOKEN` | *(empty)* | Required for the `modal` backend. |
| `OFFLINE_MODE` | `false` | Master switch — forces the whole pipeline local. |
| `M2M100_MODEL_PATH` / `M2M100_TOKENIZER_PATH` | `models/m2m100_ur_to_rur` / `models/m2m100_tokenizer` | Local model paths. |
| `TRANSLITERATION_DEVICE` | `auto` | `auto` picks CUDA when available, else CPU. |
| `ENABLE_LOANWORD_DICT` | `false` | Loanword/name substitution around M2M100. |
| `ENABLE_LLM_REFINE` | `true` | Claude polish pass over M2M100 output. |
| `ANTHROPIC_API_KEY` | *(empty)* | Required when `ENABLE_LLM_REFINE=true`; the account needs credit. |
| `CLAUDE_REFINE_MODEL` | `claude-haiku-4-5` | Override for higher quality at higher cost. |
| `ENABLE_AUDIO_ENHANCE` | `true` | Pre-ASR FFmpeg clean-up. |
| `AUDIO_ENHANCE_USE_RNNOISE` / `AUDIO_RNNOISE_MODEL` | `false` / *(empty)* | Optional RNNoise denoise. |
| `ENABLE_DIACRITICS` | `false` | Reserved stub for a future Urdu diacritizer; currently a no-op (logs a warning when `true`). |
| `MAX_FILE_SIZE_MB` | `2048` | Upload cap. |
| `MEDIA_UPLOAD_DIR` | `<repo>/uploads/media` | Uploaded media. Must be durable — "recents" projects point at it. |
| `STATE_DIR` | `<repo>/app/data` | Runtime JSON state (`subtitle_state.json`, `file_registry.json`). Kept separate from the image-baked dictionaries in Docker. |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | *(empty)* | Google sign-in. |
| `BREVO_API_KEY` / `BREVO_SENDER_EMAIL` / `BREVO_SENDER_NAME` | *(empty)* / `noreply@romasub.me` / `RomaSub.AI` | Transactional email for OTPs. |

---

## API reference

Interactive docs at `/docs`. `GET /` returns API metadata; `GET /health` reports model and device
configuration.

### Authentication — `/auth`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/register` | Create an account (sends a verification OTP) |
| `POST` | `/auth/login` | OAuth2 form login (Swagger-compatible) |
| `POST` | `/auth/login/json` | JSON login — what the Flutter client uses |
| `POST` | `/auth/google` | Google sign-in with an ID token (mobile/web) |
| `POST` | `/auth/google/code` | Google sign-in with an authorization code (desktop) |
| `POST` | `/auth/verify-email` | Verify the 6-digit OTP — returns a token, logging the user straight in |
| `POST` | `/auth/resend-verification-otp` | Resend the verification code |
| `POST` | `/auth/forgot-password` | Request a password-reset OTP (deliberately generic response) |
| `POST` | `/auth/verify-otp` | Verify a reset OTP |
| `POST` | `/auth/reset-password` | Set a new password using the OTP |
| `POST` | `/auth/change-password` | Change password (authenticated) |
| `GET` | `/auth/me` | Current user |

Login returns **403** for an unverified account — the client must route the user to verification.

### Users — `/users`

| Method | Path | Purpose |
|---|---|---|
| `PUT` | `/users/profile` | Update first/last name |
| `POST` | `/users/profile-picture` | Upload a profile picture (max 5 MB) |
| `DELETE` | `/users/profile-picture` | Remove it |
| `GET` | `/users/me/details` | Full user details |

Uploaded pictures are served from the static `/uploads` mount.

### Media — `/media`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/media/upload` | Upload video/audio (authenticated) |
| `POST` | `/media/upload/anonymous` | Upload without auth |
| `GET` | `/media/{file_id}` | File info |
| `POST` | `/media/{file_id}/extract-audio` | Extract the 16 kHz mono track |
| `DELETE` | `/media/{file_id}` | Delete the file |
| `GET` | `/media/{file_id}/stream` | Range-request video streaming for the player |

### ASR — `/asr`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/asr/transcribe/{file_id}` | Transcribe, then auto-transliterate to Roman Urdu |
| `POST` | `/asr/transcribe/{file_id}/anonymous` | Same, without auth |
| `GET` | `/asr/result/{file_id}` | Transcription result |
| `GET` | `/asr/result/{file_id}/srt` | Quick SRT straight from the result |
| `GET` | `/asr/languages` | Supported languages |

### Transliteration — `/transliterate`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/transliterate/text` | Transliterate raw Urdu text (no file needed) |
| `POST` | `/transliterate/{file_id}` | Re-run transliteration over an existing transcription |
| `POST` | `/transliterate/{file_id}/anonymous` | Same, without auth |
| `GET` | `/transliterate/result/{file_id}` | Latest transliteration result |
| `GET` | `/transliterate/result/{file_id}/srt` | The same result as SRT |

### Subtitles — `/subtitles`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/subtitles/create/{file_id}` | Create a subtitle project from a transcription |
| `GET` | `/subtitles/{subtitle_id}` | Load a project |
| `PUT` | `/subtitles/{subtitle_id}/segments/{segment_id}` | Update one segment |
| `POST` | `/subtitles/{subtitle_id}/segments` | Add a segment |
| `DELETE` | `/subtitles/{subtitle_id}/segments/{segment_id}` | Delete a segment |
| `PUT` | `/subtitles/{subtitle_id}/bulk-update` | Save many segments at once (auto-save uses this) |
| `POST` | `/subtitles/{subtitle_id}/fix-overlaps` | Repair overlapping timings |
| `GET` | `/subtitles/{subtitle_id}/export?format=srt\|vtt\|txt` | Download as text |
| `GET` | `/subtitles/{subtitle_id}/export-video?mode=hardsub\|softsub` | Download the captioned MP4 |
| `GET` | `/subtitles/list/projects` | Recent projects |
| `GET` | `/subtitles/list/exports` | Export history |

### Realtime — `/realtime`

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/realtime/stream/{file_id}?language=ur` | SSE stream of `chunk_ready` / `buffer_ready` / `stream_complete` |
| `POST` | `/realtime/seek/{file_id}` | Reprioritize chunks around a seek target |
| `GET` | `/realtime/status/{file_id}` | Session progress |

### Feedback — `/feedback`

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/feedback/submit` | Rating 1–5 plus an optional comment (≤ 2000 chars) |
| `GET` | `/feedback/list` | All feedback with the average rating |

---

## Model evaluation

The transliteration model is scored against the `Mavkif/Roman-Urdu-Parl-split` test set with
`sacrebleu` (BLEU, chrF) and `jiwer` (WER, CER). Recorded runs live in `eval_results/` as JSON plus
per-sample prediction CSVs.

Latest run (`eval_m2m100_20260506T021939Z`) — 100 test samples, beam width 4, Claude refinement off
for determinism:

| Metric | Shipping default (dict off) | With `ENABLE_LOANWORD_DICT=true` |
|---|---|---|
| BLEU | **98.87** | 86.13 |
| Character BLEU | 99.12 | 94.51 |
| chrF | 99.05 | 93.06 |
| WER | **0.86 %** | 6.87 % |
| CER | **0.63 %** | 2.99 % |
| Exact match | **96.0 %** | 73.0 % |

The left column is what ships. With the dictionary off the pipeline is just urduhack normalization →
M2M100, which on this clean dataset scores identically to the bare model (confirmed by the separate
`…021253Z` run, where raw and pipeline metrics match to the decimal).

**Turning the loanword dictionary on costs ~13 BLEU here**, and that is the honest reason it defaults
to `false`. The layer rewrites loanwords to conventional English spellings (`ہسپتال` → `hospital`),
which is what a *caption reader* wants but not what this dataset's gold references contain — so the
benchmark penalizes it. The regression is partly a scoring artifact and partly unverified dictionary
content; until the entries are audited against real caption output rather than parallel-corpus text,
the flag stays off.

```bash
python scripts/model_eval.py -n 25          # run it yourself
```

Note that `scripts/model_eval.py` as it stands runs the **raw** model (no dictionary, no
normalization, no post-processing) and prints its metrics to stdout — it does not write into
`eval_results/`. The JSON files there were produced by a fuller harness that also ran pipeline mode.

---

## Tests

```bash
pytest tests -q        # 44 tests
```

The suite covers ASR backend selection and fallback, the transliteration backend switch, offline
mode, audio enhancement, the media registry and `STATE_DIR` handling, the media-info endpoint,
video/audio source detection, and captioned-video export.

---

## Documentation

| Document | Contents |
|---|---|
| [SETUP.md](SETUP.md) | Full local setup, Docker persistence, troubleshooting |
| [Documentation/PRODUCT_OVERVIEW.md](Documentation/PRODUCT_OVERVIEW.md) | Product brief: users, every screen, hard constraints, design direction |
| [Documentation/PROJECT_BRIEF.md](Documentation/PROJECT_BRIEF.md) | Project brief |
| [Documentation/PROJECT_SUMMARY.md](Documentation/PROJECT_SUMMARY.md) | Project summary |
| `Documentation/SRS.pdf`, `Documentation/SDD.pdf` | Formal requirements and design specifications |
| `Documentation/DIAGRAMS/` | Architecture, DFD, ERD, use-case, activity, state, deployment diagrams |
| [FrontEnd/CLAUDE.md](FrontEnd/CLAUDE.md) | Flutter architecture, folder conventions, state management |
| [UI_UX_AUDIT.md](UI_UX_AUDIT.md) | UI/UX audit notes |

---

## Technology

- **Backend** — FastAPI, Pydantic v2, SQLAlchemy, PostgreSQL 15+
- **ASR** — Groq-hosted Whisper `large-v3-turbo`; local `faster-whisper` (CTranslate2 int8) and
  `openai-whisper` as fallbacks
- **Transliteration** — fine-tuned M2M100 (`facebook/m2m100_418M` base) via Hugging Face
  `transformers`, optionally served from a Modal T4 GPU
- **Urdu normalization** — `urduhack` (leaf import, so TensorFlow is not needed at runtime)
- **Refinement** — Anthropic Claude API (Haiku 4.5 by default)
- **Fuzzy matching** — `rapidfuzz`
- **Media** — FFmpeg (`static_ffmpeg`), `pydub`, `ffmpeg-python` — also drives audio enhancement and
  the hardsub/softsub video export
- **Email** — Brevo transactional API for OTPs
- **Client** — Flutter 3.8+, Riverpod, Dio, `media_kit` (desktop video), `flutter_secure_storage`
- **Evaluation** — `sacrebleu`, `jiwer`, `datasets`

---

## Team

Final Year Project — BS Software Engineering (2022–2026)
**COMSATS University Islamabad, Abbottabad Campus**

- Muttayyab Abdurrehman — CIIT/FA22-BSE-046/ATD
- Muhammad Hashir — CIIT/FA22-BSE-031/ATD
- Muneeb Khan — CIIT/FA22-BSE-032/ATD

Supervisor: **Dr. Osman Khalid**

## License

MIT — see [FrontEnd/LICENSE](FrontEnd/LICENSE).
