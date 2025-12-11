"""
User profile management endpoints
Handles profile updates and profile picture uploads
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import Optional
import os
import uuid
from pathlib import Path

from app.database import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UpdateProfileRequest, MessageResponse
from app.routers.auth import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

# Profile picture storage configuration
PROFILE_PICTURES_DIR = Path("uploads/profile_pictures")
PROFILE_PICTURES_DIR.mkdir(parents=True, exist_ok=True)
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB


@router.put("/profile", response_model=UserResponse)
async def update_profile(
    profile_data: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update user profile (first name and last name)
    """
    # Update user fields
    current_user.first_name = profile_data.first_name
    current_user.last_name = profile_data.last_name

    db.commit()
    db.refresh(current_user)

    return current_user


@router.post("/profile-picture", response_model=MessageResponse)
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload and update user profile picture
    """
    # Validate file extension
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed types: {', '.join(ALLOWED_IMAGE_EXTENSIONS)}"
        )

    # Read and validate file size
    contents = await file.read()
    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {MAX_IMAGE_SIZE // (1024*1024)}MB"
        )

    # Generate unique filename
    unique_filename = f"{current_user.uuid}_{uuid.uuid4().hex[:8]}{file_ext}"
    file_path = PROFILE_PICTURES_DIR / unique_filename

    # Delete old profile picture if exists
    if current_user.profile_picture_url:
        old_file_path = Path(current_user.profile_picture_url.replace("/uploads/", "uploads/", 1))
        if old_file_path.exists():
            try:
                old_file_path.unlink()
            except Exception:
                pass  # Ignore errors when deleting old file

    # Save new file
    try:
        with open(file_path, "wb") as f:
            f.write(contents)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save file: {str(e)}"
        )

    # Update database with file URL
    current_user.profile_picture_url = f"/uploads/profile_pictures/{unique_filename}"
    db.commit()

    return MessageResponse(
        message="Profile picture updated successfully",
        success=True
    )


@router.delete("/profile-picture", response_model=MessageResponse)
async def delete_profile_picture(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete user profile picture
    """
    if not current_user.profile_picture_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No profile picture found"
        )

    # Delete file from filesystem
    file_path = Path(current_user.profile_picture_url.replace("/uploads/", "uploads/", 1))
    if file_path.exists():
        try:
            file_path.unlink()
        except Exception:
            pass  # Ignore errors

    # Update database
    current_user.profile_picture_url = None
    db.commit()

    return MessageResponse(
        message="Profile picture deleted successfully",
        success=True
    )


@router.get("/me/details", response_model=UserResponse)
async def get_user_details(
    current_user: User = Depends(get_current_user)
):
    """
    Get extended user details (same as /auth/me but with explicit endpoint)
    """
    return current_user
