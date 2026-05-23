from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict


class LanguageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    description: str | None = None
    image_url: str | None = None
    flag_url: str | None = None


class TopicOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    title: str
    title_ru: str | None = None
    title_kk: str | None = None
    level: str
    order: int
    icon_url: str | None = None
    word_count: int = 0
    lessons_count: int = 0
    completed_lessons: int = 0


class WordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    lemma: str
    part_of_speech: str | None = None
    transcription_ipa: str | None = None
    translation_ru: str | None = None
    translation_kk: str | None = None
    example_sentence: str | None = None
    example_translation_ru: str | None = None
    example_translation_kk: str | None = None
    audio_url: str | None = None
    image_url: str | None = None
    level: str = "A1"
    sublevel: int = 1
    frequency_rank: int | None = None


class QuestionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    order: int
    content: dict[str, Any]


class LessonSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None = None
    type: str
    order: int
    xp_reward: int
    estimated_minutes: int
    is_completed: bool = False
    score: int = 0
    progress: float = 0.0


class LessonDetailOut(LessonSummaryOut):
    questions: list[QuestionOut] = []


class AnswerIn(BaseModel):
    question_id: int
    answer: str | int | list[int]


class SubmitLessonIn(BaseModel):
    answers: list[AnswerIn]
    time_spent_seconds: int = 0


class SubmitLessonOut(BaseModel):
    score: int
    total: int
    correct: int
    mistakes: int
    xp_earned: int
    is_completed: bool
    per_question: list[dict[str, Any]]


# ---------------------------------------------------------------------------
# Vocab lessons (synthetic flashcard lessons built from a topic's words)
# ---------------------------------------------------------------------------


class VocabLessonProgressOut(BaseModel):
    """Per-stage completion flags + overall status."""

    model_config = ConfigDict(from_attributes=True)

    cards_done: bool = False
    listening_done: bool = False
    mc_done: bool = False
    speaking_done: bool = False
    is_completed: bool = False
    xp_earned: int = 0


class VocabLessonOut(BaseModel):
    """A single vocab lesson — a chunk of words inside a topic."""

    index: int
    title: str
    words: list[WordOut]
    progress: VocabLessonProgressOut


class VocabLessonsListOut(BaseModel):
    topic_id: int
    topic_title: str
    topic_level: str
    lesson_size: int
    lessons: list[VocabLessonOut]


class VocabStageIn(BaseModel):
    """Body for marking a stage of a vocab lesson as completed."""

    stage: str  # "cards" | "listening" | "mc" | "speaking"


class VocabStageOut(BaseModel):
    progress: VocabLessonProgressOut
    xp_earned_now: int = 0  # XP awarded by this particular stage call
