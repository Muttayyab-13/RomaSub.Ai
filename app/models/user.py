"""
User database model for RomaSub.AI
Handles user accounts, authentication methods, and OTP records
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import uuid


def generate_uuid():
    """Generate a unique UUID string"""
    return str(uuid.uuid4())


class User(Base):
    """
    User model for storing user account information.
    Supports both email/password and Google OAuth authentication.
    """
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    uuid = Column(String(36), unique=True, default=generate_uuid, index=True)
    
    # User information
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    
    # Authentication
    hashed_password = Column(String(255), nullable=True)  # Null for Google-only users
    
    # Google OAuth
    google_id = Column(String(255), unique=True, nullable=True, index=True)
    
    # Account status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    otp_records = relationship("OTPRecord", back_populates="user", cascade="all, delete-orphan")
    media_files = relationship("MediaFile", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User {self.email}>"
    
    @property
    def full_name(self):
        """Return user's full name"""
        return f"{self.first_name} {self.last_name}"


class OTPRecord(Base):
    """
    OTP (One-Time Password) records for password reset and verification.
    """
    __tablename__ = "otp_records"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # OTP details
    otp_code = Column(String(6), nullable=False)
    otp_type = Column(String(50), nullable=False)  # 'password_reset', 'email_verify'
    
    # Status
    is_used = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="otp_records")
    
    def __repr__(self):
        return f"<OTPRecord {self.otp_type} for user_id={self.user_id}>"
