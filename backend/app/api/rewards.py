"""Rewards endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.reward import Reward
from app.models.user import User
from app.schemas.reward import RewardRead, RewardSummary

router = APIRouter()


@router.get("", response_model=RewardSummary)
async def get_my_rewards(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the authenticated user's reward wallet."""
    result = await db.execute(
        select(Reward)
        .where(Reward.user_id == user.id)
        .order_by(Reward.created_at.desc())
    )
    rewards = result.scalars().all()

    count_result = await db.execute(
        select(func.count()).where(Reward.user_id == user.id)
    )
    total_rewards = count_result.scalar() or 0

    return RewardSummary(
        total_points=user.total_points,
        total_rewards=total_rewards,
        rewards=[RewardRead.model_validate(r) for r in rewards],
    )
