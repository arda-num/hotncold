from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class RewardRead(BaseModel):
    id: uuid.UUID
    type: str
    value: int
    description: Optional[str]
    reward_template_id: Optional[uuid.UUID]
    location_id: Optional[uuid.UUID]
    redeemed: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class RewardSummary(BaseModel):
    total_points: int
    total_rewards: int
    rewards: list[RewardRead]
