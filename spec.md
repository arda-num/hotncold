
# HotNCold – Project Specification

## 1. Project Overview
**Project Name:** HotNCold  
**Description:**  
HotNCold is a location-based treasure hunt mobile application where users explore real cities, discover sponsored locations on a map, scan QR codes, and earn rewards such as points, coupons, or physical products.

The experience is inspired by Pokémon Go but focused on real-world brand activations and measurable sponsor ROI.

---

## 2. Goals & Objectives
- Increase foot traffic to sponsor locations
- Create a fun, repeatable gamified experience
- Enable brands to distribute rewards efficiently
- Provide analytics and ROI tracking for sponsors
- Build a scalable city-based platform

---

## 3. Target Audience
### Users
- Age: 16–35
- Urban residents
- Students, young professionals, explorers

### Sponsors
- Cafes & restaurants
- Retail stores
- Gyms & entertainment venues
- Consumer brands

---

## 4. Core Features

### 4.1 User Features
- User authentication (Email, Google, Apple)
- City-based interactive map
- Nearby treasure locations
- QR code scanning
- Reward wallet (points, coupons, prizes)
- User profile & statistics
- Push notifications

### 4.2 Map System
- Map provider: Google Maps or Mapbox
- Location-based visibility
- Treasure points disappear after max scans
- Distance-based scan validation

### 4.3 QR Code System
- Dynamic, backend-validated QR codes
- Each QR code contains:
  - Unique ID
  - GPS coordinates
  - Max scan limit
  - Expiration date
- One scan per user per QR

### 4.4 Reward System
- Points
- Discount coupons
- Raffle entries
- Limited physical products (event-based)

---

## 5. Sponsor Features

### 5.1 Sponsor Dashboard (Web)
- Manage locations
- Create QR codes
- Define rewards
- View analytics

### 5.2 Analytics
- Total scans
- Unique users
- Scan timestamps
- Location heatmaps
- Reward redemption rates

---

## 6. Game Mechanics
- Daily scan limits
- Cooldown between scans
- Limited-time events
- Optional leaderboards
- Seasonal campaigns

---

## 7. Anti-Cheating & Security
- GPS validation on scan
- Device fingerprinting
- Backend QR verification
- Rate limiting
- Abuse detection

---

## 8. Technology Stack

### 8.1 Mobile Application
- Framework: **Flutter**
- Platforms: iOS & Android
- State Management: Riverpod / Bloc
- Maps: Google Maps / Mapbox
- QR Scanning: Mobile camera integration

### 8.2 Backend
- Language: **Python**
- Framework: **FastAPI**
- Authentication: JWT (OAuth optional)
- API Style: REST
- Background tasks: Celery / FastAPI BackgroundTasks

### 8.3 Database
- PostgreSQL (primary)
- Redis (caching & rate limiting)

### 8.4 Infrastructure
- Cloud: AWS / GCP / Azure
- Object Storage: S3-compatible
- CI/CD: GitHub Actions
- Containerization: Docker

---

## 9. Backend Architecture (FastAPI)

### Core Services
- Auth Service
- User Service
- Location Service
- QR Validation Service
- Reward Engine
- Analytics Service

### Key Endpoints (Example)
- POST /auth/login
- GET /map/locations
- POST /qr/scan
- GET /user/rewards
- GET /sponsor/analytics

---

## 10. Database Models (High Level)
- User
- Sponsor
- Location
- QRCode
- Reward
- ScanLog

---

## 11. MVP Scope (Phase 1)
- User authentication
- Map with limited locations
- QR scan validation
- Point-based rewards
- One pilot sponsor
- Single city deployment

---

## 12. Monetization Model
- Sponsored campaigns
- Premium map placement
- Event-based hunts
- Future in-app purchases

---

## 13. Legal & Compliance
- QR placement permissions
- GDPR / KVKK compliance
- Terms of Service & Privacy Policy
- Age restrictions

---

## 14. Future Enhancements
- AR mode
- Team-based hunts
- Social sharing
- Advanced sponsor targeting
- International expansion

---

## 15. Success Metrics
- Daily Active Users (DAU)
- Retention rate
- Scan-to-visit conversion
- Sponsor renewal rate
- Cost per acquisition (CPA)

---

**HotNCold** turns cities into interactive playgrounds while delivering measurable value to brands.
