"""
Feedback Router for RomaSub.AI
Handles user feedback submission and retrieval (stored in PostgreSQL)
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional, List

from app.database import get_db
from app.models.feedback import Feedback

router = APIRouter(prefix="/feedback", tags=["Feedback"])


class FeedbackRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="Rating 1-5 stars")
    comment: Optional[str] = Field(None, max_length=2000)
    feedback_type: str = Field("general", description="general, bug, feature, other")


class FeedbackResponse(BaseModel):
    success: bool = True
    feedback_id: str
    message: str


class FeedbackItem(BaseModel):
    feedback_id: str
    rating: int
    comment: Optional[str]
    feedback_type: str
    created_at: str


@router.post("/submit", response_model=FeedbackResponse)
async def submit_feedback(request: FeedbackRequest, db: Session = Depends(get_db)):
    """Submit user feedback (stored in PostgreSQL)."""
    feedback = Feedback(
        rating=request.rating,
        comment=request.comment,
        feedback_type=request.feedback_type,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)

    return FeedbackResponse(
        feedback_id=feedback.feedback_id,
        message="Thank you for your feedback!",
    )


@router.get("/list")
async def list_feedback(db: Session = Depends(get_db)):
    """List all feedback (newest first)."""
    feedbacks = db.query(Feedback).order_by(Feedback.created_at.desc()).limit(50).all()

    return {
        "success": True,
        "feedbacks": [
            {
                "feedback_id": f.feedback_id,
                "rating": f.rating,
                "comment": f.comment,
                "feedback_type": f.feedback_type,
                "created_at": f.created_at.isoformat() if f.created_at else "",
            }
            for f in feedbacks
        ],
        "total": db.query(Feedback).count(),
        "average_rating": round(
            sum(f.rating for f in feedbacks) / len(feedbacks), 1
        ) if feedbacks else 0.0,
    }
