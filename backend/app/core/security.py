"""Firebase authentication utilities."""

import os
from pathlib import Path

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
from fastapi import HTTPException, status

from app.core import settings


def init_firebase() -> None:
    """Initialize the Firebase Admin SDK (idempotent)."""
    if not firebase_admin._apps:
        # Check if service account file exists
        cred_path = Path(settings.google_application_credentials)
        if not cred_path.is_absolute():
            # Make path relative to backend directory
            cred_path = Path(__file__).parent.parent.parent / settings.google_application_credentials
        
        if cred_path.exists():
            cred = credentials.Certificate(str(cred_path))
        else:
            # Fall back to Application Default Credentials for development
            print(f"⚠️  Firebase service account not found at {cred_path}")
            print("   Using Application Default Credentials (auth will not work until service account is configured)")
            cred = credentials.ApplicationDefault()
        
        firebase_admin.initialize_app(cred, {"projectId": settings.firebase_project_id})


def verify_firebase_token(id_token: str) -> dict:
    """
    Verify a Firebase ID token and return the decoded claims.

    Raises HTTPException 401 on invalid / expired tokens.
    """
    try:
        decoded = firebase_auth.verify_id_token(id_token)
        return decoded
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase token has expired",
        )
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )
