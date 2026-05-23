"""Bulk-assign existing topic_id to enriched cached words via Gemini.

Reads the enriched caches produced by `import_cefrj.py` and
`import_oxford5000.py`, asks Gemini-Flash to pick the best matching topic
slug from `topics.json` for each word (within the word's CEFR level), and
writes the result to `data/cache_topic_assignments.jsonl` (resumable).

Run:
    docker compose -f infra/docker-compose.yml exec backend \
        python -m scripts.assign_topics_via_gemini

The script:
  - Skips words already assigned (resumable)
  - Picks topic only from topics that match the word's level (so we don't
    put a B2 word into an A1 topic)
  - Falls back to `null` (= unassigned) if Gemini can't decide
  - Batches 50 words per request to stay well under Gemini's free quota
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys
from collections import defaultdict
from pathlib import Path

ERROR_SENTINEL = "__error__"  # marks a batch that failed (will be retried)
BATCH_SLEEP_S = 4.5            # ~13 req/min, well under the 15 RPM free quota

# Make app imports work when running as `python -m scripts.assign_topics_via_gemini`.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.gemini_client import GeminiError, generate_json  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("assign_topics")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
SEEDS_DIR = SCRIPT_DIR.parent / "app" / "seeds"
ENRICHED_CACHES = [
    DATA_DIR / "cache_enriched.jsonl",
    DATA_DIR / "cache_oxford5000.jsonl",
]
ASSIGN_CACHE = DATA_DIR / "cache_topic_assignments.jsonl"

BATCH_SIZE = 50
MAX_RETRIES_PER_BATCH = 3


def _load_topics_by_level() -> dict[str, list[dict]]:
    raw = json.loads((SEEDS_DIR / "topics.json").read_text(encoding="utf-8"))
    by_level: dict[str, list[dict]] = defaultdict(list)
    for t in raw:
        by_level[t.get("level", "A1")].append(
            {"slug": t["slug"], "title": t["title"]}
        )
    return by_level


def _load_enriched() -> list[dict]:
    """Merge all enriched caches; dedupe by lemma (first occurrence wins)."""
    seen: set[str] = set()
    out: list[dict] = []
    for path in ENRICHED_CACHES:
        if not path.exists():
            log.warning("Enriched cache missing: %s", path)
            continue
        with path.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                w = json.loads(line)
                lemma = w.get("lemma")
                if not lemma or lemma in seen:
                    continue
                seen.add(lemma)
                out.append(w)
    return out


def _load_assignments() -> dict[str, str | None]:
    """Read existing assignments cache: {lemma: topic_slug | None}.

    Rows previously written with topic == ERROR_SENTINEL are treated as
    *not assigned* so they get retried on the next run.
    """
    out: dict[str, str | None] = {}
    if not ASSIGN_CACHE.exists():
        return out
    with ASSIGN_CACHE.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            topic = row.get("topic")
            if topic == ERROR_SENTINEL:
                # leave it out of `out` so it gets retried
                continue
            out[row["lemma"]] = topic
    return out


def _append_assignments(rows: list[dict]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with ASSIGN_CACHE.open("a", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


_SYSTEM_PROMPT = """\
You are a vocabulary classifier for a CEFR-aligned language-learning app.

For every input word you must pick the single best-matching topic slug from
the provided list, or return null if none of them fit. Use the literal slug
strings — do not invent new topics.

