from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TranslateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5000)
    source_lang: str = Field(min_length=2, max_length=8, examples=["en"])
    target_lang: str = Field(min_length=2, max_length=8, examples=["ru"])
    mode: Literal["text", "voice", "camera"] = "text"
    save_history: bool = True


class TranslateResponse(BaseModel):
    source_lang: str
    target_lang: str
    source_text: str
    translated_text: str
    history_id: int | None = None


class HistoryItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    source_lang: str
    target_lang: str
    source_text: str
    translated_text: str
    mode: str
    is_favorite: bool
    created_at: datetime
