"""Vocab-lesson endpoints.

A vocab lesson is a synthetic chunk of N words inside a topic. The lesson
identity is (topic_id, lesson_index). There is no curated content — words
are pulled from the topic and chunked by `LESSON_SIZE`. Progress is tracked
per stage in `VocabLessonProgress`.
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import Profile, Topic, User, VocabLessonProgress, Word
from app.services import achievement_service
from app.schemas.learning import (
    VocabLessonOut,
    VocabLessonProgressOut,
    VocabLessonsListOut,
    VocabStageIn,
    VocabStageOut,
    WordOut,
)

router = APIRouter()

# Preferred number of words per vocab lesson. The actual lesson sizes are
# rebalanced so a topic with N words yields ceil(N / LESSON_SIZE) lessons of
# almost equal size (e.g. 10 words → 5+5, not 8+2).
LESSON_SIZE = 6
# Hard cap so very small topics still produce at least one lesson.
MIN_WORDS_PER_LESSON = 3
# XP awarded per completed stage (4 stages → up to 4 * STAGE_XP per lesson).
STAGE_XP = 5
# Bonus XP for finishing all four stages.
COMPLETION_BONUS = 10

_VALID_STAGES = ("cards", "listening", "mc", "speaking")


def _is_completed(p: VocabLessonProgress) -> bool:
    return p.cards_done and p.listening_done and p.mc_done and p.speaking_done


def _progress_out(p: VocabLessonProgress | None) -> VocabLessonProgressOut:
    if p is None:
        return VocabLessonProgressOut()
    return VocabLessonProgressOut(
        cards_done=p.cards_done,
        listening_done=p.listening_done,
        mc_done=p.mc_done,
        speaking_done=p.speaking_done,
        is_completed=_is_completed(p),
        xp_earned=p.xp_earned,
    )


def _chunk_words(words: list[Word]) -> list[list[Word]]:
    """Split words into balanced lessons.

    The number of lessons is ``ceil(N / LESSON_SIZE)``; words are then spread
    as evenly as possible so chunks differ by at most 1 element. Examples
    (LESSON_SIZE=6):

        8  → 4+4
        10 → 5+5
        12 → 6+6
        17 → 6+6+5
        22 → 6+6+5+5
        27 → 6+6+5+5+5

    Topics with fewer than ``MIN_WORDS_PER_LESSON`` words still yield a single
    lesson so progress can be tracked.
    """
    n = len(words)
    if n == 0:
        return []
    if n <= MIN_WORDS_PER_LESSON:
        return [words]
    lessons = max(1, -(-n // LESSON_SIZE))  # ceil(n / LESSON_SIZE)
    base, extra = divmod(n, lessons)  # `extra` chunks get one more word
    chunks: list[list[Word]] = []
    start = 0
    for i in range(lessons):
        size = base + (1 if i < extra else 0)
        chunks.append(words[start : start + size])
        start += size
    return chunks


async def _load_topic_words(db: AsyncSession, topic_id: int) -> list[Word]:
    """Return a stable, ordered slice of words for a topic.

    Only words whose own CEFR level matches the topic's level are included —
    this guarantees a user studying at level X only learns level-X vocabulary,
    even if the seed data put some higher-level words into the same topic.

    Ordering: by frequency_rank (NULLS LAST), then id. This keeps lesson 1
    composed of the most common words.
    """
    topic = await db.get(Topic, topic_id)
    if topic is None:
        return []
    topic_level = topic.level.value if hasattr(topic.level, "value") else str(topic.level)
    rows = (
        await db.execute(
            select(Word)
            .where(Word.topic_id == topic_id, Word.level == topic_level)
            .order_by(Word.frequency_rank.is_(None), Word.frequency_rank, Word.id)
        )
    ).scalars().all()
    return list(rows)


def _word_out(w: Word) -> WordOut:
    return WordOut.model_validate(w)


@router.get("/topic/{topic_id}", response_model=VocabLessonsListOut)
async def list_vocab_lessons(
    topic_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VocabLessonsListOut:
    topic = await db.get(Topic, topic_id)
    if topic is None:
        raise HTTPException(404, "Topic not found")

    words = await _load_topic_words(db, topic_id)
    chunks = _chunk_words(words)

    prog_rows = (
        await db.execute(
            select(VocabLessonProgress).where(
                VocabLessonProgress.user_id == current.id,
                VocabLessonProgress.topic_id == topic_id,
            )
        )
    ).scalars().all()
    by_index = {p.lesson_index: p for p in prog_rows}

    lessons: list[VocabLessonOut] = []
    for idx, chunk in enumerate(chunks):
        lessons.append(
            VocabLessonOut(
                index=idx,
                title=f"Lesson {idx + 1}",
                words=[_word_out(w) for w in chunk],
                progress=_progress_out(by_index.get(idx)),
            )
        )

    return VocabLessonsListOut(
        topic_id=topic.id,
        topic_title=topic.title,
        topic_title_ru=topic.title_ru,
        topic_title_kk=topic.title_kk,
        topic_level=topic.level.value if hasattr(topic.level, "value") else str(topic.level),
        lesson_size=LESSON_SIZE,
        lessons=lessons,
    )


@router.get("/topic/{topic_id}/{lesson_index}", response_model=VocabLessonOut)
async def get_vocab_lesson(
    topic_id: int,
    lesson_index: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VocabLessonOut:
    topic = await db.get(Topic, topic_id)
    if topic is None:
        raise HTTPException(404, "Topic not found")

    words = await _load_topic_words(db, topic_id)
    chunks = _chunk_words(words)
    if lesson_index < 0 or lesson_index >= len(chunks):
        raise HTTPException(404, "Lesson not found")

    prog = (
        await db.execute(
            select(VocabLessonProgress).where(
                VocabLessonProgress.user_id == current.id,
                VocabLessonProgress.topic_id == topic_id,
                VocabLessonProgress.lesson_index == lesson_index,
            )
        )
    ).scalar_one_or_none()

    return VocabLessonOut(
        index=lesson_index,
        title=f"Lesson {lesson_index + 1}",
        words=[_word_out(w) for w in chunks[lesson_index]],
        progress=_progress_out(prog),
    )


@router.post(
    "/topic/{topic_id}/{lesson_index}/stage",
    response_model=VocabStageOut,
)
async def mark_stage_complete(
    topic_id: int,
    lesson_index: int,
    payload: VocabStageIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VocabStageOut:
    if payload.stage not in _VALID_STAGES:
        raise HTTPException(400, f"Invalid stage: {payload.stage}")

    topic = await db.get(Topic, topic_id)
    if topic is None:
        raise HTTPException(404, "Topic not found")

    # Validate lesson_index against actual word count.
    words = await _load_topic_words(db, topic_id)
    chunks = _chunk_words(words)
    if lesson_index < 0 or lesson_index >= len(chunks):
        raise HTTPException(404, "Lesson not found")

    prog = (
        await db.execute(
            select(VocabLessonProgress).where(
                VocabLessonProgress.user_id == current.id,
                VocabLessonProgress.topic_id == topic_id,
                VocabLessonProgress.lesson_index == lesson_index,
            )
        )
    ).scalar_one_or_none()
    if prog is None:
        prog = VocabLessonProgress(
            user_id=current.id,
            topic_id=topic_id,
            lesson_index=lesson_index,
        )
        db.add(prog)

    # Award XP only on first transition of a stage to "done".
    awarded = 0
    field = f"{payload.stage}_done"
    if not getattr(prog, field):
        setattr(prog, field, True)
        awarded += STAGE_XP

    # Lesson completion bonus on first transition to fully-done.
    was_completed = bool(prog.completed_at)
    if _is_completed(prog) and not was_completed:
        prog.completed_at = datetime.now(timezone.utc)
        awarded += COMPLETION_BONUS

    prog.xp_earned = (prog.xp_earned or 0) + awarded

    if awarded > 0:
        profile = await db.get(Profile, current.id)
        if profile is not None:
            profile.experience_points = (profile.experience_points or 0) + awarded

    await achievement_service.grant_achievements(db, current.id)
    await db.commit()
    await db.refresh(prog)

    return VocabStageOut(progress=_progress_out(prog), xp_earned_now=awarded)
