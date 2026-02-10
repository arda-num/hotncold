"""User endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.claim_log import ClaimLog
from app.models.user import User
from app.schemas.user import UserRead, UserStats, UserUpdate

router = APIRouter()


@router.get("/me", response_model=UserRead)
async def get_me(user: User = Depends(get_current_active_user)):
    """Return the current authenticated user's profile."""
    return user


@router.patch("/me", response_model=UserRead)
async def update_me(
    payload: UserUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Update the current user's profile fields."""
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    await db.flush()
    await db.refresh(user)
    return user


@router.get("/me/stats", response_model=UserStats)
async def get_my_stats(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return claim statistics for the current user."""
    result = await db.execute(
        select(func.count()).where(ClaimLog.user_id == user.id)
    )
    total_claims = result.scalar() or 0

    return UserStats(
        total_points=user.total_points,
        total_claims=total_claims,
        member_since=user.created_at,
    )
