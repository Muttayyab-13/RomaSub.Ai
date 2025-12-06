"""
User Repository for RomaSub.AI
Data access layer for User and OTP database operations

Pure functions for database operations - no classes, no state.
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.models.user import User, OTPRecord


# ============================================================================
# User Query Operations
# ============================================================================

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """
    Get user by email address.

    Args:
        db: Database session
        email: User's email address

    Returns:
        User object or None
    """
    return db.query(User).filter(User.email == email.lower()).first()


def get_user_by_uuid(db: Session, uuid: str) -> Optional[User]:
    """
    Get user by UUID.

    Args:
        db: Database session
        uuid: User's UUID

    Returns:
        User object or None
    """
    return db.query(User).filter(User.uuid == uuid).first()


def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
    """
    Get user by database ID.

    Args:
        db: Database session
        user_id: User's database ID

    Returns:
        User object or None
    """
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_google_id(db: Session, google_id: str) -> Optional[User]:
    """
    Get user by Google ID.

    Args:
        db: Database session
        google_id: User's Google ID

    Returns:
        User object or None
    """
    return db.query(User).filter(User.google_id == google_id).first()


def get_all_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """
    Get all users (paginated).

    Args:
        db: Database session
        skip: Number of records to skip
        limit: Maximum number of records to return

    Returns:
        List of User objects
    """
    return db.query(User).offset(skip).limit(limit).all()


def count_users(db: Session) -> int:
    """
    Count total number of users.

    Args:
        db: Database session

    Returns:
        Total user count
    """
    return db.query(User).count()


# ============================================================================
# User Mutation Operations
# ============================================================================

def create_user(db: Session, user_data: dict) -> User:
    """
    Create a new user in database.

    Args:
        db: Database session
        user_data: Dictionary with user fields (first_name, last_name, email, etc.)

    Returns:
        Created User object
    """
    db_user = User(**user_data)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def update_user(db: Session, user: User, update_data: dict) -> User:
    """
    Update user information.

    Args:
        db: Database session
        user: User object to update
        update_data: Dictionary with fields to update

    Returns:
        Updated User object
    """
    for key, value in update_data.items():
        if hasattr(user, key):
            setattr(user, key, value)

    db.commit()
    db.refresh(user)
    return user


def update_last_login(db: Session, user: User) -> User:
    """
    Update user's last login timestamp to now.

    Args:
        db: Database session
        user: User object

    Returns:
        Updated User object
    """
    user.last_login = datetime.utcnow()
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user: User) -> bool:
    """
    Delete a user from database.

    Args:
        db: Database session
        user: User object to delete

    Returns:
        True if deleted successfully
    """
    db.delete(user)
    db.commit()
    return True


# ============================================================================
# OTP Operations
# ============================================================================

def create_otp_record(db: Session, otp_data: dict) -> OTPRecord:
    """
    Create a new OTP record in database.

    Args:
        db: Database session
        otp_data: Dictionary with OTP fields (user_id, otp_code, otp_type, expires_at)

    Returns:
        Created OTPRecord object
    """
    db_otp = OTPRecord(**otp_data)
    db.add(db_otp)
    db.commit()
    db.refresh(db_otp)
    return db_otp


def get_valid_otp(db: Session, user_id: int, otp_code: str, otp_type: str) -> Optional[OTPRecord]:
    """
    Get a valid (unused, not expired) OTP record.

    Args:
        db: Database session
        user_id: User's database ID
        otp_code: OTP code to verify
        otp_type: Type of OTP (e.g., 'password_reset', 'email_verify')

    Returns:
        OTPRecord object or None if not found/expired/used
    """
    return db.query(OTPRecord).filter(
        and_(
            OTPRecord.user_id == user_id,
            OTPRecord.otp_code == otp_code,
            OTPRecord.otp_type == otp_type,
            OTPRecord.is_used == False,
            OTPRecord.expires_at > datetime.utcnow()
        )
    ).first()


def mark_otp_used(db: Session, otp_record: OTPRecord) -> OTPRecord:
    """
    Mark an OTP record as used.

    Args:
        db: Database session
        otp_record: OTPRecord object to mark as used

    Returns:
        Updated OTPRecord object
    """
    otp_record.is_used = True
    db.commit()
    db.refresh(otp_record)
    return otp_record


def delete_user_otps(db: Session, user_id: int, otp_type: str) -> int:
    """
    Delete all OTP records for a user of a specific type.

    Args:
        db: Database session
        user_id: User's database ID
        otp_type: Type of OTP to delete

    Returns:
        Number of records deleted
    """
    deleted = db.query(OTPRecord).filter(
        and_(
            OTPRecord.user_id == user_id,
            OTPRecord.otp_type == otp_type
        )
    ).delete()
    db.commit()
    return deleted
