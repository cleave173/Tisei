"""Achievement granting service.

Call `grant_achievements(db, user_id)` after any user action that could
trigger an unlock (lesson complete, XP gained, translation saved, etc.).
The caller is responsible for committing the session afterwards.
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Achievement, UserAchievement, VocabLessonProgress
from app.models.translation import TranslationHistory
from app.models.user import Profile


async def grant_achievements(db: AsyncSession, user_id: int) -> list[str]:
    """Evaluate all achievement conditions and unlock newly earned ones.

    Returns the list of achievement *codes* that were unlocked during this call.
    Progress is only ever moved forward (never decreased).
    """
    profile = await db.get(Profile, user_id)
    if profile is None:
        return []

    # ── Compute live progress values ─────────────────────────────────────────

    completed_lessons: int = (
        await db.execute(
            select(func.count(VocabLessonProgress.id)).where(
                VocabLessonProgress.user_id == user_id,
                VocabLessonProgress.completed_at.is_not(None),
            )
        )
    ).scalar_one()

    translator_count: int = (
        await db.execute(
            select(func.count(TranslationHistory.id)).where(
                TranslationHistory.user_id == user_id,
            )
        )
    ).scalar_one()

    xp: int = profile.experience_points or 0
    streak: int = profile.streak_days or 0
    # Approximate word count: completed lessons × average lesson size (6 words)
    words_learned: int = completed_lessons * 6

    progress_map: dict[str, int] = {
        "first_lesson": completed_lessons,
        "warmup_5": completed_lessons,
        "studious_10": completed_lessons,
        "chapter_runner": completed_lessons,
        "studious_50": completed_lessons,
        "century_club": completed_lessons,
        "xp_spark": xp,
        "ambitious": xp,
        "xp_engine": xp,
        "spark_3": streak,
        "streak_7": streak,
        "fortnight_focus": streak,
        "streak_30": streak,
        "habit_anchor": streak,
        "word_scout": words_learned,
        "vocab_100": words_learned,
        "lexicon_keeper": words_learned,
        "translator_50": translator_count,
        # "quickie" requires timing data — skipped here; grant it externally if needed.
    }

    # ── Load achievements and existing user rows ──────────────────────────────

    all_achievements = list((await db.execute(select(Achievement))).scalars())
    user_rows = list(
        (
            await db.execute(
                select(UserAchievement).where(UserAchievement.user_id == user_id)
            )
        ).scalars()
    )
    ua_by_id: dict[int, UserAchievement] = {ua.achievement_id: ua for ua in user_rows}

    newly_unlocked: list[str] = []

    for achievement in all_achievements:
        current_progress = progress_map.get(achievement.code, 0)

        ua = ua_by_id.get(achievement.id)
        if ua is None:
            ua = UserAchievement(
                user_id=user_id,
                achievement_id=achievement.id,
                progress=current_progress,
            )
            db.add(ua)
            ua_by_id[achievement.id] = ua
        elif current_progress > ua.progress:
            ua.progress = current_progress

        if ua.unlocked_at is None and current_progress >= achievement.requirement_value:
            ua.unlocked_at = datetime.now(timezone.utc)
            newly_unlocked.append(achievement.code)

    await db.flush()
    return newly_unlocked
