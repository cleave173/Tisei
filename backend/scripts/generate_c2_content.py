"""Generate C2-level vocabulary (idioms + literature) via Gemini.

CEFR-J only covers A1..B2 and Oxford 5000 covers up to C1. Our C2 topics
(`idioms`, `literature`) are nearly empty. This script asks Gemini-Flash
to produce a curated list of advanced vocabulary for each topic with full
translations (RU + KK), an example sentence and IPA-ish transcription.

Output is appended to:
  - data/cache_c2_generated.jsonl       (enriched word records)
  - data/cache_topic_assignments.jsonl  (lemma -> topic slug)

Run:
    docker compose -f infra/docker-compose.yml exec backend \
        python -m scripts.generate_c2_content
"""
from __future__ import annotations

import asyncio
import json
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.gemini_client import GeminiError, generate_json  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("gen_c2")

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_DIR = SCRIPT_DIR / "data"
ENRICHED_OUT = DATA_DIR / "cache_c2_generated.jsonl"
ASSIGN_CACHE = DATA_DIR / "cache_topic_assignments.jsonl"

BATCH_SLEEP_S = 4.5
TARGET_PER_TOPIC = 120
WORDS_PER_REQUEST = 30  # Gemini handles ~30 enriched entries reliably

C2_TOPICS = [
    {
        "slug": "idioms",
        "title": "Idioms",
        "guidance": (
            "Authentic English idioms and fixed expressions used by educated native speakers. "
            "Examples: 'bite the bullet', 'a blessing in disguise', 'cut corners'. "
            "Each entry is the idiom itself (lowercase, multi-word allowed). "
            "Avoid clichés overlapping with B2/C1 lists."
        ),
    },
    {
        "slug": "literature",
        "title": "Literature & advanced vocabulary",
        "guidance": (
            "C2-level vocabulary common in English literature, journalism and academic prose. "
            "Examples: 'ineffable', 'sycophant', 'quintessential', 'palpable'. "
            "Single lemmas only (no phrases). "
            "Choose words that an advanced learner would meet in novels or quality press."
        ),
    },
]

_SYSTEM = """\
You are an expert lexicographer producing CEFR-aligned learning content.

Return strict JSON: a list of objects with these keys (all required):
  - lemma           (string, lowercase canonical form)
  - pos             (string: "noun" | "verb" | "adjective" | "adverb" | "phrase" | "idiom")
  - ipa             (string, IPA transcription without slashes; "" if a multi-word phrase)
  - translation_ru  (string, natural Russian translation)
  - translation_kk  (string, natural Kazakh translation)
  - example         (string, one short English sentence using the lemma)
  - example_ru      (string, Russian translation of the example)
  - example_kk      (string, Kazakh translation of the example)

No commentary, no markdown — just the JSON array.
"""


async def _generate_batch(topic: dict, n: int, exclude: set[str]) -> list[dict]:
    avoid = ""
    if exclude:
        sample = ", ".join(sorted(exclude)[:60])
        avoid = f"\n\nDo NOT repeat any of these already-collected lemmas: {sample}"

    prompt = (
        f"Generate {n} CEFR C2-level entries for the topic \"{topic['title']}\".\n\n"
        f"Topic guidance: {topic['guidance']}{avoid}\n\n"
        f"Return a JSON array of {n} objects following the system schema."
    )
    try:
        data = await generate_json(
            prompt=prompt,
            system=_SYSTEM,
            temperature=0.7,
            max_output_tokens=8192,
            timeout_s=60.0,
        )
    except GeminiError as exc:
        log.warning("Gemini failed: %s", exc)
        return []

    if not isinstance(data, list):
        log.warning("Gemini returned non-list payload, skipping")
        return []

    out: list[dict] = []
    required = {"lemma", "pos", "translation_ru", "translation_kk", "example"}
    for r in data:
        if not isinstance(r, dict):
            continue
        if not required.issubset(r):
            continue
        lemma = str(r["lemma"]).strip().lower()
        if not lemma or lemma in exclude:
            continue
        out.append({
            "lemma": lemma,
            "pos": r.get("pos") or "",
            "level": "C2",
            "ipa": r.get("ipa") or "",
            "translation_ru": r.get("translation_ru") or "",
            "translation_kk": r.get("translation_kk") or "",
            "example": r.get("example") or "",
            "example_ru": r.get("example_ru") or "",
            "example_kk": r.get("example_kk") or "",
            "frequency_rank": None,
            "source": "gemini-c2",
        })
        exclude.add(lemma)
    return out


def _load_existing_lemmas() -> set[str]:
    """All lemmas we should not duplicate (from prior caches)."""
    seen: set[str] = set()
    for name in ("cache_enriched.jsonl", "cache_oxford5000.jsonl", "cache_c2_generated.jsonl"):
        p = DATA_DIR / name
        if not p.exists():
            continue
        with p.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    seen.add(json.loads(line)["lemma"].lower())
                except (KeyError, json.JSONDecodeError):
                    pass
    return seen


def _append_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


async def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    exclude = _load_existing_lemmas()
    log.info("Already-known lemmas (will be skipped): %d", len(exclude))

    grand_total = 0
    for topic in C2_TOPICS:
        log.info("=== %s — target %d words ===", topic["slug"], TARGET_PER_TOPIC)
        topic_lemmas: list[str] = []
        # Local exclude tracks only THIS topic's lemmas in addition to the global set
        topic_exclude = set(exclude)
        attempts = 0
        while len(topic_lemmas) < TARGET_PER_TOPIC and attempts < 8:
            attempts += 1
            n = min(WORDS_PER_REQUEST, TARGET_PER_TOPIC - len(topic_lemmas))
            log.info("  attempt %d: requesting %d words", attempts, n)
            batch = await _generate_batch(topic, n, topic_exclude)
            if not batch:
                log.warning("  empty batch — sleeping and retrying")
                await asyncio.sleep(BATCH_SLEEP_S)
                continue
            _append_jsonl(ENRICHED_OUT, batch)
            _append_jsonl(
                ASSIGN_CACHE,
                [{"lemma": w["lemma"], "level": "C2", "topic": topic["slug"]} for w in batch],
            )
            topic_lemmas.extend(w["lemma"] for w in batch)
            log.info("  +%d (topic total: %d)", len(batch), len(topic_lemmas))
            await asyncio.sleep(BATCH_SLEEP_S)
        # Update global set so the next topic doesn't repeat
        exclude.update(topic_lemmas)
        grand_total += len(topic_lemmas)
        log.info("=== %s done: %d words ===", topic["slug"], len(topic_lemmas))

    log.info("Finished. Generated %d C2 words total.", grand_total)


if __name__ == "__main__":
    asyncio.run(main())
