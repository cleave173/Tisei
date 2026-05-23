"""Bulk import of Oxford 5000 exclusive (B2-C1) wordlist.

Oxford 5000 = Oxford 3000 + 2000 extra B2/C1 words ("exclusive" set).
We import only the exclusive part (1404 C1 + 734 B2). The C1 entries are
the main upgrade — CEFR-J only covers ~30 C1 words.

Schema (CSV columns):
    word, type, cefr (b2|c1), phon_br, phon_n_am, definition, example

Pipeline:
    1. Parse CSV.
    2. Reuse phon_n_am as IPA (high-quality Oxford transcription).
    3. Translate lemma + example EN -> RU (LibreTranslate) + EN -> KK (Yandex).
    4. Upsert into `words` (skip duplicates by (language_id, lemma)).

Source: winterdl/oxford-5000-vocabulary-audio-definition (CC0/MIT, scraped
from Oxford Learner's Dictionaries — used here for educational purposes only).
"""
from __future__ import annotations

import asyncio
import csv
import json
import logging
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal as async_session_maker  # noqa: E402
from app.models import Language, Word  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("import_oxford5000")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
CACHE_PATH = DATA_DIR / "cache_oxford5000.jsonl"
SRC_CSV = DATA_DIR / "oxford_5000_exclusive.csv"

POS_MAP: dict[str, str] = {
    "verb": "verb",
    "noun": "noun",
    "adjective": "adj",
    "adverb": "adv",
    "pronoun": "pron",
    "preposition": "prep",
    "conjunction": "conj",
    "determiner": "det",
    "interjection": "interj",
    "auxiliary verb": "aux",
    "modal verb": "aux",
    "number": "num",
}

CEFR_MAP = {"b2": "B2", "c1": "C1", "c2": "C2"}
SLASH_RE = re.compile(r"^/(.+)/$")


@dataclass
class WordRow:
    lemma: str
    pos: str | None
    level: str
    ipa: str | None = None
    translation_ru: str | None = None
    translation_kk: str | None = None
    example: str | None = None
    example_ru: str | None = None
    example_kk: str | None = None
    definition_en: str | None = None
    source: str = "oxford-5000"

    @property
    def key(self) -> str:
        return f"{self.lemma}::{self.pos or ''}"

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


# ---------------------------------------------------------------------------
# Parse
# ---------------------------------------------------------------------------

def parse_csv(path: Path) -> list[WordRow]:
    rows: dict[str, WordRow] = {}
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            lemma = (raw.get("word") or "").strip().lower()
            if not lemma or not re.match(r"^[a-z][a-z\-' ]*$", lemma):
                continue

            pos_raw = (raw.get("type") or "").strip().lower()
            pos = POS_MAP.get(pos_raw, pos_raw or None)
            if pos and len(pos) > 20:
                pos = pos[:20]

            cefr_raw = (raw.get("cefr") or "").strip().lower()
            level = CEFR_MAP.get(cefr_raw)
            if not level:
                continue

            # Use US transcription (more globally recognisable)
            phon = (raw.get("phon_n_am") or raw.get("phon_br") or "").strip()
            if phon:
                m = SLASH_RE.match(phon)
                if m:
                    phon = m.group(1)
            else:
                phon = None

            example = (raw.get("example") or "").strip() or None
            definition = (raw.get("definition") or "").strip() or None

            key = f"{lemma}::{pos or ''}"
            if key not in rows:
                rows[key] = WordRow(
                    lemma=lemma,
                    pos=pos,
                    level=level,
                    ipa=phon,
                    example=example,
                    definition_en=definition,
                )
    log.info("Parsed %d Oxford 5000 entries", len(rows))
    return list(rows.values())


# ---------------------------------------------------------------------------
# Translation clients
# ---------------------------------------------------------------------------

