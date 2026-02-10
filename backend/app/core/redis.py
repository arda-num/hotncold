"""Redis client for caching and rate limiting."""

import redis.asyncio as redis

from app.core import settings

redis_client = redis.from_url(settings.redis_url, decode_responses=True)


async def get_redis() -> redis.Redis:
    """FastAPI dependency that returns the async Redis client."""
    return redis_client
