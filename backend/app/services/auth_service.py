"""Authentication business logic — separated from HTTP layer."""
from __future__ import annotations

import logging
import random
import asyncio
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.models import AuthProvider, Profile, RefreshToken, User
from app.models.password_reset import PasswordResetCode
from app.schemas.auth import GoogleAuthRequest, LoginRequest, RegisterRequest, TokenPair
from app.services import email_service

log = logging.getLogger(__name__)


async def _send_reset_code_safely(email: str, code: str, user_id: int) -> None:
    try:
        await email_service.send_reset_code(email, code)
    except Exception:
        # Password reset must not expose mail-provider failures as a 500 or
        # reveal whether an email exists. Railway logs contain provider errors.
        log.exception("Password reset email delivery failed for user_id=%s", user_id)


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


async def forgot_password(db: AsyncSession, email: str) -> None:
    """Generate a 6-digit OTP and send it via email. Always succeeds (no enumeration)."""
    user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
    if user is None:
        return  # silent — don't reveal whether email exists

    # Invalidate all previous codes for this user
    await db.execute(delete(PasswordResetCode).where(PasswordResetCode.user_id == user.id))

    code = f"{random.randint(0, 999_999):06d}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.reset_code_expire_minutes)
    db.add(PasswordResetCode(user_id=user.id, code=code, expires_at=expires_at))
    await db.flush()

    if settings.log_reset_codes:
        log.warning("Password reset code for %s: %s", user.email, code)

    asyncio.create_task(_send_reset_code_safely(user.email, code, user.id))


async def reset_password(db: AsyncSession, email: str, code: str, new_password: str) -> None:
    """Verify OTP and update password."""
    user = (await db.execute(select(User).where(User.email == email))).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired code")

    now = datetime.now(timezone.utc)
    reset = (
        await db.execute(
            select(PasswordResetCode).where(
                PasswordResetCode.user_id == user.id,
                PasswordResetCode.code == code,
                PasswordResetCode.used.is_(False),
                PasswordResetCode.expires_at > now,
            )
        )
    ).scalar_one_or_none()

    if reset is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired code")

    if user.password_hash and verify_password(new_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the old password",
        )

    reset.used = True
    user.password_hash = hash_password(new_password)
    await db.flush()
