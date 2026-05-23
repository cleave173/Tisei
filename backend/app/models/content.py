from __future__ import annotations

from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class CefrLevel(str, PyEnum):
    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"
    C2 = "C2"


class LessonType(str, PyEnum):
    introduction = "introduction"
    grammar = "grammar"
    vocabulary = "vocabulary"
    mixed = "mixed"


class QuestionType(str, PyEnum):
    multiple_choice = "multiple_choice"
    fill_blanks = "fill_blanks"
    text_input = "text_input"


class Topic(Base):
    __tablename__ = "topics"
    __table_args__ = (UniqueConstraint("language_id", "slug", name="uq_topic_lang_slug"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    language_id: Mapped[int] = mapped_column(
        ForeignKey("languages.id", ondelete="CASCADE"), index=True, nullable=False
    )
    slug: Mapped[str] = mapped_column(String(80), nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    title_ru: Mapped[str | None] = mapped_column(String(120), nullable=True)
    title_kk: Mapped[str | None] = mapped_column(String(120), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    level: Mapped[CefrLevel] = mapped_column(
        Enum(CefrLevel, name="cefr_level"), default=CefrLevel.A1, nullable=False
    )
    order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    language: Mapped["Language"] = relationship(back_populates="topics")  # noqa: F821
    words: Mapped[list["Word"]] = relationship(back_populates="topic", cascade="all, delete-orphan")
    lessons: Mapped[list["Lesson"]] = relationship(back_populates="topic")


class Word(Base):
    __tablename__ = "words"
    __table_args__ = (
        UniqueConstraint("language_id", "lemma", name="uq_word_lang_lemma"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    language_id: Mapped[int] = mapped_column(
        ForeignKey("languages.id", ondelete="CASCADE"), index=True, nullable=False
    )
    topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"), index=True, nullable=True
    )
    lemma: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    part_of_speech: Mapped[str | None] = mapped_column(String(20), nullable=True)
    transcription_ipa: Mapped[str | None] = mapped_column(String(120), nullable=True)
    translation_ru: Mapped[str | None] = mapped_column(String(200), nullable=True)
    translation_kk: Mapped[str | None] = mapped_column(String(200), nullable=True)
    example_sentence: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_translation_ru: Mapped[str | None] = mapped_column(Text, nullable=True)
    example_translation_kk: Mapped[str | None] = mapped_column(Text, nullable=True)
    audio_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    difficulty: Mapped[int] = mapped_column(Integer, default=1, nullable=False)  # 1..5
    frequency_rank: Mapped[int | None] = mapped_column(Integer, nullable=True)
    level: Mapped[CefrLevel] = mapped_column(
        Enum(CefrLevel, name="cefr_level"), default=CefrLevel.A1, nullable=False, index=True
    )
    # CEFR sub-level: 1 or 2 (e.g. B2 + sublevel=1 → "B2.1", sublevel=2 → "B2.2").
    sublevel: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    language: Mapped["Language"] = relationship(back_populates="words")  # noqa: F821
    topic: Mapped[Topic | None] = relationship(back_populates="words")


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[int] = mapped_column(primary_key=True)
    language_id: Mapped[int] = mapped_column(
        ForeignKey("languages.id", ondelete="CASCADE"), index=True, nullable=False
    )
    topic_id: Mapped[int | None] = mapped_column(
        ForeignKey("topics.id", ondelete="SET NULL"), index=True, nullable=True
    )
    type: Mapped[LessonType] = mapped_column(
        Enum(LessonType, name="lesson_type"), default=LessonType.vocabulary, nullable=False
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    xp_reward: Mapped[int] = mapped_column(Integer, default=10, nullable=False)
    estimated_minutes: Mapped[int] = mapped_column(Integer, default=5, nullable=False)

    language: Mapped["Language"] = relationship(back_populates="lessons")  # noqa: F821
    topic: Mapped[Topic | None] = relationship(back_populates="lessons")
    questions: Mapped[list["Question"]] = relationship(
        back_populates="lesson", cascade="all, delete-orphan", order_by="Question.order"
    )


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(primary_key=True)
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"), index=True, nullable=False
    )
    type: Mapped[QuestionType] = mapped_column(
        Enum(QuestionType, name="question_type"), nullable=False
    )
    order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    # Structured payload. Shape depends on `type`:
    #   multiple_choice: {prompt, image_url?, options:[str], correct_index:int}
    #   text_input:      {prompt, audio_url?, accepted_answers:[str]}
    #   fill_blanks:     {template:"I __ __ ?", tokens:[str], correct_order:[int]}
    content: Mapped[dict] = mapped_column(JSONB, nullable=False)
    correct_answer: Mapped[str | None] = mapped_column(Text, nullable=True)

    lesson: Mapped[Lesson] = relationship(back_populates="questions")


class UserProgress(Base):
    __tablename__ = "user_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "lesson_id", name="uq_user_lesson"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    lesson_id: Mapped[int] = mapped_column(
        ForeignKey("lessons.id", ondelete="CASCADE"), index=True, nullable=False
    )
    is_completed: Mapped[bool] = mapped_column(default=False, nullable=False)
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    mistakes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    time_spent_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class QuestionAttempt(Base):
    __tablename__ = "question_attempts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), index=True, nullable=False
    )
    is_correct: Mapped[bool] = mapped_column(nullable=False)
    answer_given: Mapped[str | None] = mapped_column(Text, nullable=True)
    attempted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class UserWordProgress(Base):
    """SM-2 spaced repetition state per user/word."""

    __tablename__ = "user_word_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "word_id", name="uq_user_word"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    word_id: Mapped[int] = mapped_column(
        ForeignKey("words.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[str] = mapped_column(String(16), default="new", nullable=False)
    ease_factor: Mapped[float] = mapped_column(default=2.5, nullable=False)
    interval_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    repetitions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_review_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), index=True, nullable=True
    )


class VocabLessonProgress(Base):
    """Per-user progress for a synthetic "vocab lesson" — a chunk of words
    inside a topic. There is no curated Lesson row for these; the lesson
    identity is (topic_id, lesson_index).

    Each lesson has 4 stages the user must clear:
      1. cards     — review all flashcards once
      2. listening — type each word heard via TTS
      3. mc        — pick the correct translation from 4 options
      4. speaking  — pronounce each word (scored via /speaking/evaluate)

    A lesson is considered completed when all four stage flags are true.
    """

    __tablename__ = "vocab_lesson_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "topic_id", "lesson_index", name="uq_vlp_user_topic_idx"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    topic_id: Mapped[int] = mapped_column(
        ForeignKey("topics.id", ondelete="CASCADE"), index=True, nullable=False
    )
    lesson_index: Mapped[int] = mapped_column(Integer, nullable=False)

    cards_done: Mapped[bool] = mapped_column(default=False, nullable=False)
    listening_done: Mapped[bool] = mapped_column(default=False, nullable=False)
    mc_done: Mapped[bool] = mapped_column(default=False, nullable=False)
    speaking_done: Mapped[bool] = mapped_column(default=False, nullable=False)

    xp_earned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
