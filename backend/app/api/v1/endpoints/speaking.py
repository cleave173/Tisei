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


def _normalize(text: str) -> str:
    """Lowercase, strip punctuation, collapse whitespace."""
    text = text.lower().strip()
    text = _PUNCT_RE.sub(" ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


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
    t = _normalize(target)
    r = _normalize(recognized)
    if not t:
        return 0
    if not r:
        return 0
    dist = _levenshtein(t, r)
    longest = max(len(t), len(r))
    ratio = 1.0 - dist / longest
    return max(0, min(100, round(ratio * 100)))


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
        recognized_normalized=_normalize(payload.recognized_text),
        feedback=feedback,
    )
