# API Routers Package
from app.routers.auth import router as auth_router
from app.routers.media import router as media_router
from app.routers.asr import router as asr_router
from app.routers.user import router as user_router
from app.routers.transliteration import router as transliteration_router

__all__ = ["auth_router", "media_router", "asr_router", "user_router", "transliteration_router"]
