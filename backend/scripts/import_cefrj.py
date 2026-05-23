"""Bulk CEFR vocabulary import.

Pipeline:
  1. Parse the CEFR-J v1.5 CSV (7799 A1-B2 entries).
  2. Enrich with IPA via `eng_to_ipa` (offline CMU Pronouncing Dictionary).
  3. Translate EN -> RU via LibreTranslate (running in compose).
  4. Translate EN -> KK via Yandex Translate API (user-provided key).
  5. Upsert into `words` table with CEFR level + sublevel.

The script is resumable: every enriched word is written to a JSONL cache
(`cache_enriched.jsonl`). Re-running skips already-translated entries.

Source licensing: CEFR-J Wordlist v1.5 by Yukio Tono, TUFS. CC BY-SA 4.0.
Attribution is added in the Tisei `About` screen.
"""
from __future__ import annotations

import asyncio
import csv
import json
import logging
import os
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

import httpx
import eng_to_ipa as _ipa
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

# Make app imports work when running as `python -m scripts.import_cefrj`.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.session import SessionLocal as async_session_maker  # noqa: E402
from app.models import Language, Word  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("import_cefrj")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
CACHE_PATH = DATA_DIR / "cache_enriched.jsonl"
SRC_CSV = DATA_DIR / "cefrj-1.5.csv"

# POS normalization (CEFR-J uses long forms)
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
    "article": "det",
}

LEMMA_RE_CLEAN = re.compile(r"\s+")


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class WordRow:
    lemma: str
    pos: str | None
    level: str  # A1..C2
    ipa: str | None = None
    translation_ru: str | None = None
    translation_kk: str | None = None
    example: str | None = None
    example_ru: str | None = None
    example_kk: str | None = None
    frequency_rank: int | None = None
    source: str = "cefr-j-1.5"

    @property
    def key(self) -> str:
        return f"{self.lemma}::{self.pos or ''}"

    def as_dict(self) -> dict[str, Any]:
        return asdict(self)


# ---------------------------------------------------------------------------
# Step 1: parse CSV
# ---------------------------------------------------------------------------

def parse_cefrj_csv(csv_path: Path) -> list[WordRow]:
    """Read CEFR-J CSV into WordRow objects, deduped by (lemma, pos)."""
    rows: dict[str, WordRow] = {}
    skipped_multi = 0
    with csv_path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            headword = (raw.get("headword") or "").strip()
            pos_long = (raw.get("pos") or "").strip().lower()
            cefr = (raw.get("CEFR") or "").strip().upper()

            # Skip multi-form entries like "a.m./A.M./am/AM" — keep first form only
            if "/" in headword:
                headword = headword.split("/", 1)[0].strip()

            # Skip things like blank or acronyms
            if not headword or not cefr or cefr not in {"A1", "A2", "B1", "B2", "C1", "C2"}:
                continue

            # Normalize: multi-word phrases allowed, but collapse whitespace
            lemma = LEMMA_RE_CLEAN.sub(" ", headword).strip().lower()
            if not lemma or not re.match(r"^[a-z][a-z\-' ]*$", lemma):
                skipped_multi += 1
                continue

            pos = POS_MAP.get(pos_long, pos_long or None)
            if pos and len(pos) > 20:
                pos = pos[:20]

            key = f"{lemma}::{pos or ''}"
            if key not in rows:
                rows[key] = WordRow(lemma=lemma, pos=pos, level=cefr)
    log.info("Parsed %d unique (lemma,pos) entries (%d skipped)", len(rows), skipped_multi)
    return list(rows.values())


# ---------------------------------------------------------------------------
# Step 2: IPA enrichment
# ---------------------------------------------------------------------------

def enrich_ipa(rows: list[WordRow]) -> int:
    """Add IPA transcription via eng_to_ipa. Returns count successful."""
    ok = 0
    for r in rows:
        try:
            ipa_str = _ipa.convert(r.lemma)
            # eng_to_ipa marks unknown words with a trailing '*'
            if ipa_str and not ipa_str.endswith("*") and ipa_str != r.lemma:
                # Multi-word: may return 'a b c' — keep as-is
                r.ipa = ipa_str.strip()
                ok += 1
        except Exception as e:  # noqa: BLE001
            log.debug("IPA failed for %s: %s", r.lemma, e)
    log.info("IPA filled: %d / %d (%.1f%%)", ok, len(rows), 100 * ok / max(1, len(rows)))
    return ok


# ---------------------------------------------------------------------------
# Step 3 + 4: translation pipelines
# ---------------------------------------------------------------------------

class LibreTranslateClient:
    def __init__(self, base_url: str) -> None:
        self._url = base_url.rstrip("/")
        self._client = httpx.AsyncClient(timeout=30.0)

    async def close(self) -> None:
        await self._client.aclose()

    async def translate_batch(self, texts: list[str], target: str) -> list[str]:
        """LibreTranslate supports 'q' as array too."""
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

        # Response can be {translatedText: [...]} (array) or {translatedText: "..."} (single)
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
        self._client = httpx.AsyncClient(timeout=30.0)
        self._url = "https://translate.api.cloud.yandex.net/translate/v2/translate"

    async def close(self) -> None:
        await self._client.aclose()

    async def translate_batch(
        self, texts: list[str], source: str, target: str
    ) -> list[str]:
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


