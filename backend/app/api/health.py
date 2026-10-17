from fastapi import APIRouter

router = APIRouter()

@router.api_route("/health", methods=["GET", "HEAD"], tags=["Health"])
async def health_check():
    """ALB Health check endpoint returning HTTP 200 OK for both GET and HEAD."""
    return {"status": "healthy", "service": "langmatcher-backend"}
