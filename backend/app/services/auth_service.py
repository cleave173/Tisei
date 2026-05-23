"""Authentication business logic — separated from HTTP layer."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.models import AuthProvider, Profile, RefreshToken, User
from app.schemas.auth import GoogleAuthRequest, LoginRequest, RegisterRequest, TokenPair


async def _issue_token_pair(db: AsyncSession, user: User) -> TokenPair:
    access = create_access_token(user.id)
    raw_refresh, expires_at = create_refresh_token(user.id)
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(raw_refresh),
            expires_at=expires_at,
        )
    )
    await db.flush()
    return TokenPair(access_token=access, refresh_token=raw_refresh)


async def register(db: AsyncSession, payload: RegisterRequest) -> TokenPair:
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        age=payload.age,
        provider=AuthProvider.email,
        is_active=True,
        is_verified=False,
    )
    db.add(user)
    await db.flush()
    db.add(Profile(user_id=user.id))
    await db.flush()
    return await _issue_token_pair(db, user)


async def login(db: AsyncSession, payload: LoginRequest) -> TokenPair:
    user = (await db.execute(select(User).where(User.email == payload.email))).scalar_one_or_none()
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account disabled")
    return await _issue_token_pair(db, user)


async def google_auth(db: AsyncSession, payload: GoogleAuthRequest) -> TokenPair:
    """Verify Google id_token, upsert user, issue our own JWT pair."""
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token

    from app.core.config import settings

    try:
        info = google_id_token.verify_oauth2_token(
            payload.id_token, google_requests.Request(), settings.google_client_id
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Google token: {exc}")

    google_sub = info.get("sub")
    email = info.get("email")
    name = info.get("name") or (email.split("@")[0] if email else "User")
    picture = info.get("picture")
    if not google_sub or not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed Google token")

    user = (
        await db.execute(
            select(User).where(
                (User.provider == AuthProvider.google) & (User.provider_id == google_sub)
            )
        )
    ).scalar_one_or_none()
    if user is None:
        user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()

    if user is None:
        user = User(
            email=email,
            full_name=name,
            avatar_url=picture,
            provider=AuthProvider.google,
            provider_id=google_sub,
            is_active=True,
            is_verified=True,
        )
        db.add(user)
        await db.flush()
        db.add(Profile(user_id=user.id))
    else:
        user.provider = AuthProvider.google
        user.provider_id = google_sub
        user.is_verified = True
        if picture and not user.avatar_url:
            user.avatar_url = picture

    await db.flush()
    return await _issue_token_pair(db, user)


async def refresh(db: AsyncSession, raw_refresh: str) -> TokenPair:
    token_hash = hash_refresh_token(raw_refresh)
    rt = (
        await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    ).scalar_one_or_none()
    if rt is None or rt.revoked or rt.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user = await db.get(User, rt.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Inactive user")

    rt.revoked = True  # rotate
    return await _issue_token_pair(db, user)
