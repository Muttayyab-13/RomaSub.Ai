"""
Feedback database model for RomaSub.AI
Stores user feedback with ratings in PostgreSQL
"""

from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
import uuid


def generate_uuid():
    return str(uuid.uuid4())


class Feedback(Base):
    """User feedback stored in PostgreSQL"""
    __tablename__ = "feedbacks"

    id = Column(Integer, primary_key=True, index=True)
    feedback_id = Column(String(36), unique=True, default=generate_uuid, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)

    rating = Column(Integer, nullable=False)  # 1-5 stars
    comment = Column(Text, nullable=True)
    feedback_type = Column(String(50), default="general")  # general, bug, feature, other

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")

    def __repr__(self):
        return f"<Feedback {self.feedback_id} rating={self.rating}>"
