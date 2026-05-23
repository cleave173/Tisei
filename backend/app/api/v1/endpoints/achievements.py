from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import Achievement, User, UserAchievement

router = APIRouter()


@router.get("")
async def list_achievements(
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    achievements = list((await db.execute(select(Achievement).order_by(Achievement.id))).scalars())
    user_rows = (
        await db.execute(select(UserAchievement).where(UserAchievement.user_id == current.id))
    ).scalars().all()
    by_id = {ua.achievement_id: ua for ua in user_rows}
    return [
        {
            "id": a.id,
            "code": a.code,
            "name": a.name,
            "description": a.description,
            "stars": a.stars,
            "requirement_value": a.requirement_value,
            "progress": (by_id[a.id].progress if a.id in by_id else 0),
            "unlocked": bool(by_id.get(a.id) and by_id[a.id].unlocked_at),
        }
        for a in achievements
    ]
