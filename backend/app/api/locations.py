"""Map / location endpoints."""

from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_active_user
from app.models.user import User
from app.schemas.location import LocationWithDistance
from app.services.location_service import get_nearby_locations

router = APIRouter()


@router.get("/locations", response_model=list[LocationWithDistance])
async def list_nearby_locations(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(1000.0, ge=0.1, le=1000),
    city: Optional[str] = Query(None),
    _user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return active treasure locations near the given coordinates.
    Results are sorted by distance ascending.
    """
    nearby = await get_nearby_locations(db, latitude, longitude, radius_km, city)

    return [
        LocationWithDistance(
            id=item["location"].id,
            name=item["location"].name,
            description=item["location"].description,
            latitude=item["location"].latitude,
            longitude=item["location"].longitude,
            address=item["location"].address,
            image_url=item["location"].image_url,
            radius_m=item["location"].radius_m,
            city=item["location"].city,
            sponsor_id=item["location"].sponsor_id,
            is_active=item["location"].is_active,
            created_at=item["location"].created_at,
            distance_m=item["distance_m"],
            reward_template=item["location"].reward_template,
        )
        for item in nearby
    ]
