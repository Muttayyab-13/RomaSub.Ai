# RomaSub.AI Backend

Roman Urdu Captions Generator - Backend API

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
- `POST /auth/google` - Google OAuth login
- `POST /auth/forgot-password` - Request password reset OTP
- `POST /auth/verify-otp` - Verify OTP
- `POST /auth/reset-password` - Reset password with OTP
- `POST /auth/change-password` - Change password (authenticated)

### Media (Module 2)
- `POST /media/upload` - Upload video/audio file
- `GET /media/{file_id}` - Get file info

### ASR (Module 3)
- `POST /asr/transcribe/{file_id}` - Transcribe uploaded file
- `GET /asr/result/{task_id}` - Get transcription result

## Technologies Used

- FastAPI 0.110+
- PostgreSQL 15+
- OpenAI Whisper (small model)
- FFmpeg (for audio extraction)
- MailerSend (for email OTP)
