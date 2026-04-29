# RomaSub.AI Backend

Roman Urdu Captions Generator — Backend API.

Pipeline: Urdu audio → Whisper ASR → loanword/name detection → urduhack normalization → fine-tuned M2M100 (Urdu→Roman Urdu) → loanword reconstruction → fuzzy postprocess → optional Claude Haiku 4.5 refinement → SRT/VTT/streaming output.

## Project Structure

```
romasub_ai/
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI application entry point
│   ├── config.py               # Configuration settings
│   ├── database.py             # Database connection
│   ├── models/
│   │   ├── __init__.py
│   │   └── user.py             # User database model
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── user.py             # Pydantic schemas
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py             # Authentication routes
│   │   ├── media.py            # Video/Audio upload routes
│   │   └── asr.py              # ASR processing routes
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py     # Authentication logic
│   │   ├── email_service.py    # Email OTP service
│   │   ├── media_service.py    # Media processing service
│   │   └── asr_service.py      # Whisper ASR service
│   └── utils/
│       ├── __init__.py
│       └── security.py         # Password hashing, JWT
├── demo/
│   └── demo_ui.py              # Simple Streamlit demo UI
├── requirements.txt
├── .env.example
└── README.md
```

## Setup Instructions

### 1. Create Virtual Environment

```bash
cd romasub_ai
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Setup PostgreSQL Database

```sql
-- Run in PostgreSQL
CREATE DATABASE romasub_ai;
```

### 4. Configure Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

Transliteration-related settings (all optional, off by default):

| Variable | Default | Purpose |
|---|---|---|
| `ENABLE_DIACRITICS` | `false` | Reserved stub for a future Urdu diacritizer; currently a no-op (logs a warning when `true`). |
| `ENABLE_LLM_REFINE` | `false` | When `true`, the M2M100 output for each chunk is passed to Claude for polishing. Falls back silently to raw M2M100 on any failure. |
| `CLAUDE_REFINE_MODEL` | `claude-haiku-4-5` | Anthropic model ID used by the refiner. Override to `claude-sonnet-4-6` for higher quality at ~3× cost. |
| `ANTHROPIC_API_KEY` | *(empty)* | Required when `ENABLE_LLM_REFINE=true`. The account must have non-zero credit. |

### 5. Run Database Migrations

The tables will be created automatically on first run.

### 6. Run the Application

```bash
# Start FastAPI server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 7. Run Demo UI (Optional)

```bash
streamlit run demo/demo_ui.py
```

## API Endpoints

### Authentication (Module 1)
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login with email/password
- `POST /auth/google` - Google OAuth login (mobile/web with ID token)
- `POST /auth/google/code` - Google OAuth login (desktop with authorization code)
- `POST /auth/forgot-password` - Request password reset OTP
- `POST /auth/verify-otp` - Verify OTP
- `POST /auth/reset-password` - Reset password with OTP
- `POST /auth/change-password` - Change password (authenticated)

**Google OAuth Setup**: See [GOOGLE_OAUTH_SETUP.md](./GOOGLE_OAUTH_SETUP.md) for detailed instructions or [GOOGLE_OAUTH_QUICKSTART.md](./GOOGLE_OAUTH_QUICKSTART.md) for quick reference.

### Media (Module 2)
- `POST /media/upload` - Upload video/audio file
- `GET /media/{file_id}` - Get file info

### ASR (Module 3)
- `POST /asr/transcribe/{file_id}` - Transcribe uploaded file (auto-transliterates to Roman Urdu)
- `GET /asr/result/{task_id}` - Get transcription result

### Transliteration (Module 6)
- `POST /transliteration/{file_id}` - Re-run Urdu→Roman Urdu transliteration on an existing transcription
- `GET /transliteration/{file_id}` - Get the latest transliteration result

### Realtime (SSE streaming)
- `GET /realtime/stream/{file_id}?language=ur` - Server-Sent-Events stream of `chunk_ready` / `buffer_ready` / `stream_complete` events as each audio chunk is ASR'd, transliterated, and (if enabled) refined.

### Subtitles
- `GET /subtitle/{file_id}/srt` - Download SRT subtitle file
- `GET /subtitle/{file_id}/vtt` - Download WebVTT subtitle file

## Transliteration Pipeline

Each Urdu audio segment from Whisper passes through the following layers before being emitted to the client:

1. **Loanword & name detection** (`app/services/loanword_processor.py`) — splits the segment into Urdu-only chunks and English loanwords/Pakistani names found in `app/data/loanword_dict.json` and `app/data/names_dict.json`. Loanwords are bypassed and reinserted at their original positions later.
2. **Urdu normalization** (`app/services/urdu_preprocessor.py`) — folds Arabic-presentation-form characters (`ﮨﮯ` → `ہے`), normalizes combine forms, and removes stray diacritics via `urduhack` so M2M100 sees a canonical script.
3. **M2M100 transliteration** (`app/services/transliteration.py`) — fine-tuned `m2m100_ur_to_rur` model produces draft Roman Urdu for each Urdu-only chunk.
4. **Reconstruction** — interleaves the transliterated chunks with the bypassed loanwords/names at the original positions.
5. **Fuzzy postprocess** — `rapidfuzz` snaps mangled English-looking words back to known dictionary entries (score ≥ 80).
6. **Claude refinement (optional)** (`app/services/llm_refiner.py`) — if `ENABLE_LLM_REFINE=true`, sends `(urdu, roman)` pairs to Claude Haiku 4.5 for polishing. Refine is purely additive: every failure path (API error, parse failure, length mismatch, missing dep) logs one `WARNING` and returns the raw M2M100 output unchanged.

Every refine call is logged with a `Claude refiner:` prefix — grep for it to see `SKIPPED` (with reason), `CALLING`, `SUCCESS` (with token usage and a before/after sample), or `FAILED` (with error type) on each chunk.

## Technologies Used

- **Web**: FastAPI 0.110+, Pydantic v2, PostgreSQL 15+
- **ASR**: OpenAI Whisper (medium model, configurable via `WHISPER_MODEL`)
- **Transliteration**: Fine-tuned M2M100 (`facebook/m2m100_418M`) via Hugging Face `transformers`
- **Urdu normalization**: `urduhack` (leaf import — no TensorFlow dependency at runtime)
- **Refinement**: Anthropic Claude API (Haiku 4.5 by default)
- **Fuzzy matching**: `rapidfuzz`
- **Media**: FFmpeg, `pydub`, `ffmpeg-python`
- **Email**: MailerSend (for OTP)
