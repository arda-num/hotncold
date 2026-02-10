from __future__ import annotations

import uuid
from typing import Optional

from pydantic import BaseModel, Field


class ClaimRequest(BaseModel):
    """Request to claim a reward at a location."""
    latitude: float = Field(..., ge=-90, le=90, description="User's current latitude")
    longitude: float = Field(..., ge=-180, le=180, description="User's current longitude")
    device_id: Optional[str] = Field(None, max_length=500, description="Device fingerprint for anti-abuse")


class ClaimResponse(BaseModel):
    """Response after successfully claiming a reward."""
    reward_type: str
    reward_value: int
    reward_description: Optional[str]
    total_points: int
    location_id: uuid.UUID
    location_name: str
