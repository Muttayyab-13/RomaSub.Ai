"""
Services for RomaSub.AI
Business logic layer with pure functional modules

Pure functional modules (use module imports):
    from app.services import auth
    from app.services import media
    from app.services import asr
    from app.services import email

Then use:
    auth.register_user(db, user_data)
    media.save_upload_file(file)
    asr.transcribe_audio(file_id, language)
    email.send_otp_email(to_email, to_name, otp)
"""

__all__ = []
