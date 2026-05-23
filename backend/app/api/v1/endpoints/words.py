"""Vocabulary endpoints — browse words for a topic or globally, optionally filtered by CEFR level."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import Language, Topic, User, Word
from app.schemas.learning import WordOut

router = APIRouter()


@router.get("/search", response_model=list[WordOut])
async def search_words(
    language: str = Query(default="en", description="Language code (en, ru, kk, ...)"),
    level: str | None = Query(default=None, description="CEFR level filter (A1..C2)"),
    q: str | None = Query(default=None, description="Search lemma / translations"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Word]:
    """Global vocabulary browse: filter by language + CEFR level, optional substring search.

    Designed for the 'Vocabulary' tab so imported (CEFR-J / Oxford 5000) words
    that have no `topic_id` are still discoverable.
    """
    lang = (
        await db.execute(select(Language).where(Language.code == language))
    ).scalar_one_or_none()
    if lang is None:
        raise HTTPException(404, f"Language '{language}' not found")

    stmt = select(Word).where(Word.language_id == lang.id)
    if level:
        stmt = stmt.where(Word.level == level.upper())
    if q:
        like = f"%{q.strip().lower()}%"
        stmt = stmt.where(
            or_(
                Word.lemma.ilike(like),
                Word.translation_ru.ilike(like),
                Word.translation_kk.ilike(like),
            )
        )
    stmt = (
        stmt.order_by(
            Word.level,
            Word.sublevel,
            Word.frequency_rank.nullslast(),
            Word.lemma,
        )
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return list(rows)


@router.get("/by-topic/{topic_id}", response_model=list[WordOut])
async def list_words_by_topic(
    topic_id: int,
    level: str | None = Query(default=None, description="Filter by CEFR level (A1..C2)"),
    sublevel: int | None = Query(default=None, ge=1, le=2),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[Word]:
    topic = await db.get(Topic, topic_id)
    if topic is None:
        raise HTTPException(404, "Topic not found")

    stmt = select(Word).where(Word.topic_id == topic_id)
    if level:
        stmt = stmt.where(Word.level == level.upper())
    if sublevel:
        stmt = stmt.where(Word.sublevel == sublevel)
    stmt = stmt.order_by(Word.level, Word.sublevel, Word.frequency_rank.nullslast(), Word.lemma)

    rows = (await db.execute(stmt)).scalars().all()
    return list(rows)


@router.get("/{word_id}", response_model=WordOut)
async def get_word(
    word_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Word:
    word = await db.get(Word, word_id)
    if word is None:
        raise HTTPException(404, "Word not found")
    return word
