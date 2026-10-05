import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base

class CallSession(Base):
    __tablename__ = "call_sessions"

    session_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_a_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    user_b_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    language_id = Column(Integer, ForeignKey("languages.language_id"), nullable=True)
    start_time = Column(DateTime, default=datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    duration_seconds = Column(Integer, default=0)
    termination_reason = Column(String(50), default="NORMAL")
    rating_user_a = Column(Integer, nullable=True)
    rating_user_b = Column(Integer, nullable=True)
