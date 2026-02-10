from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from fastapi import Query
from pydantic import BaseModel, Field


class RewardTemplateRead(BaseModel):
    """Reward template information for AR positioning."""
    id: uuid.UUID
    reward_type: str
    reward_value: int
    reward_description: Optional[str]
    bearing_degrees: float = Field(..., ge=0, le=360, description="AR bearing in degrees (0-360)")
    elevation_degrees: float = Field(..., ge=-90, le=90, description="AR elevation in degrees (-90 to +90)")
    is_active: bool

    model_config = {"from_attributes": True}


class LocationBase(BaseModel):
    name: str = Field(..., max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: Optional[str] = Field(None, max_length=500)
    image_url: Optional[str] = Field(None, max_length=500)
    radius_m: int = Field(100, ge=10, le=1000000)
    city: str = Field(..., max_length=100)


class LocationCreate(LocationBase):
    sponsor_id: Optional[uuid.UUID] = None


class LocationRead(LocationBase):
    id: uuid.UUID
    sponsor_id: Optional[uuid.UUID]
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class LocationWithDistance(LocationRead):
    """Location enriched with distance from the requesting user."""
    distance_m: float = 0.0
    reward_template: Optional[RewardTemplateRead] = None


class NearbyQuery(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius_km: float = Query(5.0, ge=0.1, le=50)
    city: Optional[str] = None
