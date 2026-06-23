"""Speaking pronunciation evaluation.

MVP: client uses on-device STT (`speech_to_text`) to convert the user's speech
to text and POSTs both the target phrase and the recognized text. We score the
match using Levenshtein similarity normalized to 0..100. Pass threshold = 80.

Roadmap: when budget allows, swap `_score_text` with a call to Azure
Pronunciation Assessment (https://learn.microsoft.com/azure/ai-services/speech-service/how-to-pronunciation-assessment),
which returns phoneme-level scoring + accent feedback. The endpoint contract
stays identical, so the Flutter app does not change.
"""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.api.deps import get_current_user
from app.models import User

router = APIRouter()


# ---------------------------------------------------------------------------
# Pure scoring helpers
# ---------------------------------------------------------------------------

_PUNCT_RE = re.compile(r"[^\w\s']", flags=re.UNICODE)
_NUMBER_WORDS_0_TO_19 = {
    0: "zero",
    1: "one",
    2: "two",
    3: "three",
    4: "four",
    5: "five",
    6: "six",
    7: "seven",
    8: "eight",
    9: "nine",
    10: "ten",
    11: "eleven",
    12: "twelve",
    13: "thirteen",
    14: "fourteen",
    15: "fifteen",
    16: "sixteen",
    17: "seventeen",
    18: "eighteen",
    19: "nineteen",
}
_NUMBER_WORDS_TENS = {
    20: "twenty",
    30: "thirty",
    40: "forty",
    50: "fifty",
    60: "sixty",
    70: "seventy",
    80: "eighty",
    90: "ninety",
}
_HOMOPHONE_GROUPS = (
    ("eye", "i", "aye"),
    ("ear", "year"),
    ("see", "sea"),
    ("hear", "here"),
    ("to", "too", "two"),
    ("for", "four"),
    ("one", "won"),
    ("be", "bee"),
    ("by", "buy", "bye"),
    ("no", "know"),
    ("right", "write"),
    ("new", "knew"),
    ("son", "sun"),
    ("red", "read"),
    ("blue", "blew"),
    ("pair", "pear"),
    ("there", "their", "they're"),
)
_HOMOPHONE_CANONICAL = {
    variant: group[0]
    for group in _HOMOPHONE_GROUPS
    for variant in group
}


def _number_to_words(value: int) -> str:
    """Convert common STT digit output into English words for scoring."""
    if value < 20:
        return _NUMBER_WORDS_0_TO_19[value]
    if value < 100:
        tens = value // 10 * 10
        ones = value % 10
        if ones == 0:
            return _NUMBER_WORDS_TENS[tens]
        return f"{_NUMBER_WORDS_TENS[tens]} {_NUMBER_WORDS_0_TO_19[ones]}"
    if value < 1000:
        hundreds = value // 100
        rest = value % 100
        prefix = f"{_NUMBER_WORDS_0_TO_19[hundreds]} hundred"
        return prefix if rest == 0 else f"{prefix} {_number_to_words(rest)}"
    return str(value)


def _expand_digits(text: str) -> str:
    return re.sub(
        r"\b\d{1,3}\b",
        lambda m: _number_to_words(int(m.group(0))),
        text,
    )


def _normalize(text: str) -> str:
    """Lowercase, strip punctuation, collapse whitespace."""
    text = text.lower().strip()
    text = _expand_digits(text)
    text = _PUNCT_RE.sub(" ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _tokens(text: str) -> list[str]:
    return _normalize(text).split()


def _canonical_token(token: str) -> str:
    return _HOMOPHONE_CANONICAL.get(token, token)


def _canonical_text(text: str) -> str:
    return " ".join(_canonical_token(token) for token in _tokens(text))


def _levenshtein(a: str, b: str) -> int:
    """Iterative DP Levenshtein — small inputs, no external deps."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i] + [0] * len(b)
        for j, cb in enumerate(b, 1):
            cost = 0 if ca == cb else 1
            cur[j] = min(
                cur[j - 1] + 1,        # insertion
                prev[j] + 1,           # deletion
                prev[j - 1] + cost,    # substitution
            )
        prev = cur
    return prev[-1]


def _score_text(target: str, recognized: str) -> int:
    """Return 0..100 similarity score."""
    target_tokens = _tokens(target)
    recognized_tokens = _tokens(recognized)
    if not target_tokens:
        return 0
    if not recognized_tokens:
        return 0

    target_text = " ".join(_canonical_token(token) for token in target_tokens)
    recognized_text = " ".join(
        _canonical_token(token) for token in recognized_tokens
    )
    candidates = {recognized_text}

    # STT often returns an entire phrase ("it is eye") for a one-word prompt.
    # Score the best same-length window, so the pronounced word can still pass.
    window_size = len(target_tokens)
    if len(recognized_tokens) >= window_size:
        for i in range(len(recognized_tokens) - window_size + 1):
            candidates.add(
                " ".join(
                    _canonical_token(token)
                    for token in recognized_tokens[i : i + window_size]
                )
            )

    best = 0
    for candidate in candidates:
        dist = _levenshtein(target_text, candidate)
        longest = max(len(target_text), len(candidate))
        if longest == 0:
            continue
        ratio = 1.0 - dist / longest
        best = max(best, round(ratio * 100))
    return max(0, min(100, best))


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class EvaluateIn(BaseModel):
    target_text: str = Field(min_length=1, max_length=500)
    recognized_text: str = Field(default="", max_length=500)
    locale: str = Field(default="en-US", max_length=10)


class EvaluateOut(BaseModel):
    score: int = Field(ge=0, le=100)
    accuracy_score: int = Field(ge=0, le=100)
    fluency_score: int | None = None
    is_pass: bool
    pass_threshold: int = 80
    target_normalized: str
    recognized_normalized: str
    feedback: str


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------

@router.post("/evaluate", response_model=EvaluateOut)
async def evaluate_pronunciation(
    payload: EvaluateIn,
    current: User = Depends(get_current_user),
) -> EvaluateOut:
    score = _score_text(payload.target_text, payload.recognized_text)
    is_pass = score >= 80

    if not payload.recognized_text.strip():
        feedback = "no_speech_detected"
    elif score >= 95:
        feedback = "excellent"
    elif score >= 80:
        feedback = "good"
    elif score >= 60:
        feedback = "close"
    else:
        feedback = "try_again"

    return EvaluateOut(
        score=score,
        accuracy_score=score,
        fluency_score=None,
        is_pass=is_pass,
        target_normalized=_normalize(payload.target_text),
        recognized_normalized=_canonical_text(payload.recognized_text),
        feedback=feedback,
    )