class LibreTranslateClient:
    def __init__(self, base_url: str) -> None:
        self._url = base_url.rstrip("/")
        self._client = httpx.AsyncClient(timeout=60.0)

    async def close(self) -> None:
        await self._client.aclose()

    async def translate_batch(self, texts: list[str], target: str) -> list[str]:
        if not texts:
            return []
        try:
            r = await self._client.post(
                f"{self._url}/translate",
                json={"q": texts, "source": "en", "target": target, "format": "text"},
            )
            r.raise_for_status()
            data = r.json()
        except httpx.HTTPError as e:
            log.warning("LibreTranslate batch failed: %s", e)
            return ["" for _ in texts]
        out = data.get("translatedText")
        if isinstance(out, list):
            return [str(x) for x in out]
        if isinstance(out, str):
            return [out]
        return ["" for _ in texts]


class YandexTranslateClient:
    def __init__(self, api_key: str, folder_id: str) -> None:
        self._api_key = api_key
        self._folder_id = folder_id
        self._client = httpx.AsyncClient(timeout=60.0)
        self._url = "https://translate.api.cloud.yandex.net/translate/v2/translate"

    async def close(self) -> None:
        await self._client.aclose()

    async def translate_batch(self, texts: list[str], source: str, target: str) -> list[str]:
        if not texts:
            return []
        try:
            r = await self._client.post(
                self._url,
                headers={"Authorization": f"Api-Key {self._api_key}"},
                json={
                    "folderId": self._folder_id,
                    "sourceLanguageCode": source,
                    "targetLanguageCode": target,
                    "texts": texts,
                    "format": "PLAIN_TEXT",
                },
            )
            r.raise_for_status()
            data = r.json()
        except httpx.HTTPError as e:
            log.warning("Yandex batch failed: %s", e)
            return ["" for _ in texts]
        translations = data.get("translations") or []
        return [str(t.get("text", "")) for t in translations]


# ---------------------------------------------------------------------------
# Cache (resumable)
# ---------------------------------------------------------------------------

def _write_cache(rows: list[WordRow]) -> None:
    with CACHE_PATH.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r.as_dict(), ensure_ascii=False) + "\n")


def _read_cache() -> dict[str, WordRow]:
    if not CACHE_PATH.exists():
        return {}
    out: dict[str, WordRow] = {}
    with CACHE_PATH.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            d = json.loads(line)
            r = WordRow(**{k: d.get(k) for k in WordRow.__dataclass_fields__})
            out[r.key] = r
    return out


def merge_cache(fresh: list[WordRow]) -> list[WordRow]:
    cached = _read_cache()
    if not cached:
        return fresh
    merged: list[WordRow] = []
    for r in fresh:
        c = cached.get(r.key)
        if c is not None:
            r.translation_ru = c.translation_ru or r.translation_ru
            r.translation_kk = c.translation_kk or r.translation_kk
            r.example_ru = c.example_ru or r.example_ru
            r.example_kk = c.example_kk or r.example_kk
        merged.append(r)
    log.info("Cache merged: %d cached entries applied", len(cached))
    return merged


# ---------------------------------------------------------------------------
# Translate pipeline
# ---------------------------------------------------------------------------

async def translate_all(
    rows: list[WordRow],
    libre_url: str,
    yandex_key: str | None,
    yandex_folder_id: str | None,
    batch_size: int = 50,
) -> None:
    libre = LibreTranslateClient(libre_url)
    yandex = (
        YandexTranslateClient(yandex_key, yandex_folder_id)
        if yandex_key and yandex_folder_id
        else None
    )

    try:
        # ---------- RU lemmas ----------
        todo = [r for r in rows if not r.translation_ru]
        log.info("RU lemmas: %d", len(todo))
        for i in range(0, len(todo), batch_size):
            batch = todo[i : i + batch_size]
            results = await libre.translate_batch([r.lemma for r in batch], target="ru")
            for r, tr in zip(batch, results, strict=True):
                r.translation_ru = tr.lower() if tr else None
            _write_cache(rows)
            if i % 500 == 0:
                log.info("  RU lemma progress: %d/%d", min(i + batch_size, len(todo)), len(todo))

        # ---------- RU examples ----------
        todo = [r for r in rows if r.example and not r.example_ru]
        log.info("RU examples: %d", len(todo))
        for i in range(0, len(todo), batch_size):
            batch = todo[i : i + batch_size]
            results = await libre.translate_batch([r.example for r in batch], target="ru")
            for r, tr in zip(batch, results, strict=True):
                r.example_ru = tr or None
            _write_cache(rows)

        if yandex is not None:
            # ---------- KK lemmas ----------
            todo = [r for r in rows if not r.translation_kk]
            log.info("KK lemmas: %d", len(todo))
            for i in range(0, len(todo), batch_size):
                batch = todo[i : i + batch_size]
                results = await yandex.translate_batch(
                    [r.lemma for r in batch], source="en", target="kk"
                )
                for r, tr in zip(batch, results, strict=True):
                    r.translation_kk = tr.lower() if tr else None
                _write_cache(rows)
                if i % 500 == 0:
                    log.info("  KK lemma progress: %d/%d", min(i + batch_size, len(todo)), len(todo))

            # ---------- KK examples ----------
            todo = [r for r in rows if r.example and not r.example_kk]
            log.info("KK examples: %d", len(todo))
            for i in range(0, len(todo), batch_size):
                batch = todo[i : i + batch_size]
                results = await yandex.translate_batch(
                    [r.example for r in batch], source="en", target="kk"
                )
                for r, tr in zip(batch, results, strict=True):
                    r.example_kk = tr or None
                _write_cache(rows)
        else:
            log.warning("KK translation skipped (no Yandex credentials)")
    finally:
        await libre.close()
        if yandex is not None:
            await yandex.close()


