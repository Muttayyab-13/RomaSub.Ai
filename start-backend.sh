#!/usr/bin/env bash
# RomaSub.AI — start the backend for a demo/presentation.
# Uses the local venv (fast Groq + Modal path from .env). No Docker needed.
set -e
cd "$(dirname "$0")"

# Fail early if the DB isn't up (it lives on localhost:5432).
if ! (exec 3<>/dev/tcp/localhost/5432) 2>/dev/null; then
  echo "!! Postgres is NOT listening on localhost:5432 — start it first." >&2
  exit 1
fi
exec 3<&- 2>/dev/null || true

echo "Starting RomaSub.AI backend on http://localhost:8000  (Ctrl+C to stop)"
exec ./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
