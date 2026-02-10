# HotNCold 🔥❄️

A location-based treasure hunt mobile app where users explore real cities, discover sponsored locations on a map, scan QR codes, and earn rewards.

## Architecture

**Monorepo** with two main components:

| Component | Tech | Path |
|-----------|------|------|
| Backend API | Python / FastAPI / PostgreSQL / Redis | `backend/` |
| Mobile App | Flutter / Riverpod / flutter_map (OSM) | `mobile/` |

- **Auth**: Firebase Auth (Email, Google, Apple) — tokens verified server-side
- **Maps**: OpenStreetMap via `flutter_map`
- **State Management**: Riverpod
- **Database**: PostgreSQL with async SQLAlchemy + Alembic migrations
- **Caching/Rate Limiting**: Redis

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Python 3.12+
- Flutter 3.27+
- Firebase project (with service account JSON)

### Backend

```bash
# Copy env and add your Firebase credentials
cp backend/.env.example backend/.env

# Start infrastructure (Postgres + Redis + Backend)
docker compose up -d

# Or run locally:
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
python scripts/seed.py  # seed Istanbul test data
uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

> **Note**: Requires Firebase configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

## API Endpoints (MVP)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/users/me` | Current user profile |
| PATCH | `/users/me` | Update profile |
| GET | `/users/me/stats` | User scan statistics |
| GET | `/map/locations` | Nearby treasure locations |
| POST | `/qr/scan` | Scan a QR code |
| GET | `/users/me/rewards` | Reward wallet |

## Project Structure

```
backend/
  app/
    api/          # FastAPI route handlers
    core/         # Config, DB, auth, dependencies
    models/       # SQLAlchemy ORM models
    schemas/      # Pydantic request/response schemas
    services/     # Business logic (scan validation, geo)
    tasks/        # Background tasks
  alembic/        # Database migrations
  scripts/        # Seed data, utilities
  tests/          # pytest test suite

mobile/
  lib/
    core/         # Theme, constants, routing, API client
    features/
      auth/       # Login, register, auth provider
      home/       # Shell with bottom nav
      map/        # Map screen, location markers
      scanner/    # QR code scanner
      rewards/    # Reward wallet
      profile/    # User profile & settings
```

## Testing

```bash
# Backend
cd backend && pytest --cov=app -v

# Mobile
cd mobile && flutter test
```

## License

Proprietary — All rights reserved.