"""Assessment service: generates placement / level-up tests and scores answers.

## Placement test (first run after registration)
30 multiple-choice questions stratified across CEFR levels A1..C2 (5 each).
Question = "What does <lemma> mean?" with 4 translation options (1 correct,
3 distractors picked from words of the same level).

Final level estimation:
    estimated_level = highest level X where correct(X) >= PASS_THRESHOLD
                       AND correct(L) >= PASS_THRESHOLD for every L < X
If no level is passed, estimated_level = "A1" (we still let the user start).

## Level-up test
20 questions strictly at the user's current level. Pass threshold 80%.
On pass we bump `Profile.cefr_level` to the next CEFR tier.

## Privacy / cheating note
The MCQ format inherently leaks the correct answer to a determined cheater
(they can hit `/words/{id}` to see the translation). This is acceptable —
self-placement isn't high-stakes; cheating only harms the cheater.
"""
from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AssessmentKind,
    CefrLevel,
    Language,
    LevelAssessment,
    Profile,
    Topic,
    User,
    VocabLessonProgress,
    Word,
)

# Must stay in sync with LESSON_SIZE in vocab_lessons.py
_VOCAB_LESSON_SIZE = 6

# Public (consumed in routes / schemas)
LEVEL_ORDER: list[CefrLevel] = [
    CefrLevel.A1,
    CefrLevel.A2,
    CefrLevel.B1,
    CefrLevel.B2,
    CefrLevel.C1,
    CefrLevel.C2,
]

PLACEMENT_QUESTIONS_PER_LEVEL = 5
PLACEMENT_TOTAL = PLACEMENT_QUESTIONS_PER_LEVEL * len(LEVEL_ORDER)
PLACEMENT_PASS_PER_LEVEL = 3  # 3/5 = 60%

LEVEL_UP_TOTAL = 20
LEVEL_UP_PASS_RATIO = 0.8  # 16/20

# How many words to keep as "distractor pool" per level. Bigger = more variety.
_DISTRACTOR_POOL = 60


# ---------------------------------------------------------------------------
# DTOs
# ---------------------------------------------------------------------------

@dataclass
class GeneratedQuestion:
    level: CefrLevel
    word_id: int
    lemma: str
    ipa: str | None
    options: list[str]  # 4 translations, shuffled


@dataclass
class Answer:
    word_id: int
    chosen: str


@dataclass
class ScoreResult:
    scores_by_level: dict[str, dict[str, int]]  # {"A1": {"correct":5, "total":5}, ...}
    total_correct: int
    total_questions: int
    estimated_level: CefrLevel | None  # for placement
    passed: bool
    new_level: CefrLevel | None  # for level-up: the level user was promoted to


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _translation_field(interface_language: str) -> str:
    """Return Word column name used as the 'correct translation' for this UI lang."""
    if interface_language.lower().startswith("kk"):
        return "translation_kk"
    return "translation_ru"


def _next_level(level: CefrLevel) -> CefrLevel | None:
    try:
        idx = LEVEL_ORDER.index(level)
    except ValueError:
        return None
    return LEVEL_ORDER[idx + 1] if idx + 1 < len(LEVEL_ORDER) else None


async def _resolve_language_id(db: AsyncSession, code: str) -> int:
    lang = (
        await db.execute(select(Language).where(Language.code == code))
    ).scalar_one_or_none()
    if lang is None:
        raise ValueError(f"Language '{code}' not found")
    return lang.id


async def _get_profile(db: AsyncSession, user: User) -> Profile:
    res = (
        await db.execute(select(Profile).where(Profile.user_id == user.id))
    ).scalar_one_or_none()
    if res is None:
        raise ValueError(f"Profile not found for user {user.id}")
    return res


# ---------------------------------------------------------------------------
# Question generation
# ---------------------------------------------------------------------------

async def _candidate_words(
    db: AsyncSession,
    *,
    language_id: int,
    level: CefrLevel,
    translation_col: str,
    limit: int,
) -> list[Word]:
    """Return random words at `level` that have a non-null translation."""
    tcol = getattr(Word, translation_col)
    stmt = (
        select(Word)
        .where(Word.language_id == language_id)
        .where(Word.level == level)
        .where(tcol.is_not(None))
        .where(func.length(tcol) > 0)
        .order_by(func.random())
        .limit(limit)
    )
    return list((await db.execute(stmt)).scalars().all())


