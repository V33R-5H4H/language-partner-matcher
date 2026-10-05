from fastapi import APIRouter

router = APIRouter()

@router.get("/health", tags=["Health"])
async def health_check():
    """ALB Health check endpoint returning HTTP 200 OK."""
    return {"status": "healthy", "service": "langmatcher-backend"}
