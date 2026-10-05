from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.future import select
from app.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=1800,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    """Create all tables and seed initial language and timezone metadata."""
    from app.models.language import Language
    from app.models.timezone import Timezone
    # Import all models so metadata is complete
    import app.models  # noqa

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Seed Languages and Timezones if empty
    async with AsyncSessionLocal() as session:
        lang_result = await session.execute(select(Language))
        if not lang_result.scalars().first():
            default_languages = [
                Language(language_id=1, language_name="English", language_code="EN"),
                Language(language_id=2, language_name="Spanish", language_code="ES"),
                Language(language_id=3, language_name="French", language_code="FR"),
                Language(language_id=4, language_name="German", language_code="DE"),
                Language(language_id=5, language_name="Japanese", language_code="JA"),
                Language(language_id=6, language_name="Mandarin", language_code="ZH"),
                Language(language_id=7, language_name="Hindi", language_code="HI"),
            ]
            session.add_all(default_languages)

        tz_result = await session.execute(select(Timezone))
        if not tz_result.scalars().first():
            default_timezones = [
                Timezone(timezone_id=1, utc_offset="+00:00", region_name="UTC / London"),
                Timezone(timezone_id=2, utc_offset="+05:30", region_name="Asia/Kolkata (IST)"),
                Timezone(timezone_id=3, utc_offset="-05:00", region_name="America/New_York (EST)"),
                Timezone(timezone_id=4, utc_offset="-08:00", region_name="America/Los_Angeles (PST)"),
                Timezone(timezone_id=5, utc_offset="+09:00", region_name="Asia/Tokyo (JST)"),
            ]
            session.add_all(default_timezones)

        await session.commit()