def _build_question(
    word: Word,
    pool: list[Word],
    translation_col: str,
    rng: random.Random,
) -> GeneratedQuestion | None:
    """Return MCQ with 1 correct + 3 distinct distractor translations."""
    correct = (getattr(word, translation_col) or "").strip()
    if not correct:
        return None

    # Per-question shuffle so distractors vary across questions in the same level.
    shuffled = list(pool)
    rng.shuffle(shuffled)

    seen: set[str] = {correct.lower()}
    distractors: list[str] = []
    for w in shuffled:
        if w.id == word.id:
            continue
        t = (getattr(w, translation_col) or "").strip()
        if not t or t.lower() in seen:
            continue
        seen.add(t.lower())
        distractors.append(t)
        if len(distractors) == 3:
            break

    if len(distractors) < 3:
        return None  # not enough variety in this level

    options = [correct, *distractors]
    rng.shuffle(options)
    return GeneratedQuestion(
        level=word.level,
        word_id=word.id,
        lemma=word.lemma,
        ipa=word.transcription_ipa,
        options=options,
    )


async def generate_placement(
    db: AsyncSession,
    *,
    user: User,
    language_code: str = "en",
    seed: int | None = None,
) -> tuple[list[GeneratedQuestion], int, int]:
    """Generate the 30-question placement set. Returns (questions, language_id, attempt_id).

    Persists a `LevelAssessment` row in 'pending' state (passed=False, total_questions=
    PLACEMENT_TOTAL) so we have an attempt id to reference at submit time. The actual
    answers are scored statelessly from the words DB — we don't need to persist the
    question payload because correctness is re-derivable from word.translation.
    """
    rng = random.Random(seed)
    profile = await _get_profile(db, user)
    language_id = await _resolve_language_id(db, language_code)
    tcol = _translation_field(profile.interface_language)

    questions: list[GeneratedQuestion] = []
    for level in LEVEL_ORDER:
        pool = await _candidate_words(
            db,
            language_id=language_id,
            level=level,
            translation_col=tcol,
            limit=_DISTRACTOR_POOL,
        )
        # Use first N as "subject" words, rest of pool as distractor source.
        subjects = pool[:PLACEMENT_QUESTIONS_PER_LEVEL]
        distractor_pool = pool[PLACEMENT_QUESTIONS_PER_LEVEL:] or pool
        for w in subjects:
            q = _build_question(w, distractor_pool, tcol, rng)
            if q is not None:
                questions.append(q)

    rng.shuffle(questions)

    # Persist a pending assessment row so client can reference it on submit.
    attempt = LevelAssessment(
        user_id=user.id,
        language_id=language_id,
        kind=AssessmentKind.placement,
        from_level=profile.cefr_level,
        scores_by_level={},
        total_correct=0,
        total_questions=len(questions),
        passed=False,
    )
    db.add(attempt)
    await db.flush()
    await db.commit()

    return questions, language_id, attempt.id


async def generate_level_up(
    db: AsyncSession,
    *,
    user: User,
    language_code: str = "en",
    seed: int | None = None,
) -> tuple[list[GeneratedQuestion], int, int, CefrLevel]:
    """Generate a 20-question level-up test for the user's current level.

    Returns (questions, language_id, attempt_id, from_level).
    Raises ValueError if the user has no current_level (they must run placement first)
    or already at C2.
    """
    rng = random.Random(seed)
    profile = await _get_profile(db, user)
    if profile.cefr_level is None:
        raise ValueError("User has not completed placement test")
    if _next_level(profile.cefr_level) is None:
        raise ValueError("User is already at the highest level (C2)")

    language_id = await _resolve_language_id(db, language_code)
    tcol = _translation_field(profile.interface_language)
    from_level = profile.cefr_level

    pool = await _candidate_words(
        db,
        language_id=language_id,
        level=from_level,
        translation_col=tcol,
        limit=max(_DISTRACTOR_POOL, LEVEL_UP_TOTAL * 2),
    )
    if len(pool) < LEVEL_UP_TOTAL + 3:
        raise ValueError(f"Not enough vocabulary at level {from_level.value}")

    subjects = pool[:LEVEL_UP_TOTAL]
    distractor_pool = pool[LEVEL_UP_TOTAL:]

    questions: list[GeneratedQuestion] = []
    for w in subjects:
        q = _build_question(w, distractor_pool, tcol, rng)
        if q is not None:
            questions.append(q)

    attempt = LevelAssessment(
        user_id=user.id,
        language_id=language_id,
        kind=AssessmentKind.level_up,
        from_level=from_level,
        to_level=_next_level(from_level),
        scores_by_level={},
        total_correct=0,
        total_questions=len(questions),
        passed=False,
    )
    db.add(attempt)
    await db.flush()
    await db.commit()

    return questions, language_id, attempt.id, from_level


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

