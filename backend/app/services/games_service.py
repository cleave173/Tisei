"""Service layer for AI-powered language games.

Two modes per game:
  * default — pulls words/sentences from the existing DB at the user's CEFR level
  * custom  — calls Gemini with a topic-specific prompt and validates JSON output
"""
from __future__ import annotations

import logging
import random
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User
from app.models.content import CefrLevel, Word
from app.models.language import Language
from app.models.user import Profile
from app.services.gemini_client import GeminiError, generate_json

logger = logging.getLogger(__name__)

_TRANSLATION_COL = {"ru": "translation_ru", "kk": "translation_kk"}
_EXAMPLE_COL = {"ru": "example_translation_ru", "kk": "example_translation_kk"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _get_profile(db: AsyncSession, user: User) -> Profile | None:
    return (
        await db.execute(select(Profile).where(Profile.user_id == user.id))
    ).scalar_one_or_none()


async def _resolve_language_id(db: AsyncSession, code: str) -> int:
    row = (await db.execute(select(Language).where(Language.code == code))).scalar_one_or_none()
    if row is None:
        raise ValueError(f"Unknown language code: {code}")
    return row.id


def _resolve_level(profile: Profile | None, override: str | None) -> CefrLevel | None:
    """Returns the CEFR level to filter by, or None for "any level"."""
    if override:
        if override.upper() == "ANY":
            return None
        try:
            return CefrLevel(override.upper())
        except ValueError as exc:
            raise ValueError(f"Invalid CEFR level: {override}") from exc
    if profile is not None and profile.cefr_level is not None:
        return profile.cefr_level
    return CefrLevel.A1


def _level_label(level: CefrLevel | None) -> str:
    return level.value if level is not None else "ANY"


def _ui_lang(profile: Profile | None) -> str:
    if profile is not None and profile.interface_language:
        c = profile.interface_language.lower()
        if c in ("ru", "kk"):
            return c
    return "ru"  # default fallback for translations when user has no preference


async def _fetch_words(
    db: AsyncSession,
    *,
    language_id: int,
    level: CefrLevel | None,
    ui_lang: str,
    count: int,
) -> list[Word]:
    """Pick `count` words. If `level` is None, no level filter is applied."""
    tcol = _TRANSLATION_COL.get(ui_lang, "translation_ru")
    conds = [
        Word.language_id == language_id,
        getattr(Word, tcol).is_not(None),
    ]
    if level is not None:
        conds.append(Word.level == level)
    stmt = select(Word).where(*conds).limit(500)
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return []
    pool = list(rows)
    random.shuffle(pool)
    return pool[:count]


def _translation_of(word: Word, ui_lang: str) -> str | None:
    return getattr(word, _TRANSLATION_COL.get(ui_lang, "translation_ru"))


def _example_translation_of(word: Word, ui_lang: str) -> str | None:
    return getattr(word, _EXAMPLE_COL.get(ui_lang, "example_translation_ru"))


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

_SYSTEM_BASE = (
    "You are a language-learning content generator. "
    "Always reply with strict valid JSON only, no commentary, no markdown fences. "
    "Keep vocabulary appropriate for the requested CEFR level."
)


def _topic_clause(topic: str | None) -> str:
    if topic and topic.strip():
        return f"Theme: {topic.strip()!r}. All items MUST be related to this theme."
    return "Theme: general everyday vocabulary."


# ---------------------------------------------------------------------------
# Word Match
# ---------------------------------------------------------------------------

async def gen_word_match(
    db: AsyncSession,
    *,
    user: User,
    topic: str | None,
    language_code: str,
    count: int,
    level_override: str | None,
) -> dict[str, Any]:
    profile = await _get_profile(db, user)
    level = _resolve_level(profile, level_override)
    ui = _ui_lang(profile)

    if not topic:
        lang_id = await _resolve_language_id(db, language_code)
        words = await _fetch_words(db, language_id=lang_id, level=level, ui_lang=ui, count=count)
        pairs = [
            {"word": w.lemma, "translation": _translation_of(w, ui) or ""}
            for w in words
            if _translation_of(w, ui)
        ]
        if len(pairs) < 2:
            raise ValueError("Not enough words in the database for this level")
        return {"topic_label": None, "level": _level_label(level), "pairs": pairs}

    target_lang = "Russian" if ui == "ru" else "Kazakh"
    level_clause = f"at CEFR {level.value}" if level is not None else "at any level (mix beginner to advanced)"
    prompt = (
        f"Generate {count} distinct {language_code} vocabulary items {level_clause} "
        f"with their {target_lang} translations. {_topic_clause(topic)} "
        "Return ONLY a JSON object: "
        '{"pairs":[{"word":"...","translation":"..."}, ...]}. '
        "Single-word entries preferred; short collocations are okay if natural. "
        "No duplicates."
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.7)
    pairs = _coerce_list_of_objects(data, "pairs", required=("word", "translation"))
    return {"topic_label": topic, "level": _level_label(level), "pairs": pairs[:count]}


# ---------------------------------------------------------------------------
# Word Scramble
# ---------------------------------------------------------------------------

async def gen_word_scramble(
    db: AsyncSession,
    *,
    user: User,
    topic: str | None,
    language_code: str,
    count: int,
    level_override: str | None,
) -> dict[str, Any]:
    profile = await _get_profile(db, user)
    level = _resolve_level(profile, level_override)
    ui = _ui_lang(profile)

    if not topic:
        lang_id = await _resolve_language_id(db, language_code)
        words = await _fetch_words(db, language_id=lang_id, level=level, ui_lang=ui, count=count)
        items = []
        for w in words:
            tr = _translation_of(w, ui)
            if not tr or " " in w.lemma:
                continue
            items.append({"word": w.lemma, "translation": tr, "hint": None})
        if len(items) < 1:
            raise ValueError("Not enough single-word entries for this level")
        return {"topic_label": None, "level": _level_label(level), "items": items[:count]}

    target_lang = "Russian" if ui == "ru" else "Kazakh"
    level_clause = f"at CEFR {level.value}" if level is not None else "at any level (mix beginner to advanced)"
    prompt = (
        f"Generate {count} single-word {language_code} vocabulary entries {level_clause} "
        f"for a scramble (anagram) game, with their {target_lang} translations and a short "
        f"one-line hint in {target_lang}. {_topic_clause(topic)} "
        "Each word MUST be a single word (no spaces), 4-10 letters, lowercase. "
        'Return ONLY: {"items":[{"word":"...","translation":"...","hint":"..."}, ...]}. '
        "No duplicates."
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.7)
    items = _coerce_list_of_objects(data, "items", required=("word", "translation"))
    # Drop multi-word entries defensively
    items = [i for i in items if " " not in i["word"].strip()]
    return {"topic_label": topic, "level": _level_label(level), "items": items[:count]}


# ---------------------------------------------------------------------------
# Sentence Builder
# ---------------------------------------------------------------------------

async def gen_sentence_builder(
    db: AsyncSession,
    *,
    user: User,
    topic: str | None,
    language_code: str,
    count: int,
    level_override: str | None,
) -> dict[str, Any]:
    profile = await _get_profile(db, user)
    level = _resolve_level(profile, level_override)
    ui = _ui_lang(profile)

    if not topic:
        lang_id = await _resolve_language_id(db, language_code)
        words = await _fetch_words(db, language_id=lang_id, level=level, ui_lang=ui, count=count * 2)
        items = []
        for w in words:
            if not w.example_sentence:
                continue
            tr = _example_translation_of(w, ui) or _translation_of(w, ui)
            if not tr:
                continue
            items.append({"sentence": w.example_sentence, "translation": tr})
            if len(items) >= count:
                break
        if not items:
            raise ValueError("Not enough sentence examples for this level")
        return {"topic_label": None, "level": _level_label(level), "items": items}

    target_lang = "Russian" if ui == "ru" else "Kazakh"
    level_clause = f"at CEFR {level.value}" if level is not None else "at any level (mix beginner to advanced)"
    prompt = (
        f"Generate {count} short {language_code} sentences {level_clause} "
        f"(4-8 words each), with their {target_lang} translation. {_topic_clause(topic)} "
        "Sentences must be natural and unambiguous in word order. "
        'Return ONLY: {"items":[{"sentence":"...","translation":"..."}, ...]}.'
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.7)
    items = _coerce_list_of_objects(data, "items", required=("sentence", "translation"))
    return {"topic_label": topic, "level": _level_label(level), "items": items[:count]}


# ---------------------------------------------------------------------------
# Hangman
# ---------------------------------------------------------------------------

async def gen_hangman(
    db: AsyncSession,
    *,
    user: User,
    topic: str | None,
    language_code: str,
    level_override: str | None,
) -> dict[str, Any]:
    profile = await _get_profile(db, user)
    level = _resolve_level(profile, level_override)
    ui = _ui_lang(profile)

    if not topic:
        lang_id = await _resolve_language_id(db, language_code)
        words = await _fetch_words(db, language_id=lang_id, level=level, ui_lang=ui, count=30)
        candidates = [w for w in words if " " not in w.lemma and 4 <= len(w.lemma) <= 12]
        if not candidates:
            raise ValueError("No suitable words for this level")
        w = random.choice(candidates)
        tr = _translation_of(w, ui) or ""
        return {
            "topic_label": None,
            "level": _level_label(level),
            "word": w.lemma.lower(),
            "translation": tr,
            "hint": tr,
        }

    target_lang = "Russian" if ui == "ru" else "Kazakh"
    level_clause = f"at CEFR {level.value}" if level is not None else "at any level"
    prompt = (
        f"Pick ONE {language_code} word {level_clause} for a hangman game. "
        f"{_topic_clause(topic)} The word must be a single word (no spaces), "
        f"5-10 letters, lowercase. Provide its {target_lang} translation and a one-line "
        f"hint in {target_lang} that does NOT contain the word itself. "
        'Return ONLY: {"word":"...","translation":"...","hint":"..."}.'
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.8)
    if not isinstance(data, dict):
        raise ValueError("Bad AI response")
    word = str(data.get("word", "")).strip().lower()
    translation = str(data.get("translation", "")).strip()
    hint = str(data.get("hint", "")).strip()
    if not word or " " in word or not translation or not hint:
        raise ValueError("Incomplete AI response")
    return {
        "topic_label": topic,
        "level": _level_label(level),
        "word": word,
        "translation": translation,
        "hint": hint,
    }


# ---------------------------------------------------------------------------
# Internal: coerce LLM JSON shape defensively
# ---------------------------------------------------------------------------

def _coerce_list_of_objects(
    data: Any, key: str, *, required: tuple[str, ...]
) -> list[dict[str, str]]:
    """Accepts either {key: [...]} or [...] and validates required string fields."""
    raw: Any
    if isinstance(data, dict):
        raw = data.get(key) or data.get("items") or data.get("pairs")
        if raw is None and len(data) == 1:
            raw = next(iter(data.values()))
    else:
        raw = data
    if not isinstance(raw, list):
        raise ValueError("AI did not return a list")
    out: list[dict[str, str]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        ok = True
        norm: dict[str, str] = {}
        for f in required:
            v = entry.get(f)
            if not isinstance(v, str) or not v.strip():
                ok = False
                break
            norm[f] = v.strip()
        if not ok:
            continue
        # carry optional fields
        for k, v in entry.items():
            if k not in norm and isinstance(v, str):
                norm[k] = v.strip()
        out.append(norm)
    if not out:
        raise ValueError("AI returned no valid entries")
    return out


__all__ = [
    "GeminiError",
    "gen_hangman",
    "gen_sentence_builder",
    "gen_word_match",
    "gen_word_scramble",
]
