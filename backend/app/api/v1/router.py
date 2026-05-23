from fastapi import APIRouter

from app.api.v1.endpoints import (
    achievements,
    assessments,
    games,
    words,
    auth,
    languages,
    lessons,
    speaking,
    translator,
    users,
    vocab_lessons,
)

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(languages.router, prefix="/languages", tags=["languages"])
api_router.include_router(lessons.router, prefix="/lessons", tags=["lessons"])
api_router.include_router(translator.router, prefix="/translator", tags=["translator"])
api_router.include_router(achievements.router, prefix="/achievements", tags=["achievements"])
api_router.include_router(words.router, prefix="/words", tags=["words"])
api_router.include_router(speaking.router, prefix="/speaking", tags=["speaking"])
api_router.include_router(assessments.router, prefix="/assessments", tags=["assessments"])
api_router.include_router(games.router, prefix="/games", tags=["games"])
api_router.include_router(vocab_lessons.router, prefix="/vocab-lessons", tags=["vocab-lessons"])