async def _is_correct(db: AsyncSession, *, word_id: int, chosen: str, translation_col: str) -> tuple[bool, CefrLevel | None]:
    word = await db.get(Word, word_id)
    if word is None:
        return False, None
    expected = (getattr(word, translation_col) or "").strip().lower()
    if not expected:
        return False, word.level
    return expected == chosen.strip().lower(), word.level


def _estimate_level(scores: dict[str, dict[str, int]]) -> CefrLevel:
    """Highest CEFR where user got >= PLACEMENT_PASS_PER_LEVEL correct AND every
    lower level also passed. Fallback A1.
    """
    estimated = CefrLevel.A1  # default — show A1 content even if they failed everything
    for level in LEVEL_ORDER:
        bucket = scores.get(level.value, {"correct": 0, "total": 0})
        if bucket["total"] == 0:
            break
        if bucket["correct"] < PLACEMENT_PASS_PER_LEVEL:
            break
        estimated = level
    return estimated


async def score_placement(
    db: AsyncSession,
    *,
    attempt_id: int,
    user: User,
    answers: list[Answer],
) -> ScoreResult:
    profile = await _get_profile(db, user)
    tcol = _translation_field(profile.interface_language)

    attempt = await db.get(LevelAssessment, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise ValueError("Assessment attempt not found")
    if attempt.kind != AssessmentKind.placement:
        raise ValueError("Wrong assessment kind for this endpoint")

    scores: dict[str, dict[str, int]] = {l.value: {"correct": 0, "total": 0} for l in LEVEL_ORDER}
    total_correct = 0

    for ans in answers:
        ok, level = await _is_correct(
            db, word_id=ans.word_id, chosen=ans.chosen, translation_col=tcol
        )
        if level is None:
            continue
        bucket = scores[level.value]
        bucket["total"] += 1
        if ok:
            bucket["correct"] += 1
            total_correct += 1

    estimated = _estimate_level(scores)

    attempt.scores_by_level = scores
    attempt.total_correct = total_correct
    attempt.total_questions = sum(b["total"] for b in scores.values())
    attempt.to_level = estimated
    attempt.passed = True  # placement always "passes" — it's an estimation, not a gate

    profile.cefr_level = estimated
    await db.commit()

    return ScoreResult(
        scores_by_level=scores,
        total_correct=total_correct,
        total_questions=attempt.total_questions,
        estimated_level=estimated,
        passed=True,
        new_level=estimated,
    )


async def score_level_up(
    db: AsyncSession,
    *,
    attempt_id: int,
    user: User,
    answers: list[Answer],
) -> ScoreResult:
    profile = await _get_profile(db, user)
    tcol = _translation_field(profile.interface_language)

    attempt = await db.get(LevelAssessment, attempt_id)
    if attempt is None or attempt.user_id != user.id:
        raise ValueError("Assessment attempt not found")
    if attempt.kind != AssessmentKind.level_up:
        raise ValueError("Wrong assessment kind for this endpoint")
    if attempt.from_level is None:
        raise ValueError("Level-up attempt missing from_level")

    from_level = attempt.from_level
    scores: dict[str, dict[str, int]] = {from_level.value: {"correct": 0, "total": 0}}
    total_correct = 0

    for ans in answers:
        ok, level = await _is_correct(
            db, word_id=ans.word_id, chosen=ans.chosen, translation_col=tcol
        )
        if level is None:
            continue
        bucket = scores.setdefault(level.value, {"correct": 0, "total": 0})
        bucket["total"] += 1
        if ok:
            bucket["correct"] += 1
            total_correct += 1

    total = sum(b["total"] for b in scores.values())
    passed = total > 0 and (total_correct / total) >= LEVEL_UP_PASS_RATIO
    new_level = _next_level(from_level) if passed else None

    attempt.scores_by_level = scores
    attempt.total_correct = total_correct
    attempt.total_questions = total
    attempt.passed = passed
    if passed and new_level is not None:
        attempt.to_level = new_level
        profile.cefr_level = new_level

    await db.commit()

    return ScoreResult(
        scores_by_level=scores,
        total_correct=total_correct,
        total_questions=total,
        estimated_level=None,
        passed=passed,
        new_level=new_level,
    )


# ---------------------------------------------------------------------------
# Eligibility
# ---------------------------------------------------------------------------

@dataclass
class LevelStatus:
    cefr_level: CefrLevel | None
    placement_done: bool
    can_level_up: bool
    next_level: CefrLevel | None
    last_level_up_attempt_at: object | None  # datetime or None


async def get_level_status(
    db: AsyncSession,
    *,
    user: User,
    language_code: str = "en",
    cooldown_after_fail_hours: int = 24,
) -> LevelStatus:
    """Compute what assessments the user is currently eligible for."""
    profile = await _get_profile(db, user)
    language_id = await _resolve_language_id(db, language_code)

    # Last level-up attempt (any outcome)
    last_attempt = (
        await db.execute(
            select(LevelAssessment)
            .where(
                LevelAssessment.user_id == user.id,
                LevelAssessment.language_id == language_id,
                LevelAssessment.kind == AssessmentKind.level_up,
                LevelAssessment.from_level == profile.cefr_level,
            )
            .order_by(LevelAssessment.taken_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    nxt = _next_level(profile.cefr_level) if profile.cefr_level else None
    can_level_up = (
        profile.cefr_level is not None
        and nxt is not None
    )

    # Gate: user must have completed ≥ 50 % of topics at their current level.
    if can_level_up and profile.cefr_level is not None:
        topics = (
            await db.execute(
                select(Topic).where(
                    Topic.language_id == language_id,
                    Topic.level == profile.cefr_level,
                )
            )
        ).scalars().all()

        if topics:
            topic_ids = [t.id for t in topics]

            # Word counts per topic (level-matched, same logic as languages.py)
            wc_rows = (
                await db.execute(
                    select(Word.topic_id, func.count(Word.id).label("cnt"))
                    .join(Topic, Topic.id == Word.topic_id)
                    .where(
                        Word.language_id == language_id,
                        Word.level == Topic.level,
                        Word.topic_id.in_(topic_ids),
                    )
                    .group_by(Word.topic_id)
                )
            ).all()
            word_counts: dict[int, int] = {r.topic_id: r.cnt for r in wc_rows}

            # Completed vocab-lesson count per topic
            cl_rows = (
                await db.execute(
                    select(
                        VocabLessonProgress.topic_id,
                        func.count(VocabLessonProgress.id).label("cnt"),
                    )
                    .where(
                        VocabLessonProgress.user_id == user.id,
                        VocabLessonProgress.topic_id.in_(topic_ids),
                        VocabLessonProgress.completed_at.is_not(None),
                    )
                    .group_by(VocabLessonProgress.topic_id)
                )
            ).all()
            completed_counts: dict[int, int] = {r.topic_id: r.cnt for r in cl_rows}

            # A topic is "done" when all its vocab lessons are completed.
            # lessons_count = ceil(word_count / _VOCAB_LESSON_SIZE), min 1.
            def _lessons_needed(wc: int) -> int:
                return max(1, -(-wc // _VOCAB_LESSON_SIZE))

            completed_topics = sum(
                1
                for t in topics
                if word_counts.get(t.id, 0) > 0
                and completed_counts.get(t.id, 0) >= _lessons_needed(word_counts[t.id])
            )
            if completed_topics / len(topics) < 0.5:
                can_level_up = False

    if can_level_up and last_attempt is not None and not last_attempt.passed:
        # cooldown after a failed attempt
        from datetime import datetime, timedelta, timezone

        deadline = last_attempt.taken_at + timedelta(hours=cooldown_after_fail_hours)
        if datetime.now(timezone.utc) < deadline:
            can_level_up = False

    return LevelStatus(
        cefr_level=profile.cefr_level,
        placement_done=profile.cefr_level is not None,
        can_level_up=can_level_up,
        next_level=nxt,
        last_level_up_attempt_at=last_attempt.taken_at if last_attempt else None,
    )
