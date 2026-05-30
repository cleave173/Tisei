"""Service layer for AI-powered language games.

Two modes per game:
  * default — pulls words/sentences from the existing DB at the user's CEFR level
  * custom  — calls Gemini with a topic-specific prompt and validates JSON output
"""
from __future__ import annotations

import logging
import random
import re
from collections import deque
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
_MAX_TOPIC_MEMORY = 160
_RECENT_AI_TERMS: dict[tuple[int, str, str, str, str], deque[str]] = {}


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


def _topic_memory_key(
    *, user: User, game: str, topic: str | None, language_code: str, level: CefrLevel | None
) -> tuple[int, str, str, str, str]:
    normalized_topic = re.sub(r"\s+", " ", (topic or "").strip().lower())
    return (user.id, game, language_code.lower(), _level_label(level), normalized_topic)


def _normalize_term(value: str) -> str:
    lowered = value.strip().lower()
    lowered = re.sub(r"[^a-zа-яәғқңөұүһіё0-9' -]+", "", lowered)
    return re.sub(r"\s+", " ", lowered).strip()


def _seen_terms(key: tuple[int, str, str, str, str]) -> set[str]:
    return set(_RECENT_AI_TERMS.get(key, ()))


def _remember_terms(key: tuple[int, str, str, str, str], values: list[str]) -> None:
    bucket = _RECENT_AI_TERMS.setdefault(key, deque(maxlen=_MAX_TOPIC_MEMORY))
    for value in values:
        normalized = _normalize_term(value)
        if normalized and normalized not in bucket:
            bucket.append(normalized)


def _exclude_clause(seen: set[str]) -> str:
    if not seen:
        return ""
    sample = ", ".join(sorted(seen)[-80:])
    return (
        "Avoid repeating anything from this previous-output list for the same user/theme: "
        f"{sample}. "
    )


def _topic_depth_clause(topic: str | None) -> str:
    if not topic or not topic.strip():
        return "Theme: general everyday vocabulary."
    clean_topic = topic.strip()
    return (
        f"Theme: {clean_topic!r}. Treat the theme like a specific fandom, field, or subculture. "
        "Before choosing items, infer its subdomains: named concepts, roles, factions, places, "
        "mechanics, materials, rituals, conflicts, professions, tools, creatures, lore terms, "
        "and idiomatic collocations. Prefer precise, topic-native vocabulary over broad obvious "
        "associations. Avoid generic beginner words unless they are uniquely central to the theme. "
        "For example, do not stop at surface words like 'sword', 'poison', 'monster', 'magic', "
        "or 'king' when the topic supports more specific terms. "
    )


def _request_count(count: int) -> int:
    return min(30, max(count * 3, count + 10))


