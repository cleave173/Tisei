from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_optional, get_db
from app.models import CefrLevel, Language, Profile, Topic, User, VocabLessonProgress, Word
from app.schemas.learning import LanguageOut, TopicOut

router = APIRouter()


@router.get("", response_model=list[LanguageOut])
async def list_languages(db: AsyncSession = Depends(get_db)) -> list[Language]:
    res = await db.execute(
        select(Language).where(Language.is_active.is_(True)).order_by(Language.id)
    )
    return list(res.scalars().all())


@router.get("/{code}/topics", response_model=list[TopicOut])
async def list_topics(
    code: str,
    level: str | None = Query(
        default=None,
        description=(
            "CEFR level filter (A1..C2) or 'ANY' for all levels. "
            "When omitted and the request is authenticated, the user's profile "
            "level is used. 'ANY' disables filtering."
        ),
    ),
    current: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
) -> list[TopicOut]:
    lang = (await db.execute(select(Language).where(Language.code == code))).scalar_one_or_none()
    if lang is None:
        raise HTTPException(404, "Language not found")

    # Count only words whose level matches their topic's level — same filter
    # as `_load_topic_words` in vocab_lessons.py so the counts agree with the
    # actual lesson contents.
    word_counts_q = (
        select(Word.topic_id, func.count(Word.id).label("cnt"))
        .join(Topic, Topic.id == Word.topic_id)
        .where(Word.language_id == lang.id, Word.level == Topic.level)
        .group_by(Word.topic_id)
    )
    word_counts = {row.topic_id: row.cnt for row in (await db.execute(word_counts_q)).all()}

    # `lessons_count` now reflects the number of synthetic vocab lessons
    # (chunks of VOCAB_LESSON_SIZE words). The legacy curated Lesson table is
    # not exposed here anymore.
    from app.api.v1.endpoints.vocab_lessons import LESSON_SIZE as VOCAB_LESSON_SIZE
    lesson_counts = {
        tid: max(1, -(-c // VOCAB_LESSON_SIZE))  # ceil div, at least 1 if there are words
        for tid, c in word_counts.items()
        if c > 0
    }

    # Resolve effective level filter:
    #   - if authenticated: lock to user's profile level (or CefrLevel.A1 if NULL)
    #   - if not authenticated: fallback to level param (or no filter if not provided/ANY)
    effective_level: CefrLevel | None = None
    if current is not None:
        profile = await db.get(Profile, current.id)
        if profile is not None:
            effective_level = profile.cefr_level or CefrLevel.A1
    elif level:
        if level.upper() != "ANY":
            try:
                effective_level = CefrLevel(level.upper())
            except ValueError as exc:
                raise HTTPException(400, f"Invalid CEFR level: {level}") from exc

    stmt = select(Topic).where(Topic.language_id == lang.id)
    if effective_level is not None:
        stmt = stmt.where(Topic.level == effective_level)
    stmt = stmt.order_by(Topic.order, Topic.id)
    topics = (await db.execute(stmt)).scalars().all()

    # Count completed vocab lessons per topic for the authenticated user.
    completed_counts: dict[int, int] = {}
    if current is not None:
        comp_q = (
            select(VocabLessonProgress.topic_id, func.count(VocabLessonProgress.id).label("cnt"))
            .where(
                VocabLessonProgress.user_id == current.id,
                VocabLessonProgress.completed_at.is_not(None),
            )
            .group_by(VocabLessonProgress.topic_id)
        )
        completed_counts = {
            row.topic_id: row.cnt for row in (await db.execute(comp_q)).all()
        }

    return [
        TopicOut(
            id=t.id,
            slug=t.slug,
            title=t.title,
            title_ru=t.title_ru,
            title_kk=t.title_kk,
            level=t.level.value if hasattr(t.level, "value") else str(t.level),
            order=t.order,
            icon_url=t.icon_url,
            word_count=word_counts.get(t.id, 0),
            lessons_count=lesson_counts.get(t.id, 0),
            completed_lessons=completed_counts.get(t.id, 0),
        )
        for t in topics
    ]
