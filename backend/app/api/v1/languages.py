from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.core.database import get_db
from app.models.language import Language

router = APIRouter()

@router.get("", response_model=list[dict])
async def list_languages(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Language))
    languages = result.scalars().all()
    if not languages:
        # Initial defaults
        return [
            {"language_id": 1, "language_name": "English", "language_code": "EN"},
            {"language_id": 2, "language_name": "Spanish", "language_code": "ES"},
            {"language_id": 3, "language_name": "French", "language_code": "FR"},
            {"language_id": 4, "language_name": "German", "language_code": "DE"},
            {"language_id": 5, "language_name": "Japanese", "language_code": "JA"},
        ]
    return [{"language_id": l.language_id, "language_name": l.language_name, "language_code": l.language_code} for l in languages]
