# RomaSub.AI — Local Setup Guide

Backend (FastAPI + Whisper + fine-tuned M2M100) and optional Flutter frontend.

> **Heads-up before you start:** the fine-tuned M2M100 model (~1.9 GB) is **gitignored** and is not in the repo. Ask Muttayyab for the `models/` archive and place it as described in §3 — without it the transliteration endpoints will fail to load.

## 1. Prerequisites

Install before cloning:

| Tool | Version | Notes |
|---|---|---|
| Git | any recent | |
| Python | **3.11** (3.10 OK; 3.12+ may break `openai-whisper`) | |
| PostgreSQL | 15+ | local server, or use Docker (see §9) |
| FFmpeg | any recent | required by Whisper & `pydub` |
| Flutter SDK | 3.8+ | **only if** you'll run the mobile/web app |

Ubuntu/Debian one-liner for system deps:
```bash
sudo apt update && sudo apt install -y python3.11 python3.11-venv python3-pip postgresql ffmpeg git libpq-dev build-essential
```

macOS:
```bash
brew install python@3.11 postgresql@15 ffmpeg git
```

## 2. Clone

```bash
git clone git@github.com:Muttayyab-13/RomaSub.Ai.git
cd RomaSub.Ai
```
(Use the HTTPS URL `https://github.com/Muttayyab-13/RomaSub.Ai.git` if SSH isn't set up.)

## 3. Get the fine-tuned M2M100 model (NOT in the repo)

`models/` is gitignored. Ask Muttayyab for the model archive (~1.9 GB) and place it so you have:

```
RomaSub.Ai/
└── models/
    ├── m2m100_tokenizer/        # ~6 MB
    └── m2m100_ur_to_rur/        # ~1.9 GB  (config.json, model.safetensors, etc.)
```

Without these the `/asr/transcribe` and `/transliteration` endpoints will fail to load.

## 4. Python environment

```bash
python3.11 -m venv venv
source venv/bin/activate            # Windows: venv\Scripts\activate
pip install --upgrade pip
pip install -r requirements.txt
```

This pulls `torch`, `openai-whisper`, `transformers`, `urduhack`, `anthropic`, `fastapi`, `streamlit`, etc. First-time `torch` install is ~2 GB.

First Whisper run will auto-download the model (`small` by default, ~460 MB) into `~/.cache/whisper/`.

## 5. PostgreSQL database

Start Postgres, then:
```bash
sudo -u postgres psql -c "CREATE DATABASE romasub_ai;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'your_password';"
```
Tables are auto-created on first server start.

## 6. Environment variables

```bash
cp .env.example .env
```
Edit `.env`:

| Variable | Required? | Notes |
|---|---|---|
| `DATABASE_URL` | yes | e.g. `postgresql://postgres:your_password@localhost:5432/romasub_ai` |
| `SECRET_KEY` | yes | any long random string |
| `WHISPER_MODEL` | no | `small` (default), `medium`, or `large` (slower, more accurate) |
| `MAX_FILE_SIZE_MB` | no | default 2048 |
| `GOOGLE_CLIENT_ID` / `_SECRET` | no | only for Google login |
| `BREVO_API_KEY` | no | only if you need OTP password reset emails (get one at app.brevo.com/settings/keys/api) |
| `ENABLE_LLM_REFINE` | no | set `true` to polish output with Claude Haiku |
| `ANTHROPIC_API_KEY` | iff `ENABLE_LLM_REFINE=true` | account must have credit |
| `CLAUDE_REFINE_MODEL` | no | default `claude-haiku-4-5` |

## 7. Run the backend

```bash
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger UI at: `http://localhost:8000/docs`

Smoke test:
```bash
curl http://localhost:8000/health
```

## 8. Optional — Streamlit demo UI

In a second terminal:
```bash
source venv/bin/activate
streamlit run demo/demo_ui.py
```
Opens at `http://localhost:8501`.

## 9. Optional — Docker (skips §4–§5–§7)

```bash
cp .env.docker .env       # or copy your .env from §6
docker compose up --build
```
Postgres + backend on `localhost:8000`. Models still need to be in `./models/` (mounted into the container).

## 10. Optional — Flutter frontend

```bash
cd FrontEnd
flutter pub get
flutter run                # device/emulator picker, or: flutter run -d chrome
```
The app expects the backend at `http://localhost:8000` (or whatever is configured in `lib/`).

## 11. Quick end-to-end check

1. `POST /auth/register` (Swagger UI) → create a user
2. `POST /auth/login` → copy the JWT, click "Authorize" in Swagger
3. `POST /media/upload` → upload a short Urdu `.mp3` / `.mp4`
4. `POST /asr/transcribe/{file_id}` → returns a `task_id`
5. `GET /asr/result/{task_id}` → final Roman Urdu output
6. `GET /subtitle/{file_id}/srt` → downloadable subtitles

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ffmpeg not found` | install ffmpeg system-wide (§1) |
| `psycopg2` build fails | install `libpq-dev` and `build-essential` (§1) |
| `Could not load model models/m2m100_ur_to_rur` | model wasn't placed correctly (§3) |
| Whisper OOM on `large` | drop `WHISPER_MODEL` to `small` or `medium` |
| `urduhack` pulls TensorFlow | already pinned to leaf import; reinstall with `pip install --no-deps urduhack regex` |
| Claude refine logs `SKIPPED` | check `ENABLE_LLM_REFINE=true` and `ANTHROPIC_API_KEY` is set & has credit |
