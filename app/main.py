"""
RomaSub.AI - Main Application Entry Point

Roman Urdu Captions Generator Backend API
Version 1.0

Authors:
- Muttayyab Abdurrehman (CIIT/FA22-BSE-046/ATD)
- Muhammad Hashir (CIIT/FA22-BSE-031/ATD)
- Muneeb Khan (CIIT/FA22-BSE-032/ATD)

Supervisor: Dr. Osman Khalid
COMSATS University Islamabad, Abbottabad Campus
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
import sys

from app.database import init_db
from app.routers import auth_router, media_router, asr_router
from app.config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown events.
    """
    # Startup
    logger.info("="*60)
    logger.info("Starting RomaSub.AI Backend Server...")
    logger.info("="*60)
    
    # Initialize database tables
    try:
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}")
        logger.warning("Make sure PostgreSQL is running and database exists")
    
    # Log configuration
    logger.info(f"Whisper Model: {settings.whisper_model}")
    logger.info(f"Max File Size: {settings.max_file_size_mb}MB")
    logger.info(f"Temp Upload Dir: {settings.temp_upload_dir}")
    
    logger.info("="*60)
    logger.info("Server ready! API docs at: http://localhost:8000/docs")
    logger.info("="*60)
    
    yield
    
    # Shutdown
    logger.info("Shutting down RomaSub.AI Backend Server...")


# Create FastAPI application
app = FastAPI(
    title="RomaSub.AI API",
    description="""
    ## Roman Urdu Captions Generator API
    
    RomaSub.AI is a desktop application that automatically generates Roman Urdu subtitles 
    from Urdu speech in videos or audio files.
    
    ### Features:
    - **User Authentication**: Register, login, Google OAuth, password reset
    - **Media Upload**: Upload video/audio files for processing
    - **ASR Processing**: Transcribe Urdu speech using OpenAI Whisper
    
    ### Modules:
    - **Module 1**: User Authentication & Registration
    - **Module 2**: Video/Audio Input Handler
    - **Module 3**: Automated Speech Recognition (ASR)
    
    ---
    
    **COMSATS University Islamabad, Abbottabad Campus**
    
    Final Year Project - Bachelor of Software Engineering (2022-2026)
    """,
    version="1.0.0",
    contact={
        "name": "RomaSub.AI Team",
        "email": "muttayyab@example.com"
    },
    license_info={
        "name": "MIT License"
    },
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify allowed origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions globally"""
    logger.error(f"Unexpected error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "message": "An unexpected error occurred",
            "detail": str(exc)
        }
    )


# Include routers
app.include_router(auth_router)
app.include_router(media_router)
app.include_router(asr_router)


# Root endpoint
@app.get("/", tags=["Root"])
async def root():
    """
    Root endpoint - API health check and information.
    """
    return {
        "name": "RomaSub.AI API",
        "version": "1.0.0",
        "description": "Roman Urdu Captions Generator",
        "status": "running",
        "documentation": "/docs",
        "modules": {
            "auth": "User authentication and registration",
            "media": "Video/audio file upload and processing",
            "asr": "Automatic speech recognition with Whisper"
        }
    }


@app.get("/health", tags=["Root"])
async def health_check():
    """
    Health check endpoint for monitoring.
    """
    return {
        "status": "healthy",
        "database": "connected",
        "whisper_model": settings.whisper_model
    }


# Run with: uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
