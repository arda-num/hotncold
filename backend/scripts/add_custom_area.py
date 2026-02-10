"""Add locations around 39.942351, 32.835282 (Ankara)."""

import asyncio
import random
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from app.core.database import async_session_factory
from app.models import Sponsor, Location, RewardTemplate

# Locations around 39.942351, 32.835282
CUSTOM_LOCATIONS = [
    {"name": "Central Park Cafe", "lat": 39.942351, "lng": 32.835282, "address": "Merkez Park, Ankara"},
    {"name": "Corner Coffee Shop", "lat": 39.943000, "lng": 32.836000, "address": "Köşe Kahve, Ankara"},
    {"name": "Mall Rewards Station", "lat": 39.941800, "lng": 32.834500, "address": "AVM Yakını, Ankara"},
    {"name": "Fitness Center Hub", "lat": 39.942800, "lng": 32.835800, "address": "Spor Salonu, Ankara"},
    {"name": "Market Square Prize", "lat": 39.941500, "lng": 32.836200, "address": "Pazar Meydanı, Ankara"},
    {"name": "Library Rewards", "lat": 39.942900, "lng": 32.834800, "address": "Kütüphane Yanı, Ankara"},
    {"name": "Park Avenue Stop", "lat": 39.943200, "lng": 32.835500, "address": "Park Caddesi, Ankara"},
    {"name": "Downtown Bistro", "lat": 39.941900, "lng": 32.835900, "address": "Şehir Merkezi, Ankara"},
    {"name": "Metro Station Cafe", "lat": 39.942600, "lng": 32.834300, "address": "Metro İstasyonu, Ankara"},
    {"name": "Plaza Coffee", "lat": 39.941300, "lng": 32.835600, "address": "Plaza Yakını, Ankara"},
]

async def add_custom_locations():
    async with async_session_factory() as db:
        # Get first sponsor
        result = await db.execute(select(Sponsor).limit(1))
        sponsor = result.scalar_one()
        
        for loc_data in CUSTOM_LOCATIONS:
            location = Location(
                id=uuid.uuid4(),
                sponsor_id=sponsor.id,
                name=loc_data["name"],
                description=f"Visit {loc_data['name']} to claim your reward!",
                latitude=loc_data["lat"],
                longitude=loc_data["lng"],
                address=loc_data["address"],
                radius_m=100,
                city="Ankara",
                is_active=True,
            )
            db.add(location)
            await db.flush()
            
            # Create reward template with random bearing and elevation
            reward_template = RewardTemplate(
                id=uuid.uuid4(),
                location_id=location.id,
                reward_type="points",
                reward_value=10,
                reward_description=f"+10 points at {loc_data['name']}",
                bearing_degrees=random.uniform(0.0, 360.0),
                elevation_degrees=random.uniform(-15.0, 15.0),
                is_active=True,
            )
            db.add(reward_template)
        
        await db.commit()
        print(f"✅ Added {len(CUSTOM_LOCATIONS)} locations around 39.942351, 32.835282!")

if __name__ == "__main__":
    asyncio.run(add_custom_locations())
