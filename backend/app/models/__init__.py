"""Import all models so Alembic and relationships can discover them."""

from app.models.base import Base
from app.models.user import User
from app.models.sponsor import Sponsor
from app.models.location import Location
from app.models.reward_template import RewardTemplate
from app.models.claim_log import ClaimLog
from app.models.reward import Reward

__all__ = ["Base", "User", "Sponsor", "Location", "RewardTemplate", "ClaimLog", "Reward"]
