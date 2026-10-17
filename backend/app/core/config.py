from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Language Partner Matcher"
    API_V1_STR: str = "/api/v1"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/langmatcher"
    REDIS_URL: str = "redis://localhost:6379/0"
    JWT_SECRET_KEY: str = "super_secret_jwt_key_change_in_production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    ENVIRONMENT: str = "production"
    TURN_DOMAIN: str = ""
    TURN_SERVER_IP: str = ""
    TURN_SHARED_SECRET: str = ""

    class Config:
        case_sensitive = True
        env_file = ".env"
        extra = "ignore"

settings = Settings()
