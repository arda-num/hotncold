"""HotNCold – FastAPI application factory."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core import settings
from app.core.security import init_firebase
from app.api import health, users, locations, claims, rewards


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    # Startup
    init_firebase()
    yield
    # Shutdown (cleanup if needed)


def create_app() -> FastAPI:
    application = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
    )

    # CORS
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routers
    application.include_router(health.router)
    application.include_router(users.router, prefix="/users", tags=["users"])
    application.include_router(locations.router, prefix="/map", tags=["map"])
    application.include_router(claims.router, prefix="/locations", tags=["claims"])
    application.include_router(rewards.router, prefix="/users/me/rewards", tags=["rewards"])

    return application


app = create_app()
