from pydantic import BaseModel
from typing import Optional
from uuid import UUID

class EnqueueRequest(BaseModel):
    target_language_id: int

class MatchFoundResponse(BaseModel):
    room_id: UUID
    peer_id: UUID
    peer_username: str
    peer_native_lang: str
    peer_target_lang: str
    is_initiator: bool
