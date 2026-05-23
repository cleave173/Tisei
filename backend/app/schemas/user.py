from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr


class ProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    current_language_id: int | None = None
    experience_points: int
    level: int
    streak_days: int
    daily_goal_xp: int
    interface_language: str
    dark_mode: bool
    text_size: str
    notifications_enabled: bool
    cefr_level: str | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    full_name: str
    age: int | None = None
    avatar_url: str | None = None
    is_verified: bool
    created_at: datetime
    profile: ProfileOut | None = None
