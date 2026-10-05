from sqlalchemy import Column, Integer, String
from app.core.database import Base

class Language(Base):
    __tablename__ = "languages"

    language_id = Column(Integer, primary_key=True, index=True)
    language_name = Column(String(50), unique=True, nullable=False)
    language_code = Column(String(10), unique=True, nullable=False)
