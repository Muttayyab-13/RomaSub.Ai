# CLAUDE.md - Project Context for AI Assistance

## Project Overview

**RomaSub.AI** is a Roman Urdu Captions Generator - a desktop application that automatically generates Roman Urdu subtitles from Urdu speech in videos or audio files.

This is a **Final Year Project** for Bachelor of Software Engineering at COMSATS University Islamabad, Abbottabad Campus (2022-2026).

### Team Members
- Muttayyab Abdurrehman (CIIT/FA22-BSE-046/ATD) - AI & Model Development
- Muhammad Hashir (CIIT/FA22-BSE-031/ATD) - Backend & System Integration
- Muneeb Khan (CIIT/FA22-BSE-032/ATD) - Frontend Development

### Supervisor
- Dr. Osman Khalid

---

## Technical Stack

### Backend (Current - Python/FastAPI)
- **Framework:** FastAPI 0.110+
- **Database:** PostgreSQL 15+
- **ORM:** SQLAlchemy 2.0
- **Authentication:** JWT (python-jose), bcrypt, Google OAuth
- **ASR:** OpenAI Whisper (small model)
- **Audio Processing:** FFmpeg, pydub
- **Email:** Brevo transactional API (REST via `requests`)

### Frontend (Planned - Flutter)
- Flutter 3.10+ for cross-platform desktop (Windows, macOS)
- Will connect to this FastAPI backend

---

## Project Structure

```
romasub_ai/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Environment configuration (pydantic-settings)
│   ├── database.py          # SQLAlchemy engine and session
│   ├── models/
│   │   ├── __init__.py
│   │   └── user.py          # User and OTPRecord SQLAlchemy models
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── user.py          # Pydantic request/response schemas
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py          # Authentication endpoints (/auth/*)
│   │   ├── media.py         # File upload endpoints (/media/*)
│   │   └── asr.py           # Transcription endpoints (/asr/*)
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py  # Authentication business logic
│   │   ├── email_service.py # Brevo OTP email service (REST)
│   │   ├── media_service.py # File upload and audio extraction
│   │   └── asr_service.py   # Whisper ASR transcription
│   └── utils/
│       ├── __init__.py
│       └── security.py      # Password hashing, JWT tokens, OTP generation
├── demo/
│   └── demo_ui.py           # Streamlit demo UI (temporary, for testing)
├── requirements.txt
├── .env.example
├── .env                     # Local environment variables (not in git)
├── README.md
├── SETUP_GUIDE.md
└── CLAUDE.md                # This file
```

---

## Current Implementation Status

### ✅ Module 1: User Authentication (Complete)
- [x] User registration (first_name, last_name, email, password)
- [x] User login (email/password)
- [x] Google OAuth authentication
- [x] Forgot password (OTP via email)
- [x] Verify OTP
- [x] Reset password with OTP
- [x] Change password (authenticated)
- [x] JWT token authentication
- [x] Get current user info

### ✅ Module 2: Video/Audio Input Handler (Complete)
- [x] File upload (video: MP4, AVI, MKV, MOV, WEBM)
- [x] File upload (audio: MP3, WAV, M4A, FLAC, OGG)
- [x] File size validation (max 500MB)
- [x] Audio extraction from video (FFmpeg)
- [x] Temporary file storage
- [x] File info retrieval
- [x] File deletion

### ✅ Module 3: Automated Speech Recognition (Complete)
- [x] Whisper model loading (lazy load)
- [x] Audio transcription with timestamps
- [x] Urdu language support
- [x] Console output of results
- [x] API response with segments
- [x] SRT format export

### 🔲 Module 4: Dataset Generation (Not Started)
- [ ] Collect user-edited subtitles
- [ ] Anonymize data
- [ ] Format as training samples

### 🔲 Module 5: Fine-Tuning & Training (Not Started)
- [ ] M2M100 model fine-tuning
- [ ] Training pipeline
- [ ] Model versioning

### 🔲 Module 6: Transliteration Engine (Not Started)
- [ ] Urdu to Roman Urdu conversion
- [ ] M2M100 integration
- [ ] Context-aware transliteration

### 🔲 Module 7: Real-Time Subtitle Display (Not Started)
- [ ] Video playback with subtitles
- [ ] Timestamp synchronization

### 🔲 Module 8: Subtitle Editor (Not Started)
- [ ] Edit subtitle text
- [ ] Adjust timing
- [ ] Add/delete segments

