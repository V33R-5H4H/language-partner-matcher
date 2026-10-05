import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base

class Timezone(Base):
    __tablename__ = "timezones"

    timezone_id = Column(Integer, primary_key=True, index=True)
    utc_offset = Column(String(10), nullable=False)
    region_name = Column(String(100), unique=True, nullable=False)

class UserAvailability(Base):
    __tablename__ = "user_availability"

    availability_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id", ondelete="CASCADE"), unique=True, nullable=False)
    timezone_id = Column(Integer, ForeignKey("timezones.timezone_id"), nullable=True)
    available_hours_bitmask = Column(String(24), default="111111111111111111111111")
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
