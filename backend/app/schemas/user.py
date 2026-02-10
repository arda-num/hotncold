from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    display_name: str = ""
    avatar_url: Optional[str] = None


class UserRead(UserBase):
    id: uuid.UUID
    role: str
    total_points: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    display_name: Optional[str] = Field(None, max_length=100)
    avatar_url: Optional[str] = Field(None, max_length=500)
    fcm_token: Optional[str] = Field(None, max_length=500)


class UserStats(BaseModel):
    total_points: int
    total_claims: int
    member_since: datetime

    model_config = {"from_attributes": True}
