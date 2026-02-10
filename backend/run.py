#!/usr/bin/env python3
"""Run the HotNCold backend server accessible from network devices."""

import uvicorn
from app.main import app

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",  # Bind to all interfaces so phone can access
        port=8000,
        reload=True,  # Enable auto-reload for development
        log_level="info"
    )