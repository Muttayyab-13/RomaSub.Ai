"""
Services for RomaSub.AI
Business logic layer with pure functional modules

Pure functional modules (use module imports):
    from app.services import auth
    from app.services import media
    from app.services import asr

Then use:
    auth.register_user(db, user_data)
    media.save_upload_file(file)
    asr.transcribe_audio(file_id, language)

Class-based services (still available):
    from app.services.email_service import EmailService
"""

from app.services.email_service import EmailService

__all__ = ["EmailService"]
