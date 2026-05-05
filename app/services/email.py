"""
Email Service for RomaSub.AI
Handles sending OTP emails via the Brevo transactional email API.

Pure functions for email operations.
"""

import requests
from app.config import settings
import logging
import base64
import os

# Brevo transactional email endpoint (verified against
# https://developers.brevo.com/reference/send-transac-email)
BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"
BREVO_TIMEOUT_SECONDS = 10

# Setup logging
logger = logging.getLogger(__name__)

# Path to logo file
LOGO_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "FrontEnd", "assets", "images", "logos", "logo.png")


def get_logo_base64() -> str:
    """
    Load logo and convert to base64 string.

    Returns:
        Base64 encoded logo string, or empty string if file not found
    """
    try:
        if os.path.exists(LOGO_PATH):
            with open(LOGO_PATH, "rb") as f:
                logo_data = f.read()
                return base64.b64encode(logo_data).decode('utf-8')
    except Exception as e:
        logger.warning(f"Failed to load logo: {e}")
    return ""


# ============================================================================
# Email Template Functions - Black & White Theme
# ============================================================================

def get_password_reset_template(name: str, otp: str) -> str:
    """
    Generate HTML template for password reset email.

    Args:
        name: Recipient name
        otp: OTP code

    Returns:
        HTML email content
    """
    logo_base64 = get_logo_base64()
    logo_html = f'<img src="data:image/png;base64,{logo_base64}" alt="RomaSub.AI" style="max-width: 180px; height: auto;">' if logo_base64 else '<div style="font-size: 28px; font-weight: bold; color: white;">RomaSub.AI</div>'

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {{ margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f5f5f5; }}
            .wrapper {{ max-width: 600px; margin: 0 auto; padding: 40px 20px; }}
            .card {{ background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }}
            .header {{ background: #000000; padding: 32px; text-align: center; }}
            .content {{ padding: 40px 32px; }}
            .title {{ color: #1a1a1a; font-size: 24px; font-weight: 700; margin: 0 0 12px 0; }}
            .text {{ color: #666; font-size: 15px; line-height: 1.6; margin: 0 0 24px 0; }}
            .otp-container {{ background: #f8f8f8; border: 2px solid #e0e0e0; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0; }}
            .otp-code {{ font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #000000; font-family: monospace; }}
            .expiry {{ display: inline-block; background: #000; color: white; padding: 8px 16px; border-radius: 20px; font-size: 13px; font-weight: 600; margin-top: 16px; }}
            .footer {{ background: #fafafa; padding: 24px 32px; text-align: center; border-top: 1px solid #eee; }}
            .footer-text {{ color: #999; font-size: 12px; margin: 0; }}
            .divider {{ height: 1px; background: #eee; margin: 24px 0; }}
            .security-note {{ background: #f0f0f0; padding: 16px; border-radius: 8px; margin-top: 24px; }}
            .security-text {{ color: #666; font-size: 13px; margin: 0; }}
        </style>
    </head>
    <body>
        <div class="wrapper">
            <div class="card">
                <div class="header">
                    {logo_html}
                </div>
                <div class="content">
                    <h1 class="title">🔐 Password Reset</h1>
                    <p class="text">Hello <strong>{name}</strong>,</p>
                    <p class="text">We received a request to reset your password. Use the verification code below:</p>
                    
                    <div class="otp-container">
                        <div class="otp-code">{otp}</div>
                        <div class="expiry">⏱️ Expires in 15 minutes</div>
                    </div>
                    
                    <div class="security-note">
                        <p class="security-text">🛡️ If you didn't request this reset, please ignore this email. Your account is still secure.</p>
                    </div>
                </div>
                <div class="footer">
                    <p class="footer-text">© 2024 RomaSub.AI — Roman Urdu Captions Generator</p>
                </div>
            </div>
        </div>
    </body>
    </html>
    """


def get_email_verify_template(name: str, otp: str) -> str:
    """
    Generate HTML template for email verification.

    Args:
        name: Recipient name
        otp: OTP code

    Returns:
        HTML email content
    """
    logo_base64 = get_logo_base64()
    logo_html = f'<img src="data:image/png;base64,{logo_base64}" alt="RomaSub.AI" style="max-width: 180px; height: auto;">' if logo_base64 else '<div style="font-size: 28px; font-weight: bold; color: white;">RomaSub.AI</div>'

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {{ margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f5f5f5; }}
            .wrapper {{ max-width: 600px; margin: 0 auto; padding: 40px 20px; }}
            .card {{ background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }}
            .header {{ background: #000000; padding: 32px; text-align: center; }}
            .content {{ padding: 40px 32px; }}
            .title {{ color: #1a1a1a; font-size: 24px; font-weight: 700; margin: 0 0 12px 0; }}
            .text {{ color: #666; font-size: 15px; line-height: 1.6; margin: 0 0 24px 0; }}
            .highlight {{ color: #000; font-weight: 600; }}
            .otp-container {{ background: #f8f8f8; border: 2px solid #e0e0e0; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0; }}
            .otp-code {{ font-size: 36px; font-weight: 800; letter-spacing: 8px; color: #000000; font-family: monospace; }}
            .expiry {{ display: inline-block; background: #000; color: white; padding: 8px 16px; border-radius: 20px; font-size: 13px; font-weight: 600; margin-top: 16px; }}
            .footer {{ background: #fafafa; padding: 24px 32px; text-align: center; border-top: 1px solid #eee; }}
            .footer-text {{ color: #999; font-size: 12px; margin: 0; }}
            .welcome-box {{ background: linear-gradient(135deg, #f8f8f8 0%, #fff 100%); border: 1px solid #e0e0e0; border-radius: 12px; padding: 20px; margin-bottom: 24px; text-align: center; }}
            .welcome-emoji {{ font-size: 48px; margin-bottom: 12px; }}
            .welcome-text {{ color: #333; font-size: 16px; font-weight: 600; margin: 0; }}
        </style>
    </head>
    <body>
        <div class="wrapper">
            <div class="card">
                <div class="header">
                    {logo_html}
                </div>
                <div class="content">
                    <div class="welcome-box">
                        <div class="welcome-emoji">👋</div>
                        <p class="welcome-text">Welcome to RomaSub.AI!</p>
                    </div>
                    
                    <h1 class="title">✉️ Verify Your Email</h1>
                    <p class="text">Hello <strong>{name}</strong>,</p>
                    <p class="text">Thank you for joining <span class="highlight">RomaSub.AI</span>! Please enter the verification code below to activate your account:</p>
                    
                    <div class="otp-container">
                        <div class="otp-code">{otp}</div>
                        <div class="expiry">⏱️ Expires in 15 minutes</div>
                    </div>
                    
                    <p class="text" style="margin-top: 24px;">Once verified, you'll have full access to generate Roman Urdu captions for your videos!</p>
                </div>
                <div class="footer">
                    <p class="footer-text">© 2024 RomaSub.AI — Roman Urdu Captions Generator</p>
                </div>
            </div>
        </div>
    </body>
    </html>
    """


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

        # Subject and content based on purpose
        if purpose == "password_reset":
            subject = "🔐 Reset Your RomaSub.AI Password"
            html_content = get_password_reset_template(to_name, otp)
            text_content = f"Your password reset OTP is: {otp}. This code expires in 15 minutes."
        else:
            subject = "✉️ Verify Your RomaSub.AI Email"
            html_content = get_email_verify_template(to_name, otp)
            text_content = f"Your email verification OTP is: {otp}. This code expires in 15 minutes."

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
