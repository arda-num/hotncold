"""Reward claim service – validation chain and reward granting."""

from datetime import datetime, timezone

import redis.asyncio as redis
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import settings
from app.models.claim_log import ClaimLog
from app.models.location import Location
from app.models.reward import Reward
from app.models.reward_template import RewardTemplate
from app.models.user import User
from app.schemas.claim import ClaimRequest, ClaimResponse
from app.services.geo import haversine_distance


async def process_claim(
    db: AsyncSession,
    redis_client: redis.Redis,
    user: User,
    location_id: str,
    claim: ClaimRequest,
) -> ClaimResponse:
    """
    Full validation chain for a reward claim:
    1. Location exists, is active, has reward template
    2. Not already claimed by this user (once-only rule)
    3. GPS within radius
    4. Rate limit (Redis)
    5. Award reward
    """

    # 1. Look up location and reward template
    result = await db.execute(
        select(Location).where(Location.id == location_id, Location.is_active == True)  # noqa: E712
    )
    location = result.scalar_one_or_none()

    if location is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Location not found or inactive")

    # Get reward template for this location
    template_result = await db.execute(
        select(RewardTemplate).where(
            RewardTemplate.location_id == location.id,
            RewardTemplate.is_active == True,  # noqa: E712
        )
    )
    reward_template = template_result.scalar_one_or_none()

    if reward_template is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No active reward available at this location")

    # 2. Check if already claimed (once-only rule)
    claim_check = await db.execute(
        select(ClaimLog).where(
            ClaimLog.user_id == user.id,
            ClaimLog.location_id == location.id,
        )
    )
    if claim_check.scalar_one_or_none() is not None:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "You have already claimed the reward at this location"
        )

    # 3. GPS distance validation
    distance = haversine_distance(
        claim.latitude, claim.longitude,
        location.latitude, location.longitude
    )
    if distance > location.radius_m:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"You are too far from the location ({distance:.0f}m away, max {location.radius_m}m)"
        )

    # 4. Rate limiting (Redis) - use existing scan limits for now
    rate_key = f"claim_rate:{user.id}"
    daily_key = f"claim_daily:{user.id}:{datetime.now(timezone.utc).strftime('%Y-%m-%d')}"
    cooldown_key = f"claim_cooldown:{user.id}"

    # Cooldown check
    if await redis_client.exists(cooldown_key):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Please wait before claiming another reward"
        )

    # Hourly rate limit
    hourly_count = await redis_client.get(rate_key)
    if hourly_count and int(hourly_count) >= settings.max_scans_per_hour:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Hourly claim limit reached")

    # Daily limit
    daily_count = await redis_client.get(daily_key)
    if daily_count and int(daily_count) >= settings.max_daily_scans:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Daily claim limit reached")

    # ---- All checks passed – process the claim ----

    # Create claim log
    claim_log = ClaimLog(
        user_id=user.id,
        location_id=location.id,
        latitude=claim.latitude,
        longitude=claim.longitude,
        device_fingerprint=claim.device_id,
    )
    db.add(claim_log)

    # Create reward
    reward = Reward(
        user_id=user.id,
        type=reward_template.reward_type,
        value=reward_template.reward_value,
        description=reward_template.reward_description or f"+{reward_template.reward_value} points",
        reward_template_id=reward_template.id,
        location_id=location.id,
    )
    db.add(reward)

    # Update user points (for point-type rewards)
    if reward_template.reward_type == "points":
        user.total_points += reward_template.reward_value

    await db.flush()

    # Update Redis rate counters
    pipe = redis_client.pipeline()
    pipe.incr(rate_key)
    pipe.expire(rate_key, 3600)  # 1 hour TTL
    pipe.incr(daily_key)
    pipe.expire(daily_key, 86400)  # 24 hour TTL
    pipe.setex(cooldown_key, settings.scan_cooldown_seconds, "1")
    await pipe.execute()

    return ClaimResponse(
        reward_type=reward_template.reward_type,
        reward_value=reward_template.reward_value,
        reward_description=reward_template.reward_description,
        total_points=user.total_points,
        location_id=location.id,
        location_name=location.name,
    )
