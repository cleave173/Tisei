"""Bulk import enriched words (CEFR-J + Oxford 5000) with topic assignments.

Reads:
  - data/cache_enriched.jsonl         (CEFR-J A1..B2)
  - data/cache_oxford5000.jsonl       (Oxford 5000 A1..C1)
  - data/cache_topic_assignments.jsonl (lemma -> topic slug | null)

Inserts into `words` with topic_id resolved from the assignment cache (or
NULL if the word has no assigned topic / Gemini couldn't decide).

Idempotent: uses ON CONFLICT (language_id, lemma) DO UPDATE so re-runs will
refresh topic_id when assignments change but never drop existing data.

Run:
    docker compose -f infra/docker-compose.yml exec backend \
        python -m scripts.bulk_import_words
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.dialects.postgresql import insert as pg_insert  # noqa: E402

from app.db.session import SessionLocal as async_session_maker  # noqa: E402
from app.models import Language, Topic, Word  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("bulk_import")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
ENRICHED_CACHES = [
    DATA_DIR / "cache_enriched.jsonl",
    DATA_DIR / "cache_oxford5000.jsonl",
    DATA_DIR / "cache_c2_generated.jsonl",
]
ASSIGN_CACHE = DATA_DIR / "cache_topic_assignments.jsonl"

LANGUAGE_CODE = "en"
BATCH_SIZE = 500


def _load_enriched() -> dict[str, dict]:
    """Merge both enriched caches; later sources override earlier on lemma key."""
    out: dict[str, dict] = {}
    for path in ENRICHED_CACHES:
        if not path.exists():
            log.warning("Enriched cache missing: %s", path)
            continue
        n = 0
        with path.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                w = json.loads(line)
                lemma = w.get("lemma")
                if not lemma:
                    continue
                out[lemma] = w
                n += 1
        log.info("Loaded %d entries from %s", n, path.name)
    return out


def _load_topic_assignments() -> dict[str, str]:
    """Return {lemma: topic_slug} for lemmas with a valid assignment."""
    out: dict[str, str] = {}
    if not ASSIGN_CACHE.exists():
        log.warning("Assignment cache missing — every imported word will be topic-less")
        return out
    with ASSIGN_CACHE.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            topic = r.get("topic")
            if topic and topic != "__error__":
                out[r["lemma"]] = topic
    log.info("Loaded %d lemma→topic assignments", len(out))
    return out


async def main() -> None:
    enriched = _load_enriched()
    assignments = _load_topic_assignments()

    if not enriched:
        raise SystemExit("No enriched words found — run import_cefrj.py / import_oxford5000.py first")

    async with async_session_maker() as db:
        lang = (
            await db.execute(select(Language).where(Language.code == LANGUAGE_CODE))
        ).scalar_one_or_none()
        if lang is None:
            raise SystemExit(f"Language '{LANGUAGE_CODE}' missing — run seed_english first")

        # Build slug -> topic_id map (only this language's topics)
        topics = (
            await db.execute(select(Topic).where(Topic.language_id == lang.id))
        ).scalars().all()
        slug_to_id = {t.slug: t.id for t in topics}
        log.info("Topics in DB: %d", len(slug_to_id))

        # Skip enriched words whose level is missing
        rows: list[dict[str, Any]] = []
        skipped_no_level = 0
        skipped_no_translation = 0
        for lemma, w in enriched.items():
            level = (w.get("level") or "").upper()
            if level not in {"A1", "A2", "B1", "B2", "C1", "C2"}:
                skipped_no_level += 1
                continue
            # Require at least RU translation (UI shows it)
            if not w.get("translation_ru"):
                skipped_no_translation += 1
                continue
            topic_slug = assignments.get(lemma)
            topic_id = slug_to_id.get(topic_slug) if topic_slug else None
            rows.append(
                {
                    "language_id": lang.id,
                    "topic_id": topic_id,
                    "lemma": lemma,
                    "part_of_speech": w.get("pos"),
                    "transcription_ipa": w.get("ipa"),
                    "translation_ru": w.get("translation_ru"),
                    "translation_kk": w.get("translation_kk"),
                    "example_sentence": w.get("example"),
                    "example_translation_ru": w.get("example_ru"),
                    "example_translation_kk": w.get("example_kk"),
                    "level": level,
                    "sublevel": 1,
                    "frequency_rank": w.get("frequency_rank"),
                }
            )

        log.info(
            "Prepared %d rows (skipped: %d w/o level, %d w/o translation)",
            len(rows), skipped_no_level, skipped_no_translation,
        )

        inserted = 0
        for i in range(0, len(rows), BATCH_SIZE):
            batch = rows[i : i + BATCH_SIZE]
            stmt = pg_insert(Word).values(batch)
            # On conflict, refresh topic_id and translations (but keep id/created_at).
            stmt = stmt.on_conflict_do_update(
                index_elements=["language_id", "lemma"],
                set_={
                    "topic_id": stmt.excluded.topic_id,
                    "part_of_speech": stmt.excluded.part_of_speech,
                    "transcription_ipa": stmt.excluded.transcription_ipa,
                    "translation_ru": stmt.excluded.translation_ru,
                    "translation_kk": stmt.excluded.translation_kk,
                    "example_sentence": stmt.excluded.example_sentence,
                    "example_translation_ru": stmt.excluded.example_translation_ru,
                    "example_translation_kk": stmt.excluded.example_translation_kk,
                    "level": stmt.excluded.level,
                    "frequency_rank": stmt.excluded.frequency_rank,
                },
            )
            await db.execute(stmt)
            inserted += len(batch)
            log.info("  upserted batch %d/%d (%d rows total)", i // BATCH_SIZE + 1, -(-len(rows) // BATCH_SIZE), inserted)

        await db.commit()

    log.info("Done. Upserted %d words.", inserted)


if __name__ == "__main__":
    asyncio.run(main())
