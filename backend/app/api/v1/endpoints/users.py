import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models import User
from app.schemas.user import UserOut

router = APIRouter()

UPLOADS_DIR = settings.base_dir / "uploads" / "avatars"
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG and WebP are accepted")
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    ext = (file.filename or "avatar").rsplit(".", 1)[-1].lower()
    fname = f"{current.id}_{uuid.uuid4().hex[:8]}.{ext}"
    dest = UPLOADS_DIR / fname
    content = await file.read()
    dest.write_bytes(content)
    avatar_url = f"/uploads/avatars/{fname}"
    current.avatar_url = avatar_url
    db.add(current)
    await db.commit()
    return {"avatar_url": avatar_url}


@router.get("/me", response_model=UserOut)
async def me(
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> User:
    # Re-fetch with profile eagerly loaded
    res = await db.execute(
        select(User).options(selectinload(User.profile)).where(User.id == current.id)
    )
    return res.scalar_one()
