from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class RewardTemplateBase(BaseModel):
    reward_type: str = Field(..., max_length=20, description="points | coupon | raffle | product")
    reward_value: int = Field(..., ge=0)
    reward_description: Optional[str] = Field(None, max_length=500)
    is_active: bool = True


class RewardTemplateCreate(RewardTemplateBase):
    location_id: uuid.UUID


class RewardTemplateRead(RewardTemplateBase):
    id: uuid.UUID
    location_id: uuid.UUID
    created_at: datetime

    model_config = {"from_attributes": True}
