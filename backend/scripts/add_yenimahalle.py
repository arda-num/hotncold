"""Add Ankara Yenimahalle locations to the database."""

import asyncio
import random
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select
from app.core.database import async_session_factory
from app.models import Sponsor, Location, RewardTemplate

# Yenimahalle, Ankara locations
YENIMAHALLE_LOCATIONS = [
    {"name": "Yenimahalle Park Cafe", "lat": 39.9650, "lng": 32.8050, "address": "Yenimahalle Park, Ankara"},
    {"name": "Metro Cafe Rewards", "lat": 39.9620, "lng": 32.8080, "address": "Metro Yakını, Yenimahalle"},
    {"name": "Yenimahalle Market", "lat": 39.9680, "lng": 32.8100, "address": "Yenimahalle Pazar Yeri, Ankara"},
    {"name": "Merkez Shopping", "lat": 39.9640, "lng": 32.8070, "address": "Merkez AVM Yakını, Yenimahalle"},
    {"name": "Yenimahalle Bistro", "lat": 39.9665, "lng": 32.8065, "address": "Yenimahalle Merkez, Ankara"},
    {"name": "Park Avenue Coffee", "lat": 39.9685, "lng": 32.8090, "address": "Park Caddesi, Yenimahalle"},
    {"name": "Yenimahalle Gym Hub", "lat": 39.9630, "lng": 32.8055, "address": "Spor Merkezi, Yenimahalle"},
    {"name": "City Center Rewards", "lat": 39.9670, "lng": 32.8075, "address": "Şehir Merkezi, Yenimahalle"},
]

async def add_yenimahalle_locations():
    async with async_session_factory() as db:
        # Get first sponsor
        result = await db.execute(select(Sponsor).limit(1))
        sponsor = result.scalar_one()
        
        for loc_data in YENIMAHALLE_LOCATIONS:
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
                elevation_degrees=random.uniform(-15.0, 15.0),  # Random elevation
                is_active=True,
            )
            db.add(reward_template)
        
        await db.commit()
        print(f"✅ Added {len(YENIMAHALLE_LOCATIONS)} locations in Yenimahalle, Ankara!")

if __name__ == "__main__":
    asyncio.run(add_yenimahalle_locations())
