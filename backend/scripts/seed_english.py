"""Seed the English course content.

Idempotent: re-running updates existing rows by natural keys
(`languages.code`, `(language_id, slug)` for topics, `(language_id, lemma)`
for words, `achievements.code`).

Run:
    docker compose -f infra/docker-compose.yml exec backend \
        python -m scripts.seed_english
"""
from __future__ import annotations

import asyncio
import json
import random
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.models import (
    Achievement,
    CefrLevel,
    Language,
    Lesson,
    LessonType,
    Question,
    QuestionType,
    Topic,
    Word,
)

SEEDS_DIR = Path(__file__).resolve().parents[1] / "app" / "seeds"
RANDOM_SEED = 42  # deterministic distractor selection


# ---------------------------------------------------------------------------
# Upsert helpers
# ---------------------------------------------------------------------------

async def _upsert_language(session: AsyncSession) -> Language:
    """Ensure the English language row exists and return it."""
    stmt = pg_insert(Language).values(
        code="en",
        name="English",
        description="Learn the English language: vocabulary, grammar and conversation.",
        is_active=True,
    ).on_conflict_do_update(
        index_elements=[Language.code],
        set_={"name": "English", "is_active": True},
    ).returning(Language.id)
    res = await session.execute(stmt)
    lang_id = res.scalar_one()

    obj = await session.get(Language, lang_id)
    assert obj is not None
    return obj


async def _upsert_topics(session: AsyncSession, language: Language) -> dict[str, Topic]:
    raw = json.loads((SEEDS_DIR / "topics.json").read_text(encoding="utf-8"))
    by_slug: dict[str, Topic] = {}
    for item in raw:
        stmt = pg_insert(Topic).values(
            language_id=language.id,
            slug=item["slug"],
            title=item["title"],
            title_ru=item.get("title_ru"),
            title_kk=item.get("title_kk"),
            level=CefrLevel(item.get("level", "A1")),
            order=item.get("order", 0),
            icon_url=None,
        ).on_conflict_do_update(
            index_elements=["language_id", "slug"],
            set_={
                "title": item["title"],
                "title_ru": item.get("title_ru"),
                "title_kk": item.get("title_kk"),
                "level": CefrLevel(item.get("level", "A1")),
                "order": item.get("order", 0),
            },
        ).returning(Topic.id)
        topic_id = (await session.execute(stmt)).scalar_one()
        topic = await session.get(Topic, topic_id)
        assert topic is not None
        by_slug[item["slug"]] = topic
    return by_slug


async def _upsert_words(
    session: AsyncSession, language: Language, topics_by_slug: dict[str, Topic]
) -> list[Word]:
    # Load every words_*.json under the seeds dir so vocabulary can be split by level/topic.
    raw: list[dict] = []
    for path in sorted(SEEDS_DIR.glob("words_*.json")):
        raw.extend(json.loads(path.read_text(encoding="utf-8")))
    out: list[Word] = []
    for w in raw:
        topic = topics_by_slug.get(w["topic"])
        if topic is None:
            raise ValueError(f"Unknown topic slug: {w['topic']}")

        # Default level falls back to topic's own CEFR level if not specified.
        level_str = w.get("level") or (
            topic.level.value if hasattr(topic.level, "value") else str(topic.level)
        )
        sublevel = int(w.get("sublevel", 1))
        if sublevel not in (1, 2):
            sublevel = 1

        values = dict(
            language_id=language.id,
            topic_id=topic.id,
            lemma=w["lemma"],
            part_of_speech=w.get("pos"),
            transcription_ipa=w.get("ipa"),
            translation_ru=w.get("ru"),
            translation_kk=w.get("kk"),
            example_sentence=w.get("ex"),
            example_translation_ru=w.get("ex_ru"),
            example_translation_kk=w.get("ex_kk"),
            frequency_rank=w.get("freq"),
            difficulty=w.get("difficulty", 1),
            level=level_str,
            sublevel=sublevel,
        )
        stmt = pg_insert(Word).values(**values).on_conflict_do_update(
            index_elements=["language_id", "lemma"],
            set_={k: v for k, v in values.items() if k not in ("language_id", "lemma")},
        ).returning(Word.id)
        word_id = (await session.execute(stmt)).scalar_one()
        word = await session.get(Word, word_id)
        assert word is not None
        out.append(word)
    return out


