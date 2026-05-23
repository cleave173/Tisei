"""Re-classify null lemmas with a permissive 'must pick a topic' prompt.

The first pass via `assign_topics_via_gemini.py` allowed Gemini to return
null when no topic fit. Many of those nulls are salvageable — Gemini was
just being conservative. This script re-asks with a stricter instruction
that forbids null answers, so every word ends up in *some* topic.

Run:
    docker compose -f infra/docker-compose.yml exec backend \
        python -m scripts.reclassify_nulls
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.gemini_client import GeminiError, generate_json  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("reclassify")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
SEEDS_DIR = SCRIPT_DIR.parent / "app" / "seeds"
ASSIGN_CACHE = DATA_DIR / "cache_topic_assignments.jsonl"
ENRICHED_CACHES = [
    DATA_DIR / "cache_enriched.jsonl",
    DATA_DIR / "cache_oxford5000.jsonl",
    DATA_DIR / "cache_c2_generated.jsonl",
]

BATCH_SIZE = 50
BATCH_SLEEP_S = 4.5
MAX_RETRIES = 3


def _load_topics_by_level() -> dict[str, list[dict]]:
    raw = json.loads((SEEDS_DIR / "topics.json").read_text(encoding="utf-8"))
    by_level: dict[str, list[dict]] = defaultdict(list)
    for t in raw:
        by_level[t.get("level", "A1")].append({"slug": t["slug"], "title": t["title"]})
    return by_level


def _load_enriched() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for path in ENRICHED_CACHES:
        if not path.exists():
            continue
        with path.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                w = json.loads(line)
                if w.get("lemma"):
                    out[w["lemma"]] = w
    return out


def _load_assignments() -> list[dict]:
    rows: list[dict] = []
    if not ASSIGN_CACHE.exists():
        return rows
    with ASSIGN_CACHE.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    # Dedupe by lemma, last wins
    by_lemma: dict[str, dict] = {}
    for r in rows:
        by_lemma[r["lemma"]] = r
    return list(by_lemma.values())


def _write_assignments(rows: list[dict]) -> None:
    with ASSIGN_CACHE.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


_SYSTEM = """\
You are a vocabulary classifier. For every input word, you MUST pick the
closest matching topic slug from the provided list. Null is NOT allowed —
if a word is abstract or generic, pick the topic where a learner would
most plausibly encounter it. Use slug strings verbatim.

Return strict JSON: a list of {"lemma": "...", "topic": "..."} objects.
"""


async def _classify(words: list[dict], topics: list[dict], level: str) -> dict[str, str | None]:
    topic_block = "\n".join(f"- {t['slug']}: {t['title']}" for t in topics)
    word_block = "\n".join(
        f"- {w['lemma']}"
        + (f" ({w.get('pos')})" if w.get("pos") else "")
        + (f" — RU: {w['translation_ru']}" if w.get("translation_ru") else "")
        for w in words
    )
    prompt = (
        f"CEFR level: {level}\n\n"
        f"Topics (pick one slug per word, never null):\n{topic_block}\n\n"
        f"Words:\n{word_block}\n\n"
        f'Respond with a JSON array: [{{"lemma":"foo","topic":"food"}}, ...]'
    )
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            data = await generate_json(
                prompt=prompt, system=_SYSTEM, temperature=0.3, max_output_tokens=4096
            )
            break
        except GeminiError as exc:
            log.warning("attempt %d/%d failed: %s", attempt, MAX_RETRIES, exc)
            if attempt < MAX_RETRIES:
                await asyncio.sleep(BATCH_SLEEP_S * attempt)
    else:
        return {}

    valid = {t["slug"] for t in topics}
    out: dict[str, str | None] = {}
    if isinstance(data, list):
        for r in data:
            if isinstance(r, dict):
                lemma = r.get("lemma")
                topic = r.get("topic")
                if isinstance(lemma, str) and topic in valid:
                    out[lemma] = topic
    return out


async def main() -> None:
    topics_by_level = _load_topics_by_level()
    enriched = _load_enriched()
    rows = _load_assignments()

    nulls = [r for r in rows if r["topic"] is None]
    log.info("Null lemmas to reclassify: %d", len(nulls))

    by_level: dict[str, list[dict]] = defaultdict(list)
    for r in nulls:
        w = enriched.get(r["lemma"])
        if w is None:
            continue
        by_level[r["level"]].append({**w, "lemma": r["lemma"]})

    updates: dict[str, str] = {}
    for level, words in sorted(by_level.items()):
        topics = topics_by_level.get(level, [])
        if not topics:
            continue
        log.info("Level %s: %d words", level, len(words))
        n_batches = -(-len(words) // BATCH_SIZE)
        for i in range(0, len(words), BATCH_SIZE):
            batch = words[i : i + BATCH_SIZE]
            mapping = await _classify(batch, topics, level)
            updates.update(mapping)
            log.info(
                "  batch %d/%d → %d/%d reclassified (cumulative: %d)",
                i // BATCH_SIZE + 1, n_batches, len(mapping), len(batch), len(updates),
            )
            if i + BATCH_SIZE < len(words):
                await asyncio.sleep(BATCH_SLEEP_S)

    # Merge back
    changed = 0
    for r in rows:
        if r["topic"] is None and r["lemma"] in updates:
            r["topic"] = updates[r["lemma"]]
            changed += 1

    _write_assignments(rows)
    log.info("Updated %d lemmas (was null → now has topic).", changed)


if __name__ == "__main__":
    asyncio.run(main())