async def translate_all(
    rows: list[WordRow],
    libre_url: str,
    yandex_key: str | None,
    yandex_folder_id: str | None,
    batch_size: int = 50,
    skip_kk: bool = False,
) -> None:
    libre = LibreTranslateClient(libre_url)
    yandex = (
        YandexTranslateClient(yandex_key, yandex_folder_id)
        if yandex_key and yandex_folder_id and not skip_kk
        else None
    )
    try:
        # RU translations (EN -> RU) via LibreTranslate
        todo_ru = [r for r in rows if not r.translation_ru]
        log.info("RU: translating %d lemmas via LibreTranslate", len(todo_ru))
        for i in range(0, len(todo_ru), batch_size):
            batch = todo_ru[i : i + batch_size]
            results = await libre.translate_batch([r.lemma for r in batch], target="ru")
            for r, tr in zip(batch, results, strict=True):
                r.translation_ru = tr.lower() if tr else None
            _write_cache(rows)
            if i % 500 == 0:
                log.info("  RU progress: %d/%d", min(i + batch_size, len(todo_ru)), len(todo_ru))

        # KK translations (EN -> KK) via Yandex
        if yandex is not None:
            todo_kk = [r for r in rows if not r.translation_kk]
            log.info("KK: translating %d lemmas via Yandex", len(todo_kk))
            for i in range(0, len(todo_kk), batch_size):
                batch = todo_kk[i : i + batch_size]
                results = await yandex.translate_batch(
                    [r.lemma for r in batch], source="en", target="kk"
                )
                for r, tr in zip(batch, results, strict=True):
                    r.translation_kk = tr.lower() if tr else None
                _write_cache(rows)
                if i % 500 == 0:
                    log.info("  KK progress: %d/%d", min(i + batch_size, len(todo_kk)), len(todo_kk))
        else:
            log.warning("KK translation skipped (no API key or folder_id, or skip_kk=True)")
    finally:
        await libre.close()
        if yandex is not None:
            await yandex.close()


# ---------------------------------------------------------------------------
# Cache handling (resumable)
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
            # Take cached translations/ipa, overwrite level if changed upstream
            r.ipa = c.ipa or r.ipa
            r.translation_ru = c.translation_ru or r.translation_ru
            r.translation_kk = c.translation_kk or r.translation_kk
        merged.append(r)
    log.info("Cache merged: %d cached entries applied", len(cached))
    return merged


# ---------------------------------------------------------------------------
# Step 5: seed DB
# ---------------------------------------------------------------------------

async def seed_db(rows: list[WordRow], language_code: str = "en") -> int:
    from sqlalchemy.orm import attributes  # noqa: F401  (for type hints via runtime)

    inserted = 0
    skipped = 0
    async with async_session_maker() as db:
        lang = (
            await db.execute(select(Language).where(Language.code == language_code))
        ).scalar_one_or_none()
        if lang is None:
            raise RuntimeError(f"Language '{language_code}' not in DB — run seed_english first")

        # Existing lemmas for this language (to skip)
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

            batch.append(
                {
                    "language_id": lang.id,
                    "topic_id": None,  # auto-imports: unassigned; level filter drives UI
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
                    "frequency_rank": r.frequency_rank,
                }
            )
            existing.add(r.lemma)

            # Flush every 500 to keep mem low
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
            f"  curl -L https://raw.githubusercontent.com/openlanguageprofiles/"
            f"olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv -o {SRC_CSV}"
        )

    # 1. parse
    rows = parse_cefrj_csv(SRC_CSV)

    # merge in any cached progress from previous runs
    rows = merge_cache(rows)

    # 2. IPA
    enrich_ipa(rows)
    _write_cache(rows)

    # 3+4. translations
    yandex_key = os.getenv("YANDEX_TRANSLATE_API_KEY") or settings.yandex_translate_api_key
    yandex_folder = os.getenv("YANDEX_FOLDER_ID") or settings.yandex_folder_id
    skip_kk = os.getenv("SKIP_KK", "").lower() in {"1", "true", "yes"}

    await translate_all(
        rows,
        libre_url=settings.libretranslate_url,
        yandex_key=yandex_key,
        yandex_folder_id=yandex_folder,
        batch_size=int(os.getenv("BATCH_SIZE", "50")),
        skip_kk=skip_kk,
    )
    _write_cache(rows)

    # 5. seed DB
    inserted = await seed_db(rows, language_code="en")
    log.info("Done. %d words added to DB (cache: %s).", inserted, CACHE_PATH)


if __name__ == "__main__":
    asyncio.run(main())
