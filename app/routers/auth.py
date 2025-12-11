"""
Authentication Router for RomaSub.AI
Handles user registration, login, password reset, and Google OAuth
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import Annotated

from app.database import get_db
from app.schemas.user import (
    UserCreate,
    UserLogin,
    UserResponse,
    Token,
    GoogleAuthRequest,
    ForgotPasswordRequest,
    VerifyOTPRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    MessageResponse,
    VerifyEmailRequest,
    ResendOTPRequest,
    RegistrationResponse
)
from app.services import auth as auth_service
from app.utils.security import decode_access_token
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Authentication"])

# OAuth2 scheme for JWT bearer tokens
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency to get current authenticated user from JWT token.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_access_token(token)
    
    if payload is None:
        raise credentials_exception
    
    user_uuid: str = payload.get("sub")
    
    if user_uuid is None:
        raise credentials_exception
    
    user = auth_service.get_user_by_uuid(db, user_uuid)

    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    return user


@router.post("/register", response_model=RegistrationResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: Session = Depends(get_db)
):
    """
    Register a new user with email and password.
    A verification OTP will be sent to the user's email.

    - **first_name**: User's first name
    - **last_name**: User's last name
    - **email**: User's email address (must be unique)
    - **password**: Password (min 8 characters, must contain letter, digit, and special character)
    - **confirm_password**: Must match password
    """
    # Register user (includes email existence check)
    try:
        user, email_sent = auth_service.register_user(db, user_data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

    # Return registration success message
    message = "Registration successful. Please check your email for verification OTP."
    if not email_sent:
        message = "Registration successful, but failed to send verification email. Please use resend OTP."

    return RegistrationResponse(
        message=message,
        email=user.email,
        user_uuid=user.uuid
    )


@router.post("/login", response_model=Token)
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Session = Depends(get_db)
):
    """
    Login with email and password.

    Uses OAuth2 password flow for compatibility with OpenAPI/Swagger.

    - **username**: User's email address
    - **password**: User's password
    """
    user = auth_service.authenticate_user(db, form_data.username, form_data.password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check if email is verified
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please verify your email before logging in. Check your email for the verification OTP."
        )

    return auth_service.create_user_token(user)


@router.post("/login/json", response_model=Token)
async def login_json(
    login_data: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Login with email and password (JSON body).

    Alternative to OAuth2 form login.

    - **email**: User's email address
    - **password**: User's password
    """
    user = auth_service.authenticate_user(db, login_data.email, login_data.password)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    # Check if email is verified
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please verify your email before logging in. Check your email for the verification OTP."
        )

    return auth_service.create_user_token(user)


@router.post("/google", response_model=Token)
async def google_auth(
    google_data: GoogleAuthRequest,
    db: Session = Depends(get_db)
):
    """
    Authenticate or register with Google OAuth.
    
    - **id_token**: Google ID token obtained from frontend Google Sign-In
    
    If user doesn't exist, a new account will be created.
    If user exists with same email, Google account will be linked.
    """
    user, is_new = auth_service.google_auth(db, google_data.id_token)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google token"
        )

    token_response = auth_service.create_user_token(user)

    # Add flag to indicate if new user was created
    return token_response


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db)
):
    """
    Request password reset OTP.
    
    An OTP will be sent to the email address if it exists in the system.
    
    - **email**: User's registered email address
    """
    success, message = auth_service.create_password_reset_otp(db, request.email)

    return MessageResponse(message=message, success=success)


@router.post("/verify-otp", response_model=MessageResponse)
async def verify_otp(
    request: VerifyOTPRequest,
    db: Session = Depends(get_db)
):
    """
    Verify OTP code for password reset.

    Use this to check if OTP is valid before resetting password.

    - **email**: User's email address
    - **otp**: 6-digit OTP code received via email
    """
    is_valid, message = auth_service.verify_otp(db, request.email, request.otp)

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return MessageResponse(message=message, success=True)


@router.post("/verify-email", response_model=Token)
async def verify_email(
    request: VerifyEmailRequest,
    db: Session = Depends(get_db)
):
    """
    Verify email address with OTP.

    After successful verification, user will be able to login.

    - **email**: User's email address
    - **otp**: 6-digit OTP code received via email
    """
    success, message, user = auth_service.verify_email(db, request.email, request.otp)

    if not success or not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    # Return token so user can immediately login
    return auth_service.create_user_token(user)


@router.post("/resend-verification-otp", response_model=MessageResponse)
async def resend_verification_otp(
    request: ResendOTPRequest,
    db: Session = Depends(get_db)
):
    """
    Resend email verification OTP.

    Use this if user didn't receive the verification email.

    - **email**: User's email address
    """
    success, message = auth_service.resend_verification_otp(db, request.email)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return MessageResponse(message=message, success=True)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db)
):
    """
    Reset password using OTP.

    - **email**: User's email address
    - **otp**: 6-digit OTP code
    - **new_password**: New password (min 8 characters, must contain letter, digit, and special character)
    - **confirm_password**: Must match new_password
    """
    success, message = auth_service.reset_password(
        db,
        request.email,
        request.otp,
        request.new_password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return MessageResponse(message=message, success=True)


@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    request: ChangePasswordRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db)
):
    """
    Change password for authenticated user.

    Requires valid JWT token in Authorization header.

    - **current_password**: User's current password
    - **new_password**: New password (min 8 characters, must contain letter, digit, and special character)
    - **confirm_password**: Must match new_password
    """
    success, message = auth_service.change_password(
        db,
        current_user,
        request.current_password,
        request.new_password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )

    return MessageResponse(message=message, success=True)


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: Annotated[User, Depends(get_current_user)]
):
    """
    Get current authenticated user's information.
    
    Requires valid JWT token in Authorization header.
    """
    return current_user
