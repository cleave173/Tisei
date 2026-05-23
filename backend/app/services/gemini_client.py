"""Thin async client for Google Gemini's generateContent endpoint.

We use the REST API directly (no extra SDK dep). The model is asked to return
strict JSON; we validate / coerce the result on the Python side.
"""
from __future__ import annotations

import json
import logging
import re
from typing import Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_API_BASE = "https://generativelanguage.googleapis.com/v1beta/models"


class GeminiError(RuntimeError):
    """Raised when Gemini is unavailable or returns an unparseable response."""


async def generate_json(
    *,
    prompt: str,
    system: str | None = None,
    temperature: float = 0.7,
    max_output_tokens: int = 2048,
    timeout_s: float = 30.0,
) -> Any:
    """Call Gemini and return parsed JSON. Raises GeminiError on any failure.

    The model is instructed via `responseMimeType=application/json` to emit
    JSON directly; we still fall back to extracting a ```json``` code block
    or the first {...} / [...] in the text just in case.
    """
    if not settings.gemini_api_key:
        raise GeminiError("GEMINI_API_KEY is not configured on the server")

    url = (
        f"{_API_BASE}/{settings.gemini_model}:generateContent"
        f"?key={settings.gemini_api_key}"
    )

    contents: list[dict[str, Any]] = []
    if system:
        # Gemini doesn't have a system role; prepend system instructions
        # as the first user turn (the dominant convention).
        contents.append({"role": "user", "parts": [{"text": system}]})
        contents.append(
            {"role": "model", "parts": [{"text": "Understood. I'll follow these rules."}]}
        )
    contents.append({"role": "user", "parts": [{"text": prompt}]})

    body: dict[str, Any] = {
        "contents": contents,
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_output_tokens,
            "responseMimeType": "application/json",
        },
    }

    try:
        async with httpx.AsyncClient(timeout=timeout_s) as client:
            r = await client.post(url, json=body)
            r.raise_for_status()
            data = r.json()
    except httpx.HTTPStatusError as exc:
        logger.warning("Gemini HTTP %s: %s", exc.response.status_code, exc.response.text[:500])
        raise GeminiError(f"Gemini HTTP {exc.response.status_code}") from exc
    except httpx.HTTPError as exc:
        raise GeminiError(f"Gemini request failed: {exc}") from exc

    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise GeminiError("Gemini returned an unexpected response shape") from exc

    return _extract_json(text)


def _extract_json(text: str) -> Any:
    """Robustly parse JSON from a model response."""
    s = text.strip()
    # Direct parse first (responseMimeType=application/json case).
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        pass

    # Try a fenced code block.
    m = re.search(r"```(?:json)?\s*([\s\S]+?)```", s)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass

    # Last resort: grab the first {...} or [...] balanced span.
    for opener, closer in (("{", "}"), ("[", "]")):
        i = s.find(opener)
        j = s.rfind(closer)
        if i != -1 and j > i:
            try:
                return json.loads(s[i : j + 1])
            except json.JSONDecodeError:
                continue

    raise GeminiError("Failed to parse JSON from Gemini response")