Output strict JSON: a list of objects with keys "lemma" (string) and "topic"
(string slug or null), preserving the input order.
"""


async def _classify_batch(
    words: list[dict], topics: list[dict], level: str
) -> tuple[dict[str, str | None], bool]:
    """Ask Gemini to map each lemma in `words` to one of `topics` (or null).

    Returns ``(mapping, ok)``. When ``ok`` is False the call failed (e.g. 429)
    and the caller should mark these lemmas with ``ERROR_SENTINEL`` so a future
    run retries them.
    """
    topic_block = "\n".join(f"- {t['slug']}: {t['title']}" for t in topics)
    word_block = "\n".join(
        f"- {w['lemma']}"
        + (f" ({w.get('pos')})" if w.get("pos") else "")
        + (f" — RU: {w['translation_ru']}" if w.get("translation_ru") else "")
        for w in words
    )
    prompt = (
        f"CEFR level: {level}\n\n"
        f"Available topics for this level (use these slugs verbatim or null):\n"
        f"{topic_block}\n\n"
        f"Classify each word into the best matching topic. If no topic fits, "
        f"return null for that word.\n\n"
        f"Words:\n{word_block}\n\n"
        f"Respond with a JSON array like: "
        f'[{{"lemma":"foo","topic":"food"}}, {{"lemma":"bar","topic":null}}, ...]'
    )

    last_exc: GeminiError | None = None
    for attempt in range(1, MAX_RETRIES_PER_BATCH + 1):
        try:
            data = await generate_json(
                prompt=prompt,
                system=_SYSTEM_PROMPT,
                temperature=0.2,
                max_output_tokens=4096,
            )
            break
        except GeminiError as exc:
            last_exc = exc
            log.warning("Gemini batch attempt %d/%d failed: %s", attempt, MAX_RETRIES_PER_BATCH, exc)
            if attempt < MAX_RETRIES_PER_BATCH:
                await asyncio.sleep(BATCH_SLEEP_S * attempt)
    else:
        return {w["lemma"]: None for w in words}, False

    valid_slugs = {t["slug"] for t in topics}
    result: dict[str, str | None] = {}
    if isinstance(data, list):
        for row in data:
            if not isinstance(row, dict):
                continue
            lemma = row.get("lemma")
            topic = row.get("topic")
            if not isinstance(lemma, str):
                continue
            if topic is not None and topic not in valid_slugs:
                topic = None
            result[lemma] = topic
    # Default any missing lemmas to None
    for w in words:
        result.setdefault(w["lemma"], None)
    return result, True


async def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    topics_by_level = _load_topics_by_level()
    if not topics_by_level:
        raise SystemExit("topics.json is empty — aborting")
    log.info(
        "Loaded topics per level: %s",
        {lv: len(ts) for lv, ts in topics_by_level.items()},
    )

    enriched = _load_enriched()
    log.info("Loaded %d enriched words from caches", len(enriched))

    already = _load_assignments()
    log.info("Already assigned in cache: %d", len(already))

    todo = [w for w in enriched if w["lemma"] not in already]
    log.info("To classify: %d words", len(todo))

    # Bucket by level so each prompt only offers the topics for that level
    by_level: dict[str, list[dict]] = defaultdict(list)
    for w in todo:
        lvl = (w.get("level") or "A1").upper()
        by_level[lvl].append(w)

    total_done = 0
    for level, words in sorted(by_level.items()):
        topics = topics_by_level.get(level, [])
        if not topics:
            log.warning("No topics for level %s — marking %d words null", level, len(words))
            _append_assignments(
                [{"lemma": w["lemma"], "level": level, "topic": None} for w in words]
            )
            total_done += len(words)
            continue

        log.info("Level %s: %d words across %d topics", level, len(words), len(topics))
        n_batches = -(-len(words) // BATCH_SIZE)
        for i in range(0, len(words), BATCH_SIZE):
            batch = words[i : i + BATCH_SIZE]
            mapping, ok = await _classify_batch(batch, topics, level)
            if ok:
                rows = [
                    {"lemma": w["lemma"], "level": level, "topic": mapping.get(w["lemma"])}
                    for w in batch
                ]
            else:
                # mark with ERROR_SENTINEL so a re-run will retry these
                rows = [
                    {"lemma": w["lemma"], "level": level, "topic": ERROR_SENTINEL}
                    for w in batch
                ]
            _append_assignments(rows)
            total_done += len(rows)
            assigned = sum(1 for r in rows if r["topic"] and r["topic"] != ERROR_SENTINEL)
            log.info(
                "  batch %d/%d → %d/%d assigned%s (cumulative done: %d)",
                i // BATCH_SIZE + 1,
                n_batches,
                assigned,
                len(rows),
                "" if ok else " [ERROR — will retry next run]",
                total_done,
            )
            # rate-limit pacing: stay below 15 RPM free tier
            if i + BATCH_SIZE < len(words):
                await asyncio.sleep(BATCH_SLEEP_S)

    log.info("Finished. Total newly classified: %d", total_done)


if __name__ == "__main__":
    asyncio.run(main())
