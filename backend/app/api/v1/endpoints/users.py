from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select

from app.api.deps import get_current_user, get_db
from app.models import User
from app.schemas.user import UserOut

router = APIRouter()


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
