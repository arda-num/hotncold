"""Reward claim endpoints."""

import uuid

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.core.redis import get_redis
from app.models.user import User
from app.schemas.claim import ClaimRequest, ClaimResponse
from app.services.claim_service import process_claim

router = APIRouter()


@router.post("/{location_id}/claim", response_model=ClaimResponse)
async def claim_reward(
    location_id: uuid.UUID = Path(..., description="UUID of the location to claim reward from"),
    payload: ClaimRequest = ...,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
):
    """
    Claim a reward at a location. Validates GPS proximity, checks for duplicate claims,
    applies rate limits, and awards the configured reward on success.
    
    Each location can only be claimed once per user.
    """
    return await process_claim(db, redis_client, user, str(location_id), payload)
