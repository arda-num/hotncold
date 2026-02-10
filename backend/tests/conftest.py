"""Shared test fixtures."""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import Base, get_db
from app.core.deps import get_current_user
from app.core.redis import get_redis
from app.models.user import User


# ---- Event loop ----
@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


# ---- Fake user for dependency override ----
@pytest.fixture
def fake_user() -> User:
    return User(
        id=uuid4(),
        firebase_uid="test-firebase-uid",
        email="test@example.com",
        display_name="Test User",
        total_points=0,
        is_active=True,
        role="user",
    )


# ---- Mock Redis ----
@pytest.fixture
def mock_redis():
    r = AsyncMock()
    r.exists.return_value = False
    r.get.return_value = None
    r.pipeline.return_value = AsyncMock()
    r.pipeline.return_value.execute = AsyncMock(return_value=[])
    return r


# ---- App with dependency overrides ----
@pytest_asyncio.fixture
async def client(fake_user, mock_redis):
    # Patch firebase init to no-op
    with patch("app.core.security.init_firebase"):
        from app.main import app

        # Override dependencies
        async def override_get_current_user():
            return fake_user

        async def override_get_redis():
            return mock_redis

        app.dependency_overrides[get_current_user] = override_get_current_user
        app.dependency_overrides[get_redis] = override_get_redis

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac

        app.dependency_overrides.clear()
