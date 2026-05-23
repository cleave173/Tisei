"""CEFR proficiency assessments: placement (first-time) and level-up (exit) tests."""
from __future__ import annotations

from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.content import CefrLevel


class AssessmentKind(str, PyEnum):
    placement = "placement"
    level_up = "level_up"


class LevelAssessment(Base):
    """Result of a proficiency assessment attempt.

    One row per completed attempt. Stores per-level score breakdown so we can
    analyse strengths/weaknesses later.
    """

    __tablename__ = "level_assessments"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    language_id: Mapped[int] = mapped_column(
        ForeignKey("languages.id", ondelete="CASCADE"), index=True, nullable=False
    )
    kind: Mapped[AssessmentKind] = mapped_column(
        Enum(AssessmentKind, name="assessment_kind"), nullable=False
    )

    from_level: Mapped[CefrLevel | None] = mapped_column(
        Enum(CefrLevel, name="cefr_level"), nullable=True
    )
    to_level: Mapped[CefrLevel | None] = mapped_column(
        Enum(CefrLevel, name="cefr_level"), nullable=True
    )

    # {"A1": {"correct": 5, "total": 5}, "A2": {"correct": 4, "total": 5}, ...}
    scores_by_level: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    total_correct: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_questions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    passed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    taken_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
