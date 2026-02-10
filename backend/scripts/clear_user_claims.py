"""Clear claim logs for a specific user (for testing purposes)."""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path to import app modules
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import delete, select

from app.core.database import async_session_factory
from app.models.claim_log import ClaimLog
from app.models.reward import Reward
from app.models.user import User


async def clear_user_claims(user_email: str):
    """Delete all claim logs and rewards for a user."""
    async with async_session_factory() as db:
        # Find user
        result = await db.execute(select(User).where(User.email == user_email))
        user = result.scalar_one_or_none()
        
        if not user:
            print(f"❌ User not found: {user_email}")
            return
        
        # Delete claim logs
        claim_result = await db.execute(
            delete(ClaimLog).where(ClaimLog.user_id == user.id)
        )
        claims_deleted = claim_result.rowcount
        
        # Delete rewards
        reward_result = await db.execute(
            delete(Reward).where(Reward.user_id == user.id)
        )
        rewards_deleted = reward_result.rowcount
        
        # Reset user points
        user.total_points = 0
        
        await db.commit()
        
        print(f"✅ Cleared {claims_deleted} claims and {rewards_deleted} rewards for {user_email}")
        print(f"✅ Reset total points to 0")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python clear_user_claims.py <user_email>")
        sys.exit(1)
    
    user_email = sys.argv[1]
    asyncio.run(clear_user_claims(user_email))