async def _upsert_achievements(session: AsyncSession) -> None:
    raw = json.loads((SEEDS_DIR / "achievements.json").read_text(encoding="utf-8"))
    for a in raw:
        stmt = pg_insert(Achievement).values(
            code=a["code"],
            name=a["name"],
            description=a.get("description"),
            requirement_value=a.get("requirement_value", 0),
            stars=a.get("stars", 1),
        ).on_conflict_do_update(
            index_elements=[Achievement.code],
            set_={
                "name": a["name"],
                "description": a.get("description"),
                "requirement_value": a.get("requirement_value", 0),
                "stars": a.get("stars", 1),
            },
        )
        await session.execute(stmt)


# ---------------------------------------------------------------------------
# Auto-generated lessons & questions
# ---------------------------------------------------------------------------

async def _generate_vocab_lessons(
    session: AsyncSession,
    language: Language,
    topics_by_slug: dict[str, Topic],
    all_words: list[Word],
) -> None:
    """For each topic create a single vocabulary lesson with 1 multiple-choice
    question per topic word. Distractor translations are sampled from words of
    *other* topics so every quiz has 4 plausible options.

    Idempotency: lessons are looked up by (language_id, topic_id, type=vocab,
    title prefix). Existing questions are wiped and regenerated to keep
    content in sync with the seed JSON.
    """
    rng = random.Random(RANDOM_SEED)
    words_by_topic: dict[int, list[Word]] = {}
    for w in all_words:
        if w.topic_id is None:
            continue
        words_by_topic.setdefault(w.topic_id, []).append(w)

    for slug, topic in topics_by_slug.items():
        topic_words = words_by_topic.get(topic.id, [])
        if not topic_words:
            continue

        title = f"{topic.title} · Vocabulary"

        # Find or create lesson
        existing = await session.execute(
            select(Lesson).where(
                Lesson.language_id == language.id,
                Lesson.topic_id == topic.id,
                Lesson.type == LessonType.vocabulary,
            )
        )
        lesson = existing.scalar_one_or_none()
        if lesson is None:
            lesson = Lesson(
                language_id=language.id,
                topic_id=topic.id,
                type=LessonType.vocabulary,
                title=title,
                description=f"Learn the most common words about {topic.title.lower()}.",
                order=topic.order,
                xp_reward=10,
                estimated_minutes=5,
            )
            session.add(lesson)
            await session.flush()
        else:
            lesson.title = title
            lesson.order = topic.order
            # Wipe existing questions to regenerate from current seeds
            await session.execute(
                Question.__table__.delete().where(Question.lesson_id == lesson.id)
            )

        # Pool of distractor translations from words in other topics
        other_words = [w for w in all_words if w.topic_id != topic.id and w.translation_ru]

        for idx, word in enumerate(topic_words):
            if not word.translation_ru:
                continue
            distractors = rng.sample(other_words, k=min(3, len(other_words)))
            options = [d.translation_ru for d in distractors] + [word.translation_ru]
            rng.shuffle(options)
            correct_index = options.index(word.translation_ru)

            content = {
                "prompt": f"What does “{word.lemma}” mean?",
                "lemma": word.lemma,
                "ipa": word.transcription_ipa,
                "options": options,
                "correct_index": correct_index,
                # Localized prompts so Flutter can pick the right one based on UI lang
                "prompts": {
                    "en": f"What does “{word.lemma}” mean?",
                    "ru": f"Что означает «{word.lemma}»?",
                    "kk": f"«{word.lemma}» нені білдіреді?",
                },
            }
            session.add(
                Question(
                    lesson_id=lesson.id,
                    type=QuestionType.multiple_choice,
                    order=idx,
                    content=content,
                    correct_answer=word.translation_ru,
                )
            )


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

async def seed() -> None:
    async with SessionLocal() as session:  # type: AsyncSession
        async with session.begin():
            language = await _upsert_language(session)
            topics_by_slug = await _upsert_topics(session, language)
            words = await _upsert_words(session, language, topics_by_slug)
            await _upsert_achievements(session)
            await _generate_vocab_lessons(session, language, topics_by_slug, words)
        print(
            f"Seed OK: language={language.code}, topics={len(topics_by_slug)}, "
            f"words={len(words)}"
        )


if __name__ == "__main__":
    asyncio.run(seed())
