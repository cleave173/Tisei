from fastapi import APIRouter, Body, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.schemas.auth import (
    GoogleAuthRequest,
    LoginRequest,
    RegisterRequest,
    TokenPair,
)
from app.services import auth_service

router = APIRouter()


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
    async with db.begin():
        return await auth_service.register(db, payload)


@router.post("/login", response_model=TokenPair)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> TokenPair:
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
