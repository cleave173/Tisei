import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models import TranslationHistory, TranslationMode, User
from app.schemas.translator import HistoryItemOut, TranslateRequest, TranslateResponse

router = APIRouter()


@router.post("/text", response_model=TranslateResponse)
async def translate_text(
    payload: TranslateRequest,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TranslateResponse:
    """Proxy text translation to LibreTranslate, save to history."""
    url = f"{settings.libretranslate_url}/translate"
    body = {
        "q": payload.text,
        "source": payload.source_lang,
        "target": payload.target_lang,
        "format": "text",
    }
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            r = await client.post(url, json=body)
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Translator error: {exc}") from exc

    translated = data.get("translatedText", "")
    history_id: int | None = None
    if payload.save_history and translated:
        item = TranslationHistory(
            user_id=current.id,
            source_lang=payload.source_lang,
            target_lang=payload.target_lang,
            source_text=payload.text,
            translated_text=translated,
            mode=TranslationMode(payload.mode),
        )
        db.add(item)
        await db.flush()
        history_id = item.id
        await db.commit()

    return TranslateResponse(
        source_lang=payload.source_lang,
        target_lang=payload.target_lang,
        source_text=payload.text,
        translated_text=translated,
        history_id=history_id,
    )


@router.get("/history", response_model=list[HistoryItemOut])
async def list_history(
    favorites_only: bool = Query(False),
    limit: int = Query(50, le=200),
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[TranslationHistory]:
    stmt = select(TranslationHistory).where(TranslationHistory.user_id == current.id)
    if favorites_only:
        stmt = stmt.where(TranslationHistory.is_favorite.is_(True))
    stmt = stmt.order_by(desc(TranslationHistory.created_at)).limit(limit)
    return list((await db.execute(stmt)).scalars().all())


@router.post("/history/{item_id}/favorite", response_model=HistoryItemOut)
async def toggle_favorite(
    item_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TranslationHistory:
    item = await db.get(TranslationHistory, item_id)
    if item is None or item.user_id != current.id:
        raise HTTPException(404, "Not found")
    item.is_favorite = not item.is_favorite
    await db.commit()
    return item


@router.delete("/history", status_code=204)
async def clear_history(
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    await db.execute(
        TranslationHistory.__table__.delete().where(
            TranslationHistory.user_id == current.id,
            TranslationHistory.is_favorite.is_(False),
        )
    )
    await db.commit()


@router.delete("/history/{item_id}", status_code=204)
async def delete_history_item(
    item_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    item = await db.get(TranslationHistory, item_id)
    if item is None or item.user_id != current.id:
        raise HTTPException(404, "Not found")
    await db.delete(item)
    await db.commit()


# Placeholder endpoints — STT/OCR are handled on-device in this app, but the
# endpoints are kept here for future server-side fallback (faster-whisper /
# Tesseract).


@router.post("/ocr", deprecated=True)
async def ocr_translate() -> dict:
    return {"status": "not_implemented_use_on_device"}


@router.post("/stt", deprecated=True)
async def stt_translate() -> dict:
    return {"status": "not_implemented_use_on_device"}
