"""AI-powered language game endpoints.

Each game has a single POST /generate endpoint. When `topic` is empty, content
comes from the existing vocabulary database; otherwise the LLM generates it.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models import User
from app.schemas.games import (
    GameGenerateIn,
    HangmanOut,
    SentenceBuilderOut,
    WordMatchOut,
    WordScrambleOut,
)
from app.services import games_service
from app.services.gemini_client import GeminiError

router = APIRouter()


def _to_http(exc: Exception) -> HTTPException:
    if isinstance(exc, GeminiError):
        if "HTTP 429" in str(exc):
            return HTTPException(
                status_code=429,
                detail="Лимит Gemini исчерпан. Попробуйте позже или проверьте квоту API key.",
            )
        return HTTPException(status_code=502, detail=f"AI generator unavailable: {exc}")
    if isinstance(exc, ValueError):
        return HTTPException(status_code=400, detail=str(exc))
    return HTTPException(status_code=500, detail="Unexpected error")


@router.post("/word-match/generate", response_model=WordMatchOut)
async def word_match_generate(
    payload: GameGenerateIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordMatchOut:
    try:
        data = await games_service.gen_word_match(
            db,
            user=current,
            topic=payload.topic,
            language_code=payload.language,
            count=payload.count,
            level_override=payload.level,
            translation_lang=payload.translation_lang,
        )
    except Exception as exc:
        raise _to_http(exc) from exc
    return WordMatchOut(**data)


@router.post("/word-scramble/generate", response_model=WordScrambleOut)
async def word_scramble_generate(
    payload: GameGenerateIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WordScrambleOut:
    try:
        data = await games_service.gen_word_scramble(
            db,
            user=current,
            topic=payload.topic,
            language_code=payload.language,
            count=payload.count,
            level_override=payload.level,
            translation_lang=payload.translation_lang,
        )
    except Exception as exc:
        raise _to_http(exc) from exc
    return WordScrambleOut(**data)


@router.post("/sentence-builder/generate", response_model=SentenceBuilderOut)
async def sentence_builder_generate(
    payload: GameGenerateIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SentenceBuilderOut:
    try:
        data = await games_service.gen_sentence_builder(
            db,
            user=current,
            topic=payload.topic,
            language_code=payload.language,
            count=payload.count,
            level_override=payload.level,
            translation_lang=payload.translation_lang,
        )
    except Exception as exc:
        raise _to_http(exc) from exc
    return SentenceBuilderOut(**data)


@router.post("/hangman/generate", response_model=HangmanOut)
async def hangman_generate(
    payload: GameGenerateIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> HangmanOut:
    try:
        data = await games_service.gen_hangman(
            db,
            user=current,
            topic=payload.topic,
            language_code=payload.language,
            level_override=payload.level,
            translation_lang=payload.translation_lang,
        )
    except Exception as exc:
        raise _to_http(exc) from exc
    return HangmanOut(**data)
