# RomaSub.AI - Complete Setup Guide

## 📋 Prerequisites

Before starting, ensure you have the following installed:

1. **Python 3.10+** - Download from [python.org](https://www.python.org/downloads/)
2. **PostgreSQL 15+** - Download from [postgresql.org](https://www.postgresql.org/download/)
3. **FFmpeg** - Required for audio extraction
4. **Git** (optional) - For version control

### Installing FFmpeg

**Windows:**
```bash
# Using Chocolatey
choco install ffmpeg

# Or download from: https://ffmpeg.org/download.html
# Add to PATH after installation
```

**macOS:**
```bash
brew install ffmpeg
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install ffmpeg
```

---

## 🚀 Step-by-Step Setup

### Step 1: Extract the Project

Extract the `romasub_ai` folder to your desired location.

### Step 2: Create Virtual Environment

```bash
cd romasub_ai

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate

# macOS/Linux:
source venv/bin/activate
```

### Step 3: Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**Note:** Installing `openai-whisper` will also install PyTorch. This may take several minutes.

### Step 4: Setup PostgreSQL Database

1. Open PostgreSQL (pgAdmin or psql command line)

2. Create the database:
```sql
CREATE DATABASE romasub_ai;
```

3. Note your PostgreSQL credentials:
   - Host: `localhost`
   - Port: `5432`
   - Username: `postgres` (or your username)
   - Password: your password

### Step 5: Configure Environment Variables

1. Copy the example environment file:
```bash
# Windows:
copy .env.example .env

# macOS/Linux:
cp .env.example .env
```

2. Edit `.env` file with your settings:

```env
# Database Configuration
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/romasub_ai

# JWT Configuration (generate a secure random key)
SECRET_KEY=your-super-secret-key-change-this-to-random-string
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Google OAuth (optional - leave empty for now if not using)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# MailerSend Configuration (optional for testing)
MAILERSEND_API_KEY=
MAILERSEND_SENDER_EMAIL=noreply@yourdomain.com
MAILERSEND_SENDER_NAME=RomaSub.AI

# Whisper Configuration
WHISPER_MODEL=small

# File Upload Configuration
MAX_FILE_SIZE_MB=500
ALLOWED_VIDEO_EXTENSIONS=mp4,avi,mkv,mov,webm
ALLOWED_AUDIO_EXTENSIONS=mp3,wav,m4a,flac,ogg
```

### Step 6: Run the Server

```bash
# Make sure virtual environment is activated
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
INFO:     Started server process
INFO:     Waiting for application startup.
============================================================
Starting RomaSub.AI Backend Server...
============================================================
Database tables created successfully!
Whisper Model: small
============================================================
Server ready! API docs at: http://localhost:8000/docs
============================================================
```

### Step 7: Access the API

Open your browser and go to:
- **API Documentation:** http://localhost:8000/docs
- **Alternative Docs:** http://localhost:8000/redoc
- **Health Check:** http://localhost:8000/health

---

## 🧪 Testing the API

### Option 1: Using Swagger UI (Recommended)

1. Go to http://localhost:8000/docs
2. Test each endpoint directly in the browser

### Option 2: Using the Demo UI

```bash
# In a new terminal (with venv activated)
streamlit run demo/demo_ui.py
```

Open http://localhost:8501 in your browser.

### Option 3: Using cURL

**Register a user:**
```bash
curl -X POST "http://localhost:8000/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Muttayyab",
    "last_name": "Abdurrehman",
    "email": "muttayyab@example.com",
    "password": "SecurePass123",
    "confirm_password": "SecurePass123"
  }'
```

**Upload a file (without auth for testing):**
```bash
curl -X POST "http://localhost:8000/media/upload/anonymous" \
  -F "file=@/path/to/your/video.mp4"
```

**Transcribe (use file_id from upload response):**
```bash
curl -X POST "http://localhost:8000/asr/transcribe/YOUR_FILE_ID/anonymous" \
  -H "Content-Type: application/json" \
  -d '{"language": "ur"}'
```

---

## 📁 Project Structure

```
romasub_ai/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration settings
│   ├── database.py          # Database connection
│   ├── models/
│   │   ├── __init__.py
│   │   └── user.py          # User and OTP database models
│   ├── schemas/
│   │   ├── __init__.py
│   │   └── user.py          # Pydantic validation schemas
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py          # Authentication endpoints
│   │   ├── media.py         # File upload endpoints
│   │   └── asr.py           # Transcription endpoints
│   ├── services/
│   │   ├── __init__.py
│   │   ├── auth_service.py  # Authentication logic
│   │   ├── email_service.py # OTP email service
│   │   ├── media_service.py # File handling logic
│   │   └── asr_service.py   # Whisper ASR logic
│   └── utils/
│       ├── __init__.py
│       └── security.py      # JWT and password utilities
├── demo/
│   └── demo_ui.py           # Streamlit demo interface
├── requirements.txt
├── .env.example
├── .env                     # Your configuration (create this)
└── README.md
```

---

## 🔌 API Endpoints Summary

### Authentication (`/auth`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Register new user |
| POST | `/auth/login` | Login (OAuth2 form) |
| POST | `/auth/login/json` | Login (JSON body) |
| POST | `/auth/google` | Google OAuth login |
| POST | `/auth/forgot-password` | Request OTP |
| POST | `/auth/verify-otp` | Verify OTP |
| POST | `/auth/reset-password` | Reset with OTP |
| POST | `/auth/change-password` | Change password |
| GET | `/auth/me` | Get current user |

### Media (`/media`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/media/upload` | Upload file (auth) |
| POST | `/media/upload/anonymous` | Upload file (no auth) |
| GET | `/media/{file_id}` | Get file info |
| POST | `/media/{file_id}/extract-audio` | Extract audio |
| DELETE | `/media/{file_id}` | Delete file |

### ASR (`/asr`)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/asr/transcribe/{file_id}` | Transcribe (auth) |
| POST | `/asr/transcribe/{file_id}/anonymous` | Transcribe (no auth) |
| GET | `/asr/result/{file_id}` | Get transcription |
| GET | `/asr/result/{file_id}/srt` | Get as SRT format |
| GET | `/asr/languages` | List languages |

---

## ⚙️ Configuration Options

### Whisper Model Sizes

In `.env`, you can change `WHISPER_MODEL`:

| Model | Size | Speed | Accuracy |
|-------|------|-------|----------|
| tiny | ~40MB | Fastest | Basic |
| base | ~75MB | Fast | Good |
| small | ~250MB | Medium | Better |
| medium | ~770MB | Slow | High |
| large | ~1.5GB | Slowest | Best |

For development, `small` is recommended. For production, consider `medium` or `large`.

---

## 🔧 Troubleshooting

### Database Connection Error
```
sqlalchemy.exc.OperationalError: could not connect to server
```
**Solution:** Make sure PostgreSQL is running and credentials in `.env` are correct.

### FFmpeg Not Found
```
FileNotFoundError: FFmpeg not found
```
**Solution:** Install FFmpeg and ensure it's in your system PATH.

### Whisper Model Download Slow
First run will download the Whisper model. This is normal and only happens once.

### Out of Memory Error
If you get memory errors during transcription:
1. Use a smaller Whisper model (tiny or base)
2. Process shorter audio files
3. Increase system RAM

### Port Already in Use
```
ERROR: [Errno 48] Address already in use
```
**Solution:** Use a different port:
```bash
uvicorn app.main:app --reload --port 8001
```

---

## 📧 Setting Up MailerSend (Optional)

For password reset emails to work:

1. Create account at [mailersend.com](https://www.mailersend.com/)
2. Verify your domain
3. Get API key from dashboard
4. Add to `.env`:
```env
MAILERSEND_API_KEY=your-api-key
MAILERSEND_SENDER_EMAIL=noreply@yourdomain.com
```

**For testing without email:** OTP codes are printed to the console when email sending fails.

---

## 🔐 Setting Up Google OAuth (Optional)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable Google+ API
4. Create OAuth 2.0 credentials
5. Add to `.env`:
```env
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
```

---

## 🎯 Next Steps

After setup is complete:

1. Test all API endpoints using Swagger UI
2. Upload a sample Urdu audio/video file
3. Run transcription and verify output
4. Connect with Flutter frontend (Module 1-3 ready)

---

## 📞 Support

For issues or questions, contact the development team:
- Muttayyab Abdurrehman (CIIT/FA22-BSE-046/ATD)
- Muhammad Hashir (CIIT/FA22-BSE-031/ATD)
- Muneeb Khan (CIIT/FA22-BSE-032/ATD)

Supervisor: Dr. Osman Khalid
