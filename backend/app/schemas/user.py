from pydantic import BaseModel, EmailStr
from typing import Optional
from uuid import UUID

class UserResponse(BaseModel):
    user_id: UUID
    username: str
    email: EmailStr
    native_language_id: Optional[int] = None
    target_language_id: Optional[int] = None
    proficiency_level: int = 1
    is_active: bool = True

    class Config:
        from_attributes = True

class ProfileUpdateRequest(BaseModel):
    native_language_id: Optional[int] = None
    target_language_id: Optional[int] = None
    proficiency_level: Optional[int] = None
