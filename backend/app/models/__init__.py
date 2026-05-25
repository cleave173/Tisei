"""SQLAlchemy models for Tisei.

All models are imported here so Alembic `--autogenerate` can discover them
via `Base.metadata`.
"""

from app.models.achievement import Achievement, UserAchievement
from app.models.assessment import AssessmentKind, LevelAssessment
from app.models.content import (
    CefrLevel,
    Lesson,
    LessonType,
    Question,
    QuestionAttempt,
    QuestionType,
    Topic,
    UserProgress,
    UserWordProgress,
    VocabLessonProgress,
    Word,
)
from app.models.language import Language
from app.models.password_reset import PasswordResetCode
from app.models.translation import TranslationHistory, TranslationMode
from app.models.user import AuthProvider, Profile, RefreshToken, User

__all__ = [
    "Achievement",
    "AssessmentKind",
    "AuthProvider",
    "CefrLevel",
    "LevelAssessment",
    "Language",
    "Lesson",
    "PasswordResetCode",
    "LessonType",
    "Profile",
    "Question",
    "QuestionAttempt",
    "QuestionType",
    "RefreshToken",
    "Topic",
    "TranslationHistory",
    "TranslationMode",
    "User",
    "UserAchievement",
    "UserProgress",
    "UserWordProgress",
    "VocabLessonProgress",
    "Word",
]
