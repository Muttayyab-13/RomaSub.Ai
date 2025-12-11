"""
Pydantic schemas for request/response validation
Handles user registration, login, and authentication flows
"""

from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional
from datetime import datetime
import re


class UserCreate(BaseModel):
    """Schema for user registration"""
    first_name: str = Field(..., min_length=1, max_length=100, description="User's first name")
    last_name: str = Field(..., min_length=1, max_length=100, description="User's last name")
    email: EmailStr = Field(..., description="User's email address")
    password: str = Field(..., min_length=8, max_length=72, description="User's password (max 72 chars due to bcrypt limit)")
    confirm_password: str = Field(..., description="Password confirmation")
    
    @validator('password')
    def validate_password(cls, v):
        """Validate password strength"""
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('Password must contain at least one letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/;\'`~]', v):
            raise ValueError('Password must contain at least one special character (!@#$%^&*(),.?":{}|<>_-+=[]\\\/;\'`~)')
        return v
    
    @validator('confirm_password')
    def passwords_match(cls, v, values):
        """Ensure password and confirm_password match"""
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v
    
    @validator('first_name', 'last_name')
    def validate_name(cls, v):
        """Validate name contains only valid characters"""
        if not re.match(r'^[a-zA-Z\s\-\']+$', v):
            raise ValueError('Name can only contain letters, spaces, hyphens, and apostrophes')
        return v.strip()
    
    class Config:
        json_schema_extra = {
            "example": {
                "first_name": "Muttayyab",
                "last_name": "Abdurrehman",
                "email": "muttayyab@example.com",
                "password": "SecurePass123!",
                "confirm_password": "SecurePass123!"
            }
        }


class UserLogin(BaseModel):
    """Schema for user login"""
    email: EmailStr = Field(..., description="User's email address")
    password: str = Field(..., description="User's password")
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com",
                "password": "SecurePass123!"
            }
        }


class UserResponse(BaseModel):
    """Schema for user response (without sensitive data)"""
    uuid: str
    first_name: str
    last_name: str
    email: str
    profile_picture_url: Optional[str] = None
    google_id: Optional[str] = None
    is_active: bool
    is_verified: bool
    created_at: datetime
    last_login: Optional[datetime] = None

    class Config:
        from_attributes = True


class Token(BaseModel):
    """Schema for JWT token response"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class GoogleAuthRequest(BaseModel):
    """Schema for Google OAuth authentication"""
    id_token: str = Field(..., description="Google ID token from frontend")

    class Config:
        json_schema_extra = {
            "example": {
                "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6Ikp..."
            }
        }


class GoogleAuthCodeRequest(BaseModel):
    """Schema for Google OAuth authentication with authorization code (for desktop apps)"""
    code: str = Field(..., description="Authorization code from Google OAuth")
    redirect_uri: str = Field(..., description="Redirect URI used in OAuth flow")

    class Config:
        json_schema_extra = {
            "example": {
                "code": "4/0AeaYSHB...",
                "redirect_uri": "http://localhost:8080/auth/callback"
            }
        }


class ForgotPasswordRequest(BaseModel):
    """Schema for forgot password request"""
    email: EmailStr = Field(..., description="User's email address")
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com"
            }
        }


class VerifyOTPRequest(BaseModel):
    """Schema for OTP verification"""
    email: EmailStr = Field(..., description="User's email address")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP code")
    
    @validator('otp')
    def validate_otp(cls, v):
        """Validate OTP is numeric"""
        if not v.isdigit():
            raise ValueError('OTP must contain only digits')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com",
                "otp": "123456"
            }
        }


class ResetPasswordRequest(BaseModel):
    """Schema for password reset with OTP"""
    email: EmailStr = Field(..., description="User's email address")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP code")
    new_password: str = Field(..., min_length=8, max_length=100, description="New password")
    confirm_password: str = Field(..., description="Password confirmation")
    
    @validator('otp')
    def validate_otp(cls, v):
        """Validate OTP is numeric"""
        if not v.isdigit():
            raise ValueError('OTP must contain only digits')
        return v
    
    @validator('new_password')
    def validate_password(cls, v):
        """Validate password strength"""
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('Password must contain at least one letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/;\'`~]', v):
            raise ValueError('Password must contain at least one special character (!@#$%^&*(),.?":{}|<>_-+=[]\\\/;\'`~)')
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        """Ensure passwords match"""
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com",
                "otp": "123456",
                "new_password": "NewSecurePass123!",
                "confirm_password": "NewSecurePass123!"
            }
        }


class ChangePasswordRequest(BaseModel):
    """Schema for changing password (authenticated user)"""
    current_password: str = Field(..., description="Current password")
    new_password: str = Field(..., min_length=8, max_length=100, description="New password")
    confirm_password: str = Field(..., description="Password confirmation")
    
    @validator('new_password')
    def validate_password(cls, v):
        """Validate password strength"""
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('Password must contain at least one letter')
        if not re.search(r'\d', v):
            raise ValueError('Password must contain at least one digit')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/;\'`~]', v):
            raise ValueError('Password must contain at least one special character (!@#$%^&*(),.?":{}|<>_-+=[]\\\/;\'`~)')
        return v

    @validator('confirm_password')
    def passwords_match(cls, v, values):
        """Ensure passwords match"""
        if 'new_password' in values and v != values['new_password']:
            raise ValueError('Passwords do not match')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "current_password": "OldPassword123!",
                "new_password": "NewPassword456!",
                "confirm_password": "NewPassword456!"
            }
        }


class UpdateProfileRequest(BaseModel):
    """Schema for updating user profile"""
    first_name: str = Field(..., min_length=1, max_length=100, description="User's first name")
    last_name: str = Field(..., min_length=1, max_length=100, description="User's last name")

    @validator('first_name', 'last_name')
    def validate_name(cls, v):
        """Validate name contains only valid characters"""
        if not re.match(r'^[a-zA-Z\s\-\']+$', v):
            raise ValueError('Name can only contain letters, spaces, hyphens, and apostrophes')
        return v.strip()

    class Config:
        json_schema_extra = {
            "example": {
                "first_name": "Muttayyab",
                "last_name": "Abdurrehman"
            }
        }


class VerifyEmailRequest(BaseModel):
    """Schema for email verification"""
    email: EmailStr = Field(..., description="User's email address")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP code")

    @validator('otp')
    def validate_otp(cls, v):
        """Validate OTP is numeric"""
        if not v.isdigit():
            raise ValueError('OTP must contain only digits')
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com",
                "otp": "123456"
            }
        }


class ResendOTPRequest(BaseModel):
    """Schema for resending OTP"""
    email: EmailStr = Field(..., description="User's email address")

    class Config:
        json_schema_extra = {
            "example": {
                "email": "muttayyab@example.com"
            }
        }


class RegistrationResponse(BaseModel):
    """Schema for registration response (before email verification)"""
    message: str
    email: str
    user_uuid: str

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Registration successful. Please check your email for verification OTP.",
                "email": "muttayyab@example.com",
                "user_uuid": "550e8400-e29b-41d4-a716-446655440000"
            }
        }


class MessageResponse(BaseModel):
    """Schema for simple message responses"""
    message: str
    success: bool = True

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Operation completed successfully",
                "success": True
            }
        }
