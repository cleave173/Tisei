"""Email delivery service.

Supports two backends controlled by the EMAIL_BACKEND env variable:
  - ``console``  (default) – prints the email to stdout; zero external deps.
  - ``smtp``     – sends via SMTP using aiosmtplib.
  - ``resend``   – sends via Resend HTTP API; avoids blocked SMTP ports.
  - ``gmail_api`` – sends through Gmail REST API; avoids blocked SMTP ports.

Set credentials in .env:
    EMAIL_BACKEND=smtp
    SMTP_HOST=smtp.gmail.com
    SMTP_PORT=587
    SMTP_USER=you@gmail.com
    SMTP_PASSWORD=app-specific-password
    SMTP_FROM=noreply@tisei.app
    SMTP_TLS=true          # use STARTTLS (port 587); set false for port 465 SSL

    # Or:
    EMAIL_BACKEND=resend
    RESEND_API_KEY=re_...
    SMTP_FROM=Tisei <noreply@your-verified-domain.com>
"""
from __future__ import annotations

import base64
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings

log = logging.getLogger(__name__)


async def send_reset_code(to_email: str, code: str) -> None:
    """Send the 6-digit password-reset OTP to *to_email*."""
    subject = "Your Tisei password reset code"
    html_body = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:auto;padding:32px">
      <h2 style="color:#1A237E">Password Reset</h2>
      <p>Use the code below to reset your Tisei password.
         It expires in <strong>15 minutes</strong>.</p>
      <div style="font-size:40px;font-weight:700;letter-spacing:12px;
                  color:#1A237E;padding:16px 0">{code}</div>
      <p style="color:#757575;font-size:13px">
        If you didn't request a password reset, ignore this email.
      </p>
    </div>
    """
    text_body = f"Your Tisei password reset code: {code}\nExpires in 15 minutes."

    if settings.email_backend == "smtp":
        await _send_smtp(to_email, subject, html_body, text_body)
    elif settings.email_backend == "resend":
        await _send_resend(to_email, subject, html_body, text_body)
    elif settings.email_backend == "gmail_api":
        await _send_gmail_api(to_email, subject, html_body, text_body)
    else:
        _console(to_email, subject, code)


# ── Backends ──────────────────────────────────────────────────────────────────

async def _send_smtp(to: str, subject: str, html: str, text: str) -> None:
    import aiosmtplib

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to
    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=settings.smtp_user,
            password=settings.smtp_password,
            start_tls=settings.smtp_tls,
            timeout=settings.smtp_timeout_seconds,
        )
        log.info("Reset code email sent to %s", to)
    except Exception as exc:
        log.error("Failed to send email to %s: %s", to, exc)
        raise


async def _send_resend(to: str, subject: str, html: str, text: str) -> None:
    import httpx

    if not settings.resend_api_key:
        raise RuntimeError("RESEND_API_KEY is required for EMAIL_BACKEND=resend")

    payload = {
        "from": settings.smtp_from,
        "to": [to],
        "subject": subject,
        "html": html,
        "text": text,
    }
    async with httpx.AsyncClient(timeout=settings.smtp_timeout_seconds) as client:
        response = await client.post(
            "https://api.resend.com/emails",
            headers={
                "Authorization": f"Bearer {settings.resend_api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
    if response.status_code >= 400:
        log.error("Resend email failed for %s: %s", to, response.text)
        response.raise_for_status()
    log.info("Reset code email sent to %s via Resend", to)


async def _send_gmail_api(to: str, subject: str, html: str, text: str) -> None:
    import httpx

    client_id = _clean_env(settings.gmail_client_id)
    client_secret = _clean_env(settings.gmail_client_secret)
    refresh_token = _clean_env(settings.gmail_refresh_token)
    missing = [
        name
        for name, value in {
            "GMAIL_CLIENT_ID": client_id,
            "GMAIL_CLIENT_SECRET": client_secret,
            "GMAIL_REFRESH_TOKEN": refresh_token,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError(f"{', '.join(missing)} required for EMAIL_BACKEND=gmail_api")

    log.info(
        "Gmail API config: client_id=%s client_secret=%s refresh_token=%s from=%s",
        _mask_credential(client_id),
        _mask_credential(client_secret),
        _mask_credential(refresh_token),
        settings.gmail_from or settings.smtp_from or settings.smtp_user,
    )

    async with httpx.AsyncClient(timeout=settings.smtp_timeout_seconds) as client:
        token_response = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "client_id": client_id,
                "client_secret": client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
        )
        if token_response.status_code >= 400:
            log.error("Gmail token refresh failed: %s", token_response.text)
            token_response.raise_for_status()

        access_token = token_response.json()["access_token"]

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = settings.gmail_from or settings.smtp_from or settings.smtp_user
        msg["To"] = to
        msg.attach(MIMEText(text, "plain"))
        msg.attach(MIMEText(html, "html"))

        raw = base64.urlsafe_b64encode(msg.as_bytes()).decode().rstrip("=")
        send_response = await client.post(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
            json={"raw": raw},
        )
    if send_response.status_code >= 400:
        log.error("Gmail API email failed for %s: %s", to, send_response.text)
        send_response.raise_for_status()
    log.info("Reset code email sent to %s via Gmail API", to)


def _console(to: str, subject: str, code: str) -> None:
    print(
        f"\n{'='*60}\n"
        f"[EMAIL CONSOLE BACKEND]\n"
        f"To: {to}\n"
        f"Subject: {subject}\n"
        f"Reset code: {code}\n"
        f"{'='*60}\n"
    )


def _clean_env(value: str | None) -> str:
    return (value or "").strip()


def _mask_credential(value: str) -> str:
    if not value:
        return "<empty>"
    if len(value) <= 12:
        return f"<len={len(value)}>"
    return f"{value[:6]}...{value[-6:]} len={len(value)}"
