"""FastAPI dependencies for injection."""

from __future__ import annotations

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import verify_firebase_token
from app.models.user import User

bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Verify the Firebase ID token from the Authorization header,
    find or auto-create the corresponding User row, and return it.
    """
    decoded = verify_firebase_token(credentials.credentials)
    firebase_uid: str = decoded["uid"]
    email: str = decoded.get("email", "")
    name: str = decoded.get("name", "")
    picture: str = decoded.get("picture", "")

    # Look up existing user
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()

    if user is None:
        # Auto-create on first authenticated request
        user = User(
            firebase_uid=firebase_uid,
            email=email,
            display_name=name or email.split("@")[0],
            avatar_url=picture,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)

    return user


async def get_current_active_user(
    user: User = Depends(get_current_user),
) -> User:
    """Ensure the user account is active."""
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated",
        )
    return user
