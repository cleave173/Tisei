from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Profile


def level_for_xp(xp: int) -> int:
    """Return the profile level for total XP.

    Level N requires N * 200 XP to advance to the next level. This mirrors the
    progress math used by the Flutter profile screen.
    """
    level = 1
    remaining = max(0, xp)
    while remaining >= level * 200:
        remaining -= level * 200
        level += 1
    return level


def apply_learning_activity(profile: Profile, xp_earned: int) -> None:
    """Apply XP, level, streak, and last-active updates for a learning action."""
    now = datetime.now(timezone.utc)
    today = now.date()
    last_active = profile.last_active_at
    last_day = last_active.date() if last_active else None

    if xp_earned > 0:
        profile.experience_points = (profile.experience_points or 0) + xp_earned
        profile.level = level_for_xp(profile.experience_points)

    if last_day is None:
        profile.streak_days = 1
    elif last_day == today:
        profile.streak_days = max(profile.streak_days or 0, 1)
    elif last_day == today - timedelta(days=1):
        profile.streak_days = (profile.streak_days or 0) + 1
    else:
        profile.streak_days = 1

    profile.last_active_at = now


async def apply_learning_activity_for_user(
    db: AsyncSession,
    user_id: int,
    xp_earned: int,
) -> Profile | None:
    profile = await db.get(Profile, user_id)
    if profile is None:
        return None
    apply_learning_activity(profile, xp_earned)
    return profile