### 🔲 Module 9: Export & File Management (Partial)
- [x] SRT format export
- [ ] VTT format export
- [ ] TXT format export
- [ ] Project management

### 🔲 Module 10: Feedback System (Not Started)
- [ ] User feedback collection
- [ ] Training data contribution

---

## API Endpoints Reference

### Authentication (`/auth`)
| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| POST | `/auth/register` | No | Register new user |
| POST | `/auth/login` | No | Login (OAuth2 form) |
| POST | `/auth/login/json` | No | Login (JSON body) |
| POST | `/auth/google` | No | Google OAuth |
| POST | `/auth/forgot-password` | No | Request OTP |
| POST | `/auth/verify-otp` | No | Verify OTP |
| POST | `/auth/reset-password` | No | Reset password |
| POST | `/auth/change-password` | Yes | Change password |
| GET | `/auth/me` | Yes | Get current user |

### Media (`/media`)
| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| POST | `/media/upload` | Yes | Upload file |
| POST | `/media/upload/anonymous` | No | Upload (testing) |
| GET | `/media/{file_id}` | No | Get file info |
| POST | `/media/{file_id}/extract-audio` | No | Extract audio |
| DELETE | `/media/{file_id}` | No | Delete file |

### ASR (`/asr`)
| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| POST | `/asr/transcribe/{file_id}` | Yes | Transcribe file |
| POST | `/asr/transcribe/{file_id}/anonymous` | No | Transcribe (testing) |
| GET | `/asr/result/{file_id}` | No | Get result |
| GET | `/asr/result/{file_id}/srt` | No | Get as SRT |
| GET | `/asr/languages` | No | List languages |

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255),  -- NULL for Google-only users
    google_id VARCHAR(255) UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);
```

### OTP Records Table
```sql
CREATE TABLE otp_records (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    otp_code VARCHAR(6) NOT NULL,
    otp_type VARCHAR(50) NOT NULL,  -- 'password_reset', 'email_verify'
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

---

## Environment Variables

```env
# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/romasub_ai

# JWT
SECRET_KEY=your-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Google OAuth (optional)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# Brevo (optional — transactional email)
BREVO_API_KEY=
BREVO_SENDER_EMAIL=noreply@domain.com
BREVO_SENDER_NAME=RomaSub.AI

# Whisper
WHISPER_MODEL=small

# File Upload
MAX_FILE_SIZE_MB=500
ALLOWED_VIDEO_EXTENSIONS=mp4,avi,mkv,mov,webm
ALLOWED_AUDIO_EXTENSIONS=mp3,wav,m4a,flac,ogg
```

---

## Common Commands

```bash
# Start development server
uvicorn app.main:app --reload --port 8000

# Run demo UI
streamlit run demo/demo_ui.py

# Install dependencies
pip install -r requirements.txt

# Create database (PostgreSQL)
CREATE DATABASE romasub_ai;
```

---

## Key Design Decisions

1. **Temporary File Storage**: Files are stored in `/tmp/romasub_uploads/` for simplicity. In production, consider cloud storage.

2. **In-Memory Registries**: `MediaService._file_registry` and `ASRService._transcription_results` are in-memory dicts. For production, store in database.

3. **Anonymous Endpoints**: `/anonymous` endpoints exist for testing without authentication. Remove or secure in production.

4. **Whisper Model**: Using "small" model for balance of speed and accuracy. Can be changed via `WHISPER_MODEL` env var.

5. **OTP via Console**: If Brevo is not configured, OTPs are printed to console for testing.

---

## Future Improvements

1. Add database storage for uploaded files metadata
2. Implement background task queue (Celery) for long transcriptions
3. Add WebSocket for real-time transcription progress
4. Implement rate limiting
5. Add comprehensive logging
6. Add unit and integration tests
7. Docker containerization
8. CI/CD pipeline

---

## Useful Context for AI Assistance

When helping with this project:

1. **Framework**: FastAPI with async/await patterns
2. **Validation**: Pydantic v2 schemas with `model_validate()`
3. **Database**: SQLAlchemy 2.0 with `Session` dependency injection
4. **Auth**: JWT bearer tokens via `OAuth2PasswordBearer`
5. **File Handling**: Files uploaded via `UploadFile`, processed with FFmpeg
6. **ASR**: OpenAI Whisper loaded globally, transcribe returns segments with timestamps

The Flutter frontend will be developed separately and will consume this REST API.