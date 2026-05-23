"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-02
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Enums -------------------------------------------------------------
    auth_provider = postgresql.ENUM("email", "google", name="auth_provider", create_type=False)
    cefr_level = postgresql.ENUM("A1", "A2", "B1", "B2", "C1", "C2", name="cefr_level", create_type=False)
    lesson_type = postgresql.ENUM(
        "introduction", "grammar", "vocabulary", "mixed", name="lesson_type", create_type=False
    )
    question_type = postgresql.ENUM(
        "multiple_choice", "fill_blanks", "text_input", name="question_type", create_type=False
    )
    translation_mode = postgresql.ENUM(
        "text", "voice", "camera", name="translation_mode", create_type=False
    )
    auth_provider.create(op.get_bind(), checkfirst=True)
    cefr_level.create(op.get_bind(), checkfirst=True)
    lesson_type.create(op.get_bind(), checkfirst=True)
    question_type.create(op.get_bind(), checkfirst=True)
    translation_mode.create(op.get_bind(), checkfirst=True)

    # --- Core tables -------------------------------------------------------
    op.create_table(
        "languages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(8), nullable=False, unique=True),
        sa.Column("name", sa.String(80), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("flag_url", sa.String(500), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.create_index("ix_languages_code", "languages", ["code"])

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("full_name", sa.String(120), nullable=False),
        sa.Column("age", sa.Integer(), nullable=True),
        sa.Column("avatar_url", sa.String(500), nullable=True),
        sa.Column("provider", auth_provider, nullable=False, server_default="email"),
        sa.Column("provider_id", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "profiles",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("current_language_id", sa.Integer(), sa.ForeignKey("languages.id", ondelete="SET NULL"), nullable=True),
        sa.Column("experience_points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("level", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("streak_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("daily_goal_xp", sa.Integer(), nullable=False, server_default="50"),
        sa.Column("interface_language", sa.String(8), nullable=False, server_default="en"),
        sa.Column("dark_mode", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("text_size", sa.String(16), nullable=False, server_default="medium"),
        sa.Column("notifications_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("last_active_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(255), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"])

    # --- Content -----------------------------------------------------------
    op.create_table(
        "topics",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("language_id", sa.Integer(), sa.ForeignKey("languages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("slug", sa.String(80), nullable=False),
        sa.Column("title", sa.String(120), nullable=False),
        sa.Column("title_ru", sa.String(120), nullable=True),
        sa.Column("title_kk", sa.String(120), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("icon_url", sa.String(500), nullable=True),
        sa.Column("level", cefr_level, nullable=False, server_default="A1"),
        sa.Column("order", sa.Integer(), nullable=False, server_default="0"),
        sa.UniqueConstraint("language_id", "slug", name="uq_topic_lang_slug"),
    )
    op.create_index("ix_topics_language_id", "topics", ["language_id"])

    op.create_table(
        "words",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("language_id", sa.Integer(), sa.ForeignKey("languages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("topic_id", sa.Integer(), sa.ForeignKey("topics.id", ondelete="SET NULL"), nullable=True),
        sa.Column("lemma", sa.String(120), nullable=False),
        sa.Column("part_of_speech", sa.String(20), nullable=True),
        sa.Column("transcription_ipa", sa.String(120), nullable=True),
        sa.Column("translation_ru", sa.String(200), nullable=True),
        sa.Column("translation_kk", sa.String(200), nullable=True),
        sa.Column("example_sentence", sa.Text(), nullable=True),
        sa.Column("example_translation_ru", sa.Text(), nullable=True),
        sa.Column("example_translation_kk", sa.Text(), nullable=True),
        sa.Column("audio_url", sa.String(500), nullable=True),
        sa.Column("image_url", sa.String(500), nullable=True),
        sa.Column("difficulty", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("frequency_rank", sa.Integer(), nullable=True),
        sa.UniqueConstraint("language_id", "lemma", name="uq_word_lang_lemma"),
    )
    op.create_index("ix_words_language_id", "words", ["language_id"])
    op.create_index("ix_words_topic_id", "words", ["topic_id"])
    op.create_index("ix_words_lemma", "words", ["lemma"])

    op.create_table(
        "lessons",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("language_id", sa.Integer(), sa.ForeignKey("languages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("topic_id", sa.Integer(), sa.ForeignKey("topics.id", ondelete="SET NULL"), nullable=True),
        sa.Column("type", lesson_type, nullable=False, server_default="vocabulary"),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("xp_reward", sa.Integer(), nullable=False, server_default="10"),
        sa.Column("estimated_minutes", sa.Integer(), nullable=False, server_default="5"),
    )
    op.create_index("ix_lessons_language_id", "lessons", ["language_id"])
    op.create_index("ix_lessons_topic_id", "lessons", ["topic_id"])

    op.create_table(
        "questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("lesson_id", sa.Integer(), sa.ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", question_type, nullable=False),
        sa.Column("order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("content", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("correct_answer", sa.Text(), nullable=True),
    )
    op.create_index("ix_questions_lesson_id", "questions", ["lesson_id"])

    # --- Progress ----------------------------------------------------------
    op.create_table(
        "user_progress",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lesson_id", sa.Integer(), sa.ForeignKey("lessons.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("mistakes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("time_spent_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "lesson_id", name="uq_user_lesson"),
    )
    op.create_index("ix_user_progress_user_id", "user_progress", ["user_id"])
    op.create_index("ix_user_progress_lesson_id", "user_progress", ["lesson_id"])

    op.create_table(
        "question_attempts",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("questions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.Column("answer_given", sa.Text(), nullable=True),
        sa.Column("attempted_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_question_attempts_user_id", "question_attempts", ["user_id"])
    op.create_index("ix_question_attempts_question_id", "question_attempts", ["question_id"])

    op.create_table(
        "user_word_progress",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("word_id", sa.Integer(), sa.ForeignKey("words.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="new"),
        sa.Column("ease_factor", sa.Float(), nullable=False, server_default="2.5"),
        sa.Column("interval_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("repetitions", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("next_review_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("user_id", "word_id", name="uq_user_word"),
    )
    op.create_index("ix_uwp_user_id", "user_word_progress", ["user_id"])
    op.create_index("ix_uwp_word_id", "user_word_progress", ["word_id"])
    op.create_index("ix_uwp_next_review", "user_word_progress", ["next_review_at"])

    # --- Achievements ------------------------------------------------------
    op.create_table(
        "achievements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(60), nullable=False, unique=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("icon_url", sa.String(500), nullable=True),
        sa.Column("requirement_value", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("stars", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_index("ix_achievements_code", "achievements", ["code"])

    op.create_table(
        "user_achievements",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("achievement_id", sa.Integer(), sa.ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False),
        sa.Column("progress", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "achievement_id", name="uq_user_achievement"),
    )
    op.create_index("ix_user_achievements_user_id", "user_achievements", ["user_id"])
    op.create_index("ix_user_achievements_achievement_id", "user_achievements", ["achievement_id"])

    # --- Translations ------------------------------------------------------
    op.create_table(
        "translations_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("source_lang", sa.String(8), nullable=False),
        sa.Column("target_lang", sa.String(8), nullable=False),
        sa.Column("source_text", sa.Text(), nullable=False),
        sa.Column("translated_text", sa.Text(), nullable=False),
        sa.Column("mode", translation_mode, nullable=False, server_default="text"),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_translations_user_id", "translations_history", ["user_id"])
    op.create_index("ix_translations_user_created", "translations_history", ["user_id", "created_at"])


def downgrade() -> None:
    op.drop_table("translations_history")
    op.drop_table("user_achievements")
    op.drop_table("achievements")
    op.drop_table("user_word_progress")
    op.drop_table("question_attempts")
    op.drop_table("user_progress")
    op.drop_table("questions")
    op.drop_table("lessons")
    op.drop_table("words")
    op.drop_table("topics")
    op.drop_table("refresh_tokens")
    op.drop_table("profiles")
    op.drop_table("users")
    op.drop_table("languages")
    for name in ("translation_mode", "question_type", "lesson_type", "cefr_level", "auth_provider"):
        op.execute(f"DROP TYPE IF EXISTS {name}")
