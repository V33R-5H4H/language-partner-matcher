import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.health import router as health_router
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.languages import router as languages_router
from app.api.v1.match import router as match_router
from app.api.v1.webrtc import router as webrtc_router
from app.websocket.router import router as ws_router
from app.core.config import settings
from app.core.database import init_db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("langmatcher")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up Language Partner Matcher API...")
    try:
        await init_db()
        logger.info("Database tables verified & seed metadata loaded successfully.")
    except Exception as e:
        logger.error(f"Error initializing database on startup: {e}")
    yield
    logger.info("Shutting down Language Partner Matcher API...")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend API and WebRTC Signaling Service for Language Partner Matcher",
    version="1.0.0",
    lifespan=lifespan,
)

# Cross-Origin Resource Sharing (CORS) for Web and Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Attach API Routers
app.include_router(health_router, prefix="/api/v1")
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(users_router, prefix="/api/v1/users", tags=["Users"])
app.include_router(languages_router, prefix="/api/v1/languages", tags=["Languages"])
app.include_router(match_router, prefix="/api/v1/match", tags=["Matchmaking"])
app.include_router(webrtc_router, prefix="/api/v1", tags=["WebRTC"])
app.include_router(ws_router)

@app.get("/")
async def root():
    return {
        "message": "Welcome to Language Partner Matcher API",
        "docs": "/docs",
        "health": "/api/v1/health",
    }
