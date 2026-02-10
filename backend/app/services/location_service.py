"""Location service – query nearby locations."""

from __future__ import annotations

from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.location import Location
from app.services.geo import haversine_distance


async def get_nearby_locations(
    db: AsyncSession,
    latitude: float,
    longitude: float,
    radius_km: float = 5.0,
    city: Optional[str] = None,
) -> list[dict]:
    """
    Return active locations within `radius_km` of the given coordinate.
    Each result includes the computed distance in meters and reward template info.

    Uses in-Python Haversine filtering (sufficient for MVP; replace with
    PostGIS ST_DWithin for scale).
    """
    stmt = select(Location).where(Location.is_active.is_(True)).options(
        selectinload(Location.reward_template)
    )
    if city:
        stmt = stmt.where(Location.city == city)

    result = await db.execute(stmt)
    locations = result.scalars().all()

    radius_m = radius_km * 1000
    nearby: list[dict] = []

    for loc in locations:
        dist = haversine_distance(latitude, longitude, loc.latitude, loc.longitude)
        if dist <= radius_m:
            nearby.append({
                "location": loc,
                "distance_m": round(dist, 1),
            })

    # Sort by distance ascending
    nearby.sort(key=lambda x: x["distance_m"])
    return nearby
