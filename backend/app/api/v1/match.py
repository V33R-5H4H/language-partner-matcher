from fastapi import APIRouter
from app.schemas.match import EnqueueRequest

router = APIRouter()

@router.post("/enqueue")
async def enqueue_for_match(payload: EnqueueRequest):
    return {"status": "enqueued", "target_language_id": payload.target_language_id}

@router.post("/cancel")
async def cancel_match():
    return {"status": "cancelled"}

@router.get("/status")
async def match_status():
    return {"status": "idle"}