# ---------------------------------------------------------------------------
# Seed DB
# ---------------------------------------------------------------------------

async def seed_db(rows: list[WordRow], language_code: str = "en") -> int:
    inserted = 0
    skipped = 0
    async with async_session_maker() as db:
        lang = (
            await db.execute(select(Language).where(Language.code == language_code))
        ).scalar_one_or_none()
        if lang is None:
            raise RuntimeError(f"Language '{language_code}' not in DB")

        existing = {
            l for (l,) in (
                await db.execute(select(Word.lemma).where(Word.language_id == lang.id))
            ).all()
        }

        batch: list[dict[str, Any]] = []
        for r in rows:
            if r.lemma in existing:
                skipped += 1
                continue
            batch.append({
                "language_id": lang.id,
                "topic_id": None,
                "lemma": r.lemma,
                "part_of_speech": r.pos,
                "transcription_ipa": r.ipa,
                "translation_ru": r.translation_ru,
                "translation_kk": r.translation_kk,
                "example_sentence": r.example,
                "example_translation_ru": r.example_ru,
                "example_translation_kk": r.example_kk,
                "level": r.level,
                "sublevel": 1,
            })
            existing.add(r.lemma)
            if len(batch) >= 500:
                stmt = pg_insert(Word).values(batch).on_conflict_do_nothing(
                    index_elements=["language_id", "lemma"]
                )
                await db.execute(stmt)
                inserted += len(batch)
                batch.clear()

        if batch:
            stmt = pg_insert(Word).values(batch).on_conflict_do_nothing(
                index_elements=["language_id", "lemma"]
            )
            await db.execute(stmt)
            inserted += len(batch)

        await db.commit()

    log.info("DB seed: +%d inserted, %d skipped (duplicates)", inserted, skipped)
    return inserted


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not SRC_CSV.exists():
        raise SystemExit(
            f"Missing source CSV at {SRC_CSV}. Download with:\n"
            f"  curl -sL https://raw.githubusercontent.com/winterdl/"
            f"oxford-5000-vocabulary-audio-definition/master/data/"
            f"oxford_5000_exclusive.csv -o {SRC_CSV}"
        )

    rows = parse_csv(SRC_CSV)
    rows = merge_cache(rows)

    yandex_key = os.getenv("YANDEX_TRANSLATE_API_KEY") or settings.yandex_translate_api_key
    yandex_folder = os.getenv("YANDEX_FOLDER_ID") or settings.yandex_folder_id

    await translate_all(
        rows,
        libre_url=settings.libretranslate_url,
        yandex_key=yandex_key,
        yandex_folder_id=yandex_folder,
        batch_size=int(os.getenv("BATCH_SIZE", "50")),
    )
    _write_cache(rows)

    inserted = await seed_db(rows, language_code="en")
    log.info("Done. %d words added (cache: %s).", inserted, CACHE_PATH)


if __name__ == "__main__":
    asyncio.run(main())
