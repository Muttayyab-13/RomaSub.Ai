"""
Email Service for RomaSub.AI
Handles sending OTP emails via the Brevo transactional email API.

Pure functions for email operations.
"""

import logging
import requests

from app.config import settings

# Brevo transactional email endpoint (verified against
# https://developers.brevo.com/reference/send-transac-email)
BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"
BREVO_TIMEOUT_SECONDS = 10

logger = logging.getLogger(__name__)


# ============================================================================
# Email Template Functions
# ----------------------------------------------------------------------------
# Professional black-and-white transactional templates. Brand-aligned with
# the Flutter frontend (see FrontEnd/lib/core/constants/app_colors.dart):
#   primary  #000000   text   #111827 / #6B7280 / #9CA3AF
#   surface  #FFFFFF   bg     #F8F9FA   border #E5E7EB
# No emojis. Single H1 with a small uppercase eyebrow label above it.
# ============================================================================

BRAND_NAME = "RomaSub.AI"
BRAND_TAGLINE = "Roman Urdu Caption Generator"
COPYRIGHT_YEAR = 2026


def _render_otp_email(name: str, otp: str, eyebrow: str, heading: str,
                      intro: str, disclaimer: str) -> str:
    """
    Render a transactional OTP email. All variants share the same scaffold
    so visual treatment stays consistent; only the copy varies.

    Args:
        name: Recipient's display name (already trusted — comes from our DB).
        otp: 6-digit one-time code.
        eyebrow: Short uppercase label shown above the heading
                 (e.g. "Password Reset").
        heading: Single H1 line.
        intro: Body paragraph explaining what the code is for.
        disclaimer: Final paragraph for the "didn't request this" case.
    """
    # Header is purely typographic — the brand name + tagline render
    # consistently across every email client without needing image assets
    # or worrying about embedded-image rendering quirks.

    return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{heading}</title>
    <style>
        body {{ margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #F8F9FA; color: #111827; }}
        .wrapper {{ max-width: 560px; margin: 0 auto; padding: 32px 16px; }}
        .card {{ background: #FFFFFF; border: 1px solid #E5E7EB; border-radius: 12px; overflow: hidden; }}
        .header {{ background: #000000; padding: 40px 32px; text-align: center; }}
        .brand-name {{ color: #FFFFFF; font-size: 26px; font-weight: 700; letter-spacing: 0.3px; margin: 0; }}
        .brand-tagline {{ color: #9CA3AF; font-size: 12px; font-weight: 500; letter-spacing: 1.4px; text-transform: uppercase; margin: 10px 0 0 0; }}
        .content {{ padding: 40px 36px 32px; }}
        .eyebrow {{ color: #6B7280; font-size: 11px; font-weight: 600; letter-spacing: 1.6px; text-transform: uppercase; margin: 0 0 12px 0; }}
        .heading {{ color: #111827; font-size: 22px; font-weight: 600; line-height: 1.3; margin: 0 0 24px 0; }}
        .greeting {{ color: #111827; font-size: 15px; line-height: 1.6; margin: 0 0 16px 0; }}
        .body-text {{ color: #374151; font-size: 15px; line-height: 1.6; margin: 0 0 28px 0; }}
        .code-block {{ background: #F3F4F6; border: 1px solid #E5E7EB; border-radius: 8px; padding: 28px 16px; text-align: center; margin: 0 0 12px 0; }}
        .code-value {{ color: #000000; font-family: 'SF Mono', Menlo, Monaco, Consolas, 'Courier New', monospace; font-size: 32px; font-weight: 600; letter-spacing: 10px; line-height: 1; }}
        .code-meta {{ color: #6B7280; font-size: 11px; font-weight: 600; letter-spacing: 1.4px; text-transform: uppercase; text-align: center; margin: 0 0 28px 0; }}
        .divider {{ height: 1px; background: #E5E7EB; border: 0; margin: 28px 0; }}
        .disclaimer {{ color: #6B7280; font-size: 13px; line-height: 1.6; margin: 0; }}
        .footer {{ padding: 24px 32px 28px; text-align: center; border-top: 1px solid #E5E7EB; background: #FAFAFA; }}
        .footer-brand {{ color: #111827; font-size: 13px; font-weight: 600; margin: 0; }}
        .footer-tagline {{ color: #9CA3AF; font-size: 11px; letter-spacing: 0.8px; margin: 4px 0 14px 0; }}
        .footer-meta {{ color: #9CA3AF; font-size: 11px; line-height: 1.6; margin: 0; }}
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="card">
            <div class="header">
                <p class="brand-name">{BRAND_NAME}</p>
                <p class="brand-tagline">{BRAND_TAGLINE}</p>
            </div>
            <div class="content">
                <p class="eyebrow">{eyebrow}</p>
                <h1 class="heading">{heading}</h1>
                <p class="greeting">Hi {name},</p>
                <p class="body-text">{intro}</p>
                <div class="code-block">
                    <div class="code-value">{otp}</div>
                </div>
                <p class="code-meta">Valid for 15 minutes</p>
                <hr class="divider">
                <p class="disclaimer">{disclaimer}</p>
            </div>
            <div class="footer">
                <p class="footer-brand">{BRAND_NAME}</p>
                <p class="footer-tagline">{BRAND_TAGLINE}</p>
                <p class="footer-meta">&copy; {COPYRIGHT_YEAR} {BRAND_NAME}. All rights reserved.<br>This is an automated message. Please do not reply to this email.</p>
            </div>
        </div>
    </div>
</body>
</html>"""


def get_password_reset_template(name: str, otp: str) -> str:
    """Generate the password-reset OTP email."""
    return _render_otp_email(
        name=name,
        otp=otp,
        eyebrow="Password Reset",
        heading="Verification code required",
        intro=(
            "We received a request to reset the password for your "
            f"{BRAND_NAME} account. Use the verification code below to "
            "continue with the password reset."
        ),
        disclaimer=(
            "If you did not request a password reset, you can safely ignore "
            "this email. Your account remains secure and no changes will be "
            "made."
        ),
    )


def get_email_verify_template(name: str, otp: str) -> str:
    """Generate the email-verification OTP email."""
    return _render_otp_email(
        name=name,
        otp=otp,
        eyebrow="Email Verification",
        heading="Confirm your email address",
        intro=(
            f"Welcome to {BRAND_NAME}. To complete your registration and "
            "begin generating Roman Urdu captions for your videos, please "
            "confirm your email address using the verification code below."
        ),
        disclaimer=(
            f"If you did not create a {BRAND_NAME} account, please disregard "
            "this email. No further action is required."
        ),
    )


# ============================================================================
# Email Sending Functions
# ============================================================================

def send_otp_email(to_email: str, to_name: str, otp: str, purpose: str = "password_reset") -> bool:
    """
    Send OTP email to user.

    Args:
        to_email: Recipient email address
        to_name: Recipient name
        otp: The OTP code to send
        purpose: Purpose of OTP ('password_reset' or 'email_verify')

    Returns:
        True if email sent successfully, False otherwise
    """
    try:
        # Check if API key is configured
        if not settings.brevo_api_key:
            logger.warning("Brevo API key not configured. OTP: %s", otp)
            print(f"\n{'='*50}")
            print(f"EMAIL OTP (API not configured)")
            print(f"To: {to_email}")
            print(f"OTP: {otp}")
            print(f"{'='*50}\n")
            return True  # Return True for development/testing

        # Subject and content based on purpose. Plain-text fallback mirrors the
        # HTML copy for clients that don't render HTML or strip it.
        if purpose == "password_reset":
            subject = "Password reset verification code"
            html_content = get_password_reset_template(to_name, otp)
            text_content = (
                f"Hi {to_name},\n\n"
                f"We received a request to reset the password for your "
                f"RomaSub.AI account. Your verification code is:\n\n"
                f"    {otp}\n\n"
                f"This code is valid for 15 minutes.\n\n"
                f"If you did not request a password reset, you can safely "
                f"ignore this email.\n\n"
                f"— RomaSub.AI"
            )
        else:
            subject = "Confirm your RomaSub.AI email address"
            html_content = get_email_verify_template(to_name, otp)
            text_content = (
                f"Hi {to_name},\n\n"
                f"Welcome to RomaSub.AI. Please confirm your email address "
                f"using the verification code below:\n\n"
                f"    {otp}\n\n"
                f"This code is valid for 15 minutes.\n\n"
                f"If you did not create a RomaSub.AI account, please "
                f"disregard this email.\n\n"
                f"— RomaSub.AI"
            )

        # Send via Brevo REST API. camelCase field names are required by Brevo
        # (htmlContent / textContent / messageId).
        response = requests.post(
            BREVO_API_URL,
            headers={
                "api-key": settings.brevo_api_key,
                "content-type": "application/json",
                "accept": "application/json",
            },
            json={
                "sender": {
                    "email": settings.brevo_sender_email,
                    "name": settings.brevo_sender_name,
                },
                "to": [{"email": to_email, "name": to_name}],
                "subject": subject,
                "htmlContent": html_content,
                "textContent": text_content,
            },
            timeout=BREVO_TIMEOUT_SECONDS,
        )

        if response.status_code != 201:
            # Most common cause is unverified sender domain (400) or bad key (401).
            logger.error(
                "Brevo send failed for %s: HTTP %s — %s",
                to_email, response.status_code, response.text,
            )
            print(f"\n{'='*50}")
            print(f"EMAIL SENDING FAILED - OTP for {to_email}: {otp}")
            print(f"Brevo HTTP {response.status_code}: {response.text}")
            print(f"{'='*50}\n")
            return False

        message_id = response.json().get("messageId", "<unknown>")
        logger.info("OTP email sent to %s, messageId: %s", to_email, message_id)
        return True

    except Exception as e:
        logger.error("Failed to send OTP email to %s: %s", to_email, str(e))
        # Print OTP to console for development
        print(f"\n{'='*50}")
        print(f"EMAIL SENDING FAILED - OTP for {to_email}: {otp}")
        print(f"Error: {str(e)}")
        print(f"{'='*50}\n")
        return False
