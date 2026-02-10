from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables / .env file."""

    # App
    app_name: str = "HotNCold"
    app_version: str = "0.1.0"
    debug: bool = False
    secret_key: str = "change-me-in-production"

    # Database
    database_url: str = "postgresql+asyncpg://hotncold:hotncold@localhost:5432/hotncold"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Firebase
    firebase_project_id: str = ""
    google_application_credentials: str = "firebase-service-account.json"

    # CORS
    cors_origins: list[str] = Field(default=["*"])  # Allow all origins for mobile development

    # Scan limits
    max_scans_per_hour: int = 10
    scan_cooldown_seconds: int = 60
    max_daily_scans: int = 20
    scan_radius_meters: int = 100

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
        "extra": "ignore",  # Ignore extra fields in .env
    }


settings = Settings()
