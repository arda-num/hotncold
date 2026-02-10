from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class RewardTemplate(Base):
    """Template for rewards that can be claimed at a location."""
    __tablename__ = "reward_templates"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    location_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("locations.id"), nullable=False, index=True
    )
    reward_type: Mapped[str] = mapped_column(String(20), nullable=False)  # points | coupon | raffle | product
    reward_value: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    reward_description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # AR positioning: bearing (0-360°) and elevation (-90 to +90°) for virtual reward placement
    bearing_degrees: Mapped[float] = mapped_column(Float, nullable=False, default=45.0)
    elevation_degrees: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    location = relationship("Location", back_populates="reward_template", lazy="selectin")

    def __repr__(self) -> str:
        return f"<RewardTemplate {self.reward_type}={self.reward_value} for location={self.location_id} at {self.bearing_degrees}°>"
