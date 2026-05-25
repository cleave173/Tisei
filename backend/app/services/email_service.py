"""Email delivery service.

Supports two backends controlled by the EMAIL_BACKEND env variable:
  - ``console``  (default) – prints the email to stdout; zero external deps.
  - ``smtp``     – sends via SMTP using aiosmtplib.

Set credentials in .env:
    EMAIL_BACKEND=smtp
    SMTP_HOST=smtp.gmail.com
    SMTP_PORT=587
    SMTP_USER=you@gmail.com
    SMTP_PASSWORD=app-specific-password
    SMTP_FROM=noreply@tisei.app
    SMTP_TLS=true          # use STARTTLS (port 587); set false for port 465 SSL
"""
from __future__ import annotations

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
        )
        log.info("Reset code email sent to %s", to)
    except Exception as exc:
        log.error("Failed to send email to %s: %s", to, exc)
        raise


def _console(to: str, subject: str, code: str) -> None:
    print(
        f"\n{'='*60}\n"
        f"[EMAIL CONSOLE BACKEND]\n"
        f"To: {to}\n"
        f"Subject: {subject}\n"
        f"Reset code: {code}\n"
        f"{'='*60}\n"
    )
