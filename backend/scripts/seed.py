"""Seed script: populates the database with sample data for Istanbul."""

import asyncio
import random
import sys
import uuid
from pathlib import Path

# Add parent directory to path so we can import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import async_session_factory, engine, Base
from app.models import Sponsor, Location, RewardTemplate


ISTANBUL_LOCATIONS = [
    {"name": "Taksim Square Coffee", "lat": 41.0370, "lng": 28.9850, "address": "Taksim Square, Beyoğlu"},
    {"name": "Grand Bazaar Treasures", "lat": 41.0106, "lng": 28.9682, "address": "Grand Bazaar, Fatih"},
    {"name": "Galata Tower View", "lat": 41.0256, "lng": 28.9741, "address": "Galata Tower, Beyoğlu"},
    {"name": "Istiklal Street Bites", "lat": 41.0340, "lng": 28.9770, "address": "İstiklal Cd., Beyoğlu"},
    {"name": "Kadıköy Market Walk", "lat": 40.9903, "lng": 29.0291, "address": "Kadıköy, İstanbul"},
    {"name": "Ortaköy Waffle Stop", "lat": 41.0476, "lng": 29.0276, "address": "Ortaköy, Beşiktaş"},
    {"name": "Beşiktaş Fitness Hub", "lat": 41.0430, "lng": 29.0060, "address": "Beşiktaş, İstanbul"},
    {"name": "Sultanahmet Discovery", "lat": 41.0054, "lng": 28.9768, "address": "Sultanahmet, Fatih"},
    {"name": "Karaköy Brew House", "lat": 41.0224, "lng": 28.9774, "address": "Karaköy, Beyoğlu"},
    {"name": "Balat Art Corner", "lat": 41.0295, "lng": 28.9493, "address": "Balat, Fatih"},
    {"name": "Bebek Shoreline Cafe", "lat": 41.0764, "lng": 29.0435, "address": "Bebek, Beşiktaş"},
    {"name": "Moda Beach Rewards", "lat": 40.9823, "lng": 29.0327, "address": "Moda, Kadıköy"},
    {"name": "Eminönü Spice Stop", "lat": 41.0167, "lng": 28.9700, "address": "Eminönü, Fatih"},
    {"name": "Çamlıca Hill Prize", "lat": 41.0271, "lng": 29.0685, "address": "Çamlıca, Üsküdar"},
    {"name": "Nişantaşı Fashion Drop", "lat": 41.0475, "lng": 28.9944, "address": "Nişantaşı, Şişli"},
]

ESKISEHIR_LOCATIONS = [
    {"name": "Eskişehir Clock Tower", "lat": 39.7667, "lng": 30.5250, "address": "Saat Kulesi, Odunpazarı"},
    {"name": "Porsuk River Park", "lat": 39.7720, "lng": 30.5200, "address": "Porsuk Çayı, Tepebaşı"},
    {"name": "Anadolu University", "lat": 39.7940, "lng": 30.5050, "address": "Anadolu Üniversitesi, Yunusemre"},
    {"name": "Kentpark Shopping", "lat": 39.9920, "lng": 30.0040, "address": "Kentpark AVM, Tepebaşı"},
    {"name": "Eskişehir Museum", "lat": 39.7680, "lng": 30.5220, "address": "Eskişehir Müzesi, Odunpazarı"},
]

ANKARA_ERYAMAN_LOCATIONS = [
    {"name": "Eryaman Shopping Mall", "lat": 39.9825, "lng": 32.6580, "address": "Eryaman AVM, Etimesgut"},
    {"name": "Eryaman Park Cafe", "lat": 39.9870, "lng": 32.6620, "address": "Eryaman Park, Etimesgut"},
    {"name": "Eryaman Stadium Rewards", "lat": 39.9790, "lng": 32.6550, "address": "Eryaman Stadyumu Yanı, Etimesgut"},
    {"name": "Eryaman Metro Station", "lat": 39.9812, "lng": 32.6595, "address": "Eryaman Metro İstasyonu, Etimesgut"},
    {"name": "Eryaman Central Market", "lat": 39.9840, "lng": 32.6600, "address": "Eryaman Merkez Pazar, Etimesgut"},
]


async def seed():
    """Create seed data: 1 sponsor, locations in multiple cities, 1 reward template per location."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_factory() as db:
        # Create pilot sponsor
        sponsor = Sponsor(
            id=uuid.uuid4(),
            name="HotNCold Pilot Sponsor",
            logo_url=None,
            contact_email="sponsor@hotncold.com",
        )
        db.add(sponsor)
        await db.flush()

        all_locations = [
            ("Istanbul", ISTANBUL_LOCATIONS),
            ("Eskisehir", ESKISEHIR_LOCATIONS),
            ("Ankara", ANKARA_ERYAMAN_LOCATIONS),
        ]

        total_index = 0
        for city, locations in all_locations:
            for loc_data in locations:
                location = Location(
                    id=uuid.uuid4(),
                    sponsor_id=sponsor.id,
                    name=loc_data["name"],
                    description=f"Visit {loc_data['name']} to claim your reward!",
                    latitude=loc_data["lat"],
                    longitude=loc_data["lng"],
                    address=loc_data["address"],
                    radius_m=100,
                    city=city,
                    is_active=True,
                )
                db.add(location)
                await db.flush()

                # Create a reward template for the location
                reward_template = RewardTemplate(
                    id=uuid.uuid4(),
                    location_id=location.id,
                    reward_type="points",
                    reward_value=10,
                    reward_description=f"+10 points at {loc_data['name']}",
                    bearing_degrees=random.uniform(0.0, 360.0),  # Random direction (0-360°)
                    elevation_degrees=0.0,  # At eye level
                    is_active=True,
                )
                db.add(reward_template)
                total_index += 1

        await db.commit()
        print(f"✅ Seeded {total_index} locations across {len(all_locations)} cities with reward templates.")


if __name__ == "__main__":
    asyncio.run(seed())
