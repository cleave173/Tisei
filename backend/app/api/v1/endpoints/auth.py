import logging

from fastapi import APIRouter, Body, Depends, Request, status
from pydantic import BaseModel, EmailStr, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.core.limiter import limiter
from app.schemas.auth import (
    GoogleAuthRequest,
    LoginRequest,
    RegisterRequest,
    TokenPair,
)
from app.services import auth_service

log = logging.getLogger(__name__)

router = APIRouter()


# ── Request schemas ───────────────────────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(c.isalpha() for c in v):
            raise ValueError("Password must contain at least one letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one digit")
        return v


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    async with db.begin():
        return await auth_service.register(db, payload)


@router.post("/login", response_model=TokenPair)
@limiter.limit("10/minute")
async def login(
    request: Request,
    payload: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenPair:
    async with db.begin():
        return await auth_service.login(db, payload)


@router.post("/google", response_model=TokenPair)
async def google_auth(payload: GoogleAuthRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    async with db.begin():
        return await auth_service.google_auth(db, payload)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    refresh_token: str = Body(..., embed=True),
    db: AsyncSession = Depends(get_db),
) -> TokenPair:
    async with db.begin():
        return await auth_service.refresh(db, refresh_token)


@router.post("/forgot-password", status_code=status.HTTP_200_OK)
@limiter.limit("3/hour")
async def forgot_password(
    request: Request,
    payload: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Send a 6-digit OTP to the email. Always 200 to prevent email enumeration."""
    async with db.begin():
        await auth_service.forgot_password(db, str(payload.email))
    return {"message": "If this email is registered, a reset code has been sent."}


@router.post("/reset-password", status_code=status.HTTP_200_OK)
async def reset_password(
    payload: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Verify OTP and update the user's password."""
    async with db.begin():
        await auth_service.reset_password(
            db,
            str(payload.email),
            payload.code.strip(),
            payload.new_password,
        )
    return {"message": "Password updated successfully."}