def _dedupe_items(
    items: list[dict[str, str]],
    *,
    term_field: str,
    seen: set[str],
    count: int,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    local_seen: set[str] = set()
    for item in items:
        term = _normalize_term(item.get(term_field, ""))
        if not term or term in seen or term in local_seen:
            continue
        local_seen.add(term)
        out.append(item)
        if len(out) >= count:
            break
    if out:
        return out

    # Last-resort fallback: still dedupe within this response if the model ignored exclusions.
    for item in items:
        term = _normalize_term(item.get(term_field, ""))
        if not term or term in local_seen:
            continue
        local_seen.add(term)
        out.append(item)
        if len(out) >= count:
            break
    return out


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


async def _fetch_sentence_items(
    db: AsyncSession,
    *,
    language_id: int,
    level: CefrLevel | None,
    ui_lang: str,
    count: int,
) -> list[dict[str, str]]:
    """Fetch words that have example sentences; return formatted sentence items."""
    ex_col = _EXAMPLE_COL.get(ui_lang, "example_translation_ru")
    conds = [
        Word.language_id == language_id,
        Word.example_sentence.is_not(None),
        getattr(Word, ex_col).is_not(None),
    ]
    if level is not None:
        conds.append(Word.level == level)
    stmt = select(Word).where(*conds).limit(500)
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return []
    pool = list(rows)
    random.shuffle(pool)
    items = []
    for w in pool[:count * 3]:
        ex = w.example_sentence
        tr = _example_translation_of(w, ui_lang) or _translation_of(w, ui_lang)
        if not ex or not tr:
            continue
        items.append({"sentence": ex, "translation": tr})
        if len(items) >= count:
            break
    return items


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

_SYSTEM_BASE = (
    "You are a language-learning content generator. "
    "Always reply with strict valid JSON only, no commentary, no markdown fences. "
    "Keep grammar and explanations appropriate for the requested CEFR level, but make custom "
    "topic vocabulary specific, researched-feeling, and non-obvious."
)


def _topic_clause(topic: str | None) -> str:
    if topic and topic.strip():
        return _topic_depth_clause(topic)
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
    memory_key = _topic_memory_key(
        user=user, game="word_match", topic=topic, language_code=language_code, level=level
    )
    seen = _seen_terms(memory_key)
    requested = _request_count(count)
    prompt = (
        f"Generate {requested} distinct {language_code} vocabulary items {level_clause} "
        f"with their {target_lang} translations. {_topic_clause(topic)} "
        f"{_exclude_clause(seen)}"
        "Return ONLY a JSON object: "
        '{"pairs":[{"word":"...","translation":"..."}, ...]}. '
        "Use a mix of single words and natural short collocations when that makes the theme more precise. "
        "Avoid vague umbrella terms. No duplicates."
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.9)
    pairs = _coerce_list_of_objects(data, "pairs", required=("word", "translation"))
    pairs = _dedupe_items(pairs, term_field="word", seen=seen, count=count)
    _remember_terms(memory_key, [p["word"] for p in pairs])
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
    memory_key = _topic_memory_key(
        user=user, game="word_scramble", topic=topic, language_code=language_code, level=level
    )
    seen = _seen_terms(memory_key)
    requested = _request_count(count)
    prompt = (
        f"Generate {requested} single-word {language_code} vocabulary entries {level_clause} "
        f"for a scramble (anagram) game, with their {target_lang} translations and a short "
        f"one-line hint in {target_lang}. {_topic_clause(topic)} "
        f"{_exclude_clause(seen)}"
        "Each word MUST be a single word (no spaces), 4-10 letters, lowercase. "
        "Prefer distinctive proper nouns, roles, artifacts, places, materials, or lore terms "
        "when they fit the theme and length limit. "
        'Return ONLY: {"items":[{"word":"...","translation":"...","hint":"..."}, ...]}. '
        "No duplicates."
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.9)
    items = _coerce_list_of_objects(data, "items", required=("word", "translation"))
    # Drop multi-word entries defensively
    items = [i for i in items if " " not in i["word"].strip()]
    items = _dedupe_items(items, term_field="word", seen=seen, count=count)
    _remember_terms(memory_key, [i["word"] for i in items])
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
        items = await _fetch_sentence_items(
            db, language_id=lang_id, level=level, ui_lang=ui, count=count
        )
        if not items:
            raise ValueError(
                "Not enough sentence examples for this level. "
                "Try a different level or use AI mode with a custom topic."
            )
        return {"topic_label": None, "level": _level_label(level), "items": items}

    target_lang = "Russian" if ui == "ru" else "Kazakh"
    level_clause = f"at CEFR {level.value}" if level is not None else "at any level (mix beginner to advanced)"
    memory_key = _topic_memory_key(
        user=user, game="sentence_builder", topic=topic, language_code=language_code, level=level
    )
    seen = _seen_terms(memory_key)
    requested = _request_count(count)
    prompt = (
        f"Generate {requested} short {language_code} sentences {level_clause} "
        f"(4-8 words each), with their {target_lang} translation. {_topic_clause(topic)} "
        f"{_exclude_clause(seen)}"
        "Sentences must be natural and unambiguous in word order. "
        "Each sentence should include at least one theme-specific term, not only generic action words. "
        'Return ONLY: {"items":[{"sentence":"...","translation":"..."}, ...]}.'
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.9)
    items = _coerce_list_of_objects(data, "items", required=("sentence", "translation"))
    items = _dedupe_items(items, term_field="sentence", seen=seen, count=count)
    _remember_terms(memory_key, [i["sentence"] for i in items])
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
    memory_key = _topic_memory_key(
        user=user, game="hangman", topic=topic, language_code=language_code, level=level
    )
    seen = _seen_terms(memory_key)
    prompt = (
        f"Generate 12 candidate {language_code} words {level_clause} for a hangman game. "
        f"{_topic_clause(topic)} {_exclude_clause(seen)}"
        "Each word must be a single word (no spaces), 5-12 letters, lowercase. "
        "Prefer distinctive theme-native terms over obvious generic words. "
        f"Provide each {target_lang} translation and a one-line hint in {target_lang} "
        "that does NOT contain the word itself. "
        'Return ONLY: {"items":[{"word":"...","translation":"...","hint":"..."}, ...]}.'
    )
    data = await generate_json(prompt=prompt, system=_SYSTEM_BASE, temperature=0.95)
    items = _coerce_list_of_objects(data, "items", required=("word", "translation", "hint"))
    items = [i for i in items if " " not in i["word"].strip() and 5 <= len(i["word"].strip()) <= 12]
    items = _dedupe_items(items, term_field="word", seen=seen, count=1)
    if not items:
        raise ValueError("Incomplete AI response")
    item = items[0]
    word = item["word"].strip().lower()
    translation = item["translation"].strip()
    hint = item["hint"].strip()
    _remember_terms(memory_key, [word])
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
