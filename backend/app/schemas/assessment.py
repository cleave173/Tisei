"""Pydantic schemas for placement / level-up assessments."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class AssessmentQuestion(BaseModel):
    level: str
    word_id: int
    lemma: str
    ipa: str | None = None
    options: list[str]


class AssessmentStartOut(BaseModel):
    attempt_id: int
    kind: Literal["placement", "level_up"]
    from_level: str | None = None
    questions: list[AssessmentQuestion]


class AssessmentAnswerIn(BaseModel):
    word_id: int
    chosen: str = Field(..., description="The translation string the user picked")


class AssessmentSubmitIn(BaseModel):
    attempt_id: int
    answers: list[AssessmentAnswerIn]
    translation_lang: str | None = None


class LevelScore(BaseModel):
    correct: int
    total: int


class AssessmentResultOut(BaseModel):
    attempt_id: int
    kind: Literal["placement", "level_up"]
    scores_by_level: dict[str, LevelScore]
    total_correct: int
    total_questions: int
    passed: bool
    estimated_level: str | None = None  # placement
    new_level: str | None = None  # level-up: only set when passed


class LevelStatusOut(BaseModel):
    cefr_level: str | None = None
    placement_done: bool
    can_level_up: bool
    next_level: str | None = None
    last_level_up_attempt_at: datetime | None = None
