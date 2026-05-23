"""CEFR placement & level-up assessment endpoints."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import User
from app.schemas.assessment import (
    AssessmentQuestion,
    AssessmentResultOut,
    AssessmentStartOut,
    AssessmentSubmitIn,
    LevelScore,
    LevelStatusOut,
)
from app.services import assessment_service

router = APIRouter()


def _serialize_questions(qs: list[assessment_service.GeneratedQuestion]) -> list[AssessmentQuestion]:
    return [
        AssessmentQuestion(
            level=q.level.value,
            word_id=q.word_id,
            lemma=q.lemma,
            ipa=q.ipa,
            options=q.options,
        )
        for q in qs
    ]


def _serialize_result(
    attempt_id: int,
    kind: str,
    res: assessment_service.ScoreResult,
) -> AssessmentResultOut:
    return AssessmentResultOut(
        attempt_id=attempt_id,
        kind=kind,
        scores_by_level={k: LevelScore(**v) for k, v in res.scores_by_level.items()},
        total_correct=res.total_correct,
        total_questions=res.total_questions,
        passed=res.passed,
        estimated_level=res.estimated_level.value if res.estimated_level else None,
        new_level=res.new_level.value if res.new_level else None,
    )


# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

@router.get("/me/status", response_model=LevelStatusOut)
async def my_level_status(
    language: str = Query(default="en"),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LevelStatusOut:
    s = await assessment_service.get_level_status(
        db, user=current, language_code=language
    )
    return LevelStatusOut(
        cefr_level=s.cefr_level.value if s.cefr_level else None,
        placement_done=s.placement_done,
        can_level_up=s.can_level_up,
        next_level=s.next_level.value if s.next_level else None,
        last_level_up_attempt_at=s.last_level_up_attempt_at,
    )


# ---------------------------------------------------------------------------
# Placement test
# ---------------------------------------------------------------------------

@router.post("/placement/start", response_model=AssessmentStartOut)
async def start_placement(
    language: str = Query(default="en"),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AssessmentStartOut:
    try:
        questions, _, attempt_id = await assessment_service.generate_placement(
            db, user=current, language_code=language
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    return AssessmentStartOut(
        attempt_id=attempt_id,
        kind="placement",
        from_level=None,
        questions=_serialize_questions(questions),
    )


@router.post("/placement/submit", response_model=AssessmentResultOut)
async def submit_placement(
    payload: AssessmentSubmitIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AssessmentResultOut:
    try:
        res = await assessment_service.score_placement(
            db,
            attempt_id=payload.attempt_id,
            user=current,
            answers=[
                assessment_service.Answer(word_id=a.word_id, chosen=a.chosen)
                for a in payload.answers
            ],
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    return _serialize_result(payload.attempt_id, "placement", res)


# ---------------------------------------------------------------------------
# Level-up test
# ---------------------------------------------------------------------------

@router.post("/level-up/start", response_model=AssessmentStartOut)
async def start_level_up(
    language: str = Query(default="en"),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AssessmentStartOut:
    try:
        questions, _, attempt_id, from_level = await assessment_service.generate_level_up(
            db, user=current, language_code=language
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    return AssessmentStartOut(
        attempt_id=attempt_id,
        kind="level_up",
        from_level=from_level.value,
        questions=_serialize_questions(questions),
    )


@router.post("/level-up/submit", response_model=AssessmentResultOut)
async def submit_level_up(
    payload: AssessmentSubmitIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AssessmentResultOut:
    try:
        res = await assessment_service.score_level_up(
            db,
            attempt_id=payload.attempt_id,
            user=current,
            answers=[
                assessment_service.Answer(word_id=a.word_id, chosen=a.chosen)
                for a in payload.answers
            ],
        )
    except ValueError as e:
        raise HTTPException(400, str(e)) from e
    return _serialize_result(payload.attempt_id, "level_up", res)
