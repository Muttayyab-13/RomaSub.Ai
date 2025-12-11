"""
Email Service for RomaSub.AI
Handles sending OTP emails via MailerSend API

Pure functions for email operations.
"""

from mailersend import MailerSendClient, EmailBuilder
from app.config import settings
import logging
import base64
import os

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
# Email Template Functions
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
    logo_html = f'<img src="data:image/png;base64,{logo_base64}" alt="RomaSub.AI Logo" style="max-width: 200px; height: auto;">' if logo_base64 else '<h1>RomaSub.AI</h1>'

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background-color: #1a73e8; color: white; padding: 20px; text-align: center; }}
            .logo {{ max-width: 200px; height: auto; }}
            .content {{ padding: 30px; background-color: #f9f9f9; }}
            .otp-box {{ background-color: #e3f2fd; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }}
            .otp-code {{ font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #1a73e8; }}
            .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                {logo_html}
            </div>
            <div class="content">
                <h2>Password Reset Request</h2>
                <p>Hello {name},</p>
                <p>We received a request to reset your password. Use the OTP code below to complete the process:</p>
                <div class="otp-box">
                    <div class="otp-code">{otp}</div>
                </div>
                <p>This code will expire in <strong>15 minutes</strong>.</p>
                <p>If you didn't request this password reset, please ignore this email.</p>
            </div>
            <div class="footer">
                <p>&copy; 2024 RomaSub.AI - Roman Urdu Captions Generator</p>
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
    logo_html = f'<img src="data:image/png;base64,{logo_base64}" alt="RomaSub.AI Logo" style="max-width: 200px; height: auto;">' if logo_base64 else '<h1>RomaSub.AI</h1>'

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background-color: #1a73e8; color: white; padding: 20px; text-align: center; }}
            .logo {{ max-width: 200px; height: auto; }}
            .content {{ padding: 30px; background-color: #f9f9f9; }}
            .otp-box {{ background-color: #e3f2fd; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }}
            .otp-code {{ font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #1a73e8; }}
            .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                {logo_html}
            </div>
            <div class="content">
                <h2>Verify Your Email</h2>
                <p>Hello {name},</p>
                <p>Thank you for registering with RomaSub.AI! Please use the OTP code below to verify your email:</p>
                <div class="otp-box">
                    <div class="otp-code">{otp}</div>
                </div>
                <p>This code will expire in <strong>15 minutes</strong>.</p>
            </div>
            <div class="footer">
                <p>&copy; 2024 RomaSub.AI - Roman Urdu Captions Generator</p>
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
        if not settings.mailersend_api_key:
            logger.warning("MailerSend API key not configured. OTP: %s", otp)
            print(f"\n{'='*50}")
            print(f"EMAIL OTP (API not configured)")
            print(f"To: {to_email}")
            print(f"OTP: {otp}")
            print(f"{'='*50}\n")
            return True  # Return True for development/testing

        # Subject and content based on purpose
        if purpose == "password_reset":
            subject = "Reset Your RomaSub.AI Password"
            html_content = get_password_reset_template(to_name, otp)
            text_content = f"Your password reset OTP is: {otp}. This code expires in 15 minutes."
        else:
            subject = "Verify Your RomaSub.AI Email"
            html_content = get_email_verify_template(to_name, otp)
            text_content = f"Your email verification OTP is: {otp}. This code expires in 15 minutes."

        # Create MailerSend client (v2.0.0 API)
        client = MailerSendClient(api_key=settings.mailersend_api_key)

        # Build email using EmailBuilder
        email = (EmailBuilder()
            .from_email(settings.mailersend_sender_email, settings.mailersend_sender_name)
            .to(to_email, to_name)
            .subject(subject)
            .html(html_content)
            .text(text_content)
            .build())

        # Send email
        response = client.emails.send(email)

        logger.info("OTP email sent to %s, response: %s", to_email, response)
        return True

    except Exception as e:
        logger.error("Failed to send OTP email to %s: %s", to_email, str(e))
        # Print OTP to console for development
        print(f"\n{'='*50}")
        print(f"EMAIL SENDING FAILED - OTP for {to_email}: {otp}")
        print(f"Error: {str(e)}")
        print(f"{'='*50}\n")
        return False
