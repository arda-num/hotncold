"""Add Ankara Eryaman locations to the database."""

import asyncio
import random
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from app.core.database import async_session_factory
from app.models import Sponsor, Location, RewardTemplate

ANKARA_ERYAMAN_LOCATIONS = [
    {"name": "Eryaman Shopping Mall", "lat": 39.9825, "lng": 32.6580, "address": "Eryaman AVM, Etimesgut"},
    {"name": "Eryaman Park Cafe", "lat": 39.9870, "lng": 32.6620, "address": "Eryaman Park, Etimesgut"},
    {"name": "Eryaman Stadium Rewards", "lat": 39.9790, "lng": 32.6550, "address": "Eryaman Stadyumu Yanı, Etimesgut"},
    {"name": "Eryaman Metro Station", "lat": 39.9812, "lng": 32.6595, "address": "Eryaman Metro İstasyonu, Etimesgut"},
    {"name": "Eryaman Central Market", "lat": 39.9840, "lng": 32.6600, "address": "Eryaman Merkez Pazar, Etimesgut"},
]

async def add_ankara_locations():
    async with async_session_factory() as db:
        # Get first sponsor
        result = await db.execute(select(Sponsor).limit(1))
        sponsor = result.scalar_one()
        
        for loc_data in ANKARA_ERYAMAN_LOCATIONS:
            location = Location(
                id=uuid.uuid4(),
                sponsor_id=sponsor.id,
                name=loc_data["name"],
                description=f"Visit {loc_data['name']} to claim your reward!",
                latitude=loc_data["lat"],
                longitude=loc_data["lng"],
                address=loc_data["address"],
                radius_m=100000,
                city="Ankara",
                is_active=True,
            )
            db.add(location)
            await db.flush()
            
            # Create reward template with random bearing
            reward_template = RewardTemplate(
                id=uuid.uuid4(),
                location_id=location.id,
                reward_type="points",
                reward_value=10,
                reward_description=f"+10 points at {loc_data['name']}",
                bearing_degrees=random.uniform(0.0, 360.0),
                elevation_degrees=0.0,
                is_active=True,
            )
            db.add(reward_template)
        
        await db.commit()
        print(f"✅ Added {len(ANKARA_ERYAMAN_LOCATIONS)} locations in Ankara Eryaman!")

if __name__ == "__main__":
    asyncio.run(add_ankara_locations())
