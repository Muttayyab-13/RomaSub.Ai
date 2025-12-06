"""
Authentication Service for RomaSub.AI
Handles user registration, login, password reset, and Google OAuth
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple
from sqlalchemy.orm import Session

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from app.models.user import User, OTPRecord
from app.schemas.user import UserCreate, UserResponse
from app.repositories.user_repository import UserRepository
from app.utils.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    generate_otp
)
from app.services.email_service import email_service
from app.config import settings

import logging

logger = logging.getLogger(__name__)


class AuthService:
    """Service for handling all authentication operations"""

    # OTP validity duration in minutes
    OTP_VALIDITY_MINUTES = 15

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        """Get user by email address"""
        return UserRepository.get_by_email(db, email)

    @staticmethod
    def get_user_by_uuid(db: Session, uuid: str) -> Optional[User]:
        """Get user by UUID"""
        return UserRepository.get_by_uuid(db, uuid)

    @staticmethod
    def get_user_by_google_id(db: Session, google_id: str) -> Optional[User]:
        """Get user by Google ID"""
        return UserRepository.get_by_google_id(db, google_id)
    
    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> User:
        """
        Create a new user with email and password.

        Args:
            db: Database session
            user_data: User registration data

        Returns:
            Created User object
        """
        hashed_password = get_password_hash(user_data.password)

        user_dict = {
            "first_name": user_data.first_name,
            "last_name": user_data.last_name,
            "email": user_data.email.lower(),
            "hashed_password": hashed_password,
            "is_verified": False
        }

        db_user = UserRepository.create_user(db, user_dict)
        logger.info("Created new user: %s", db_user.email)
        return db_user
    
    @staticmethod
    def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
        """
        Authenticate user with email and password.

        Args:
            db: Database session
            email: User's email
            password: User's password

        Returns:
            User object if authenticated, None otherwise
        """
        user = AuthService.get_user_by_email(db, email)

        if not user:
            return None

        if not user.hashed_password:
            # User registered with Google only
            return None

        if not verify_password(password, user.hashed_password):
            return None

        if not user.is_active:
            return None

        # Update last login
        user = UserRepository.update_last_login(db, user)

        return user
    
    @staticmethod
    def create_user_token(user: User) -> dict:
        """
        Create access token for a user.
        
        Args:
            user: User object
            
        Returns:
            Dictionary with token and user info
        """
        access_token = create_access_token(
            data={"sub": user.uuid, "email": user.email}
        )
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": UserResponse.model_validate(user)
        }
    
    @staticmethod
    def verify_google_token(id_token_str: str) -> Optional[dict]:
        """
        Verify Google ID token and extract user info.
        
        Args:
            id_token_str: Google ID token from frontend
            
        Returns:
            Dictionary with user info if valid, None otherwise
        """
        try:
            # Verify the token
            idinfo = id_token.verify_oauth2_token(
                id_token_str, 
                google_requests.Request(), 
                settings.google_client_id
            )
            
            # Token is valid
            return {
                "google_id": idinfo["sub"],
                "email": idinfo["email"],
                "first_name": idinfo.get("given_name", ""),
                "last_name": idinfo.get("family_name", ""),
                "email_verified": idinfo.get("email_verified", False)
            }
            
        except ValueError as e:
            logger.error("Invalid Google token: %s", str(e))
            return None
    
    @staticmethod
    def google_auth(db: Session, id_token_str: str) -> Tuple[Optional[User], bool]:
        """
        Authenticate or register user with Google.

        Args:
            db: Database session
            id_token_str: Google ID token

        Returns:
            Tuple of (User object, is_new_user flag)
        """
        # Verify Google token
        google_info = AuthService.verify_google_token(id_token_str)

        if not google_info:
            return None, False

        # Check if user exists by Google ID
        user = AuthService.get_user_by_google_id(db, google_info["google_id"])

        if user:
            # Existing user, update last login
            user = UserRepository.update_last_login(db, user)
            return user, False

        # Check if user exists by email (registered with email/password)
        user = AuthService.get_user_by_email(db, google_info["email"])

        if user:
            # Link Google account to existing user
            update_data = {
                "google_id": google_info["google_id"],
                "is_verified": True,
                "last_login": datetime.utcnow()
            }
            user = UserRepository.update_user(db, user, update_data)
            return user, False

        # Create new user with Google
        user_dict = {
            "first_name": google_info["first_name"] or "User",
            "last_name": google_info["last_name"] or "",
            "email": google_info["email"].lower(),
            "google_id": google_info["google_id"],
            "is_verified": True,
            "last_login": datetime.utcnow()
        }

        user = UserRepository.create_user(db, user_dict)
        logger.info("Created new user via Google: %s", user.email)
        return user, True
    
    @staticmethod
    def create_password_reset_otp(db: Session, email: str) -> Tuple[bool, str]:
        """
        Create and send password reset OTP.

        Args:
            db: Database session
            email: User's email

        Returns:
            Tuple of (success, message)
        """
        user = AuthService.get_user_by_email(db, email)

        if not user:
            # Don't reveal if email exists
            return True, "If the email exists, you will receive an OTP"

        # Generate OTP
        otp = generate_otp()
        expires_at = datetime.utcnow() + timedelta(minutes=AuthService.OTP_VALIDITY_MINUTES)

        # Invalidate previous OTPs
        UserRepository.delete_user_otps(db, user.id, "password_reset")

        # Create new OTP record
        otp_data = {
            "user_id": user.id,
            "otp_code": otp,
            "otp_type": "password_reset",
            "expires_at": expires_at
        }
        UserRepository.create_otp_record(db, otp_data)

        # Send OTP email
        email_sent = email_service.send_otp_email(
            to_email=user.email,
            to_name=user.full_name,
            otp=otp,
            purpose="password_reset"
        )

        if email_sent:
            logger.info("Password reset OTP sent to: %s", email)
            return True, "OTP sent to your email"
        else:
            return False, "Failed to send OTP email"
    
    @staticmethod
    def verify_otp(db: Session, email: str, otp: str, otp_type: str = "password_reset") -> Tuple[bool, str]:
        """
        Verify an OTP code.

        Args:
            db: Database session
            email: User's email
            otp: OTP code to verify
            otp_type: Type of OTP

        Returns:
            Tuple of (is_valid, message)
        """
        user = AuthService.get_user_by_email(db, email)

        if not user:
            return False, "Invalid email or OTP"

        # Find valid OTP
        otp_record = UserRepository.get_valid_otp(db, user.id, otp, otp_type)

        if not otp_record:
            return False, "Invalid or expired OTP"

        return True, "OTP verified successfully"
    
    @staticmethod
    def reset_password(db: Session, email: str, otp: str, new_password: str) -> Tuple[bool, str]:
        """
        Reset user password with OTP.

        Args:
            db: Database session
            email: User's email
            otp: OTP code
            new_password: New password

        Returns:
            Tuple of (success, message)
        """
        user = AuthService.get_user_by_email(db, email)

        if not user:
            return False, "Invalid email or OTP"

        # Verify OTP
        otp_record = UserRepository.get_valid_otp(db, user.id, otp, "password_reset")

        if not otp_record:
            return False, "Invalid or expired OTP"

        # Update password
        update_data = {"hashed_password": get_password_hash(new_password)}
        UserRepository.update_user(db, user, update_data)

        # Mark OTP as used
        UserRepository.mark_otp_used(db, otp_record)

        logger.info("Password reset successful for: %s", email)
        return True, "Password reset successfully"
    
    @staticmethod
    def change_password(db: Session, user: User, current_password: str, new_password: str) -> Tuple[bool, str]:
        """
        Change password for authenticated user.

        Args:
            db: Database session
            user: User object
            current_password: Current password
            new_password: New password

        Returns:
            Tuple of (success, message)
        """
        if not user.hashed_password:
            return False, "Cannot change password for Google-only account. Please set a password first."

        if not verify_password(current_password, user.hashed_password):
            return False, "Current password is incorrect"

        update_data = {"hashed_password": get_password_hash(new_password)}
        UserRepository.update_user(db, user, update_data)

        logger.info("Password changed for: %s", user.email)
        return True, "Password changed successfully"
