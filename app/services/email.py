"""
Email Service for RomaSub.AI
Handles sending OTP emails via MailerSend API

Pure functions for email operations.
"""

from mailersend import Email
from app.config import settings
import logging

# Setup logging
logger = logging.getLogger(__name__)


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
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background-color: #1a73e8; color: white; padding: 20px; text-align: center; }}
            .content {{ padding: 30px; background-color: #f9f9f9; }}
            .otp-box {{ background-color: #e3f2fd; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }}
            .otp-code {{ font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #1a73e8; }}
            .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>RomaSub.AI</h1>
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
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
            .header {{ background-color: #1a73e8; color: white; padding: 20px; text-align: center; }}
            .content {{ padding: 30px; background-color: #f9f9f9; }}
            .otp-box {{ background-color: #e3f2fd; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px; }}
            .otp-code {{ font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #1a73e8; }}
            .footer {{ text-align: center; padding: 20px; color: #666; font-size: 12px; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>RomaSub.AI</h1>
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

        # Create email client
        mailer = Email.NewEmail(settings.mailersend_api_key)

        # Set up email details
        mail_body = {}

        # From address
        mail_from = {
            "name": settings.mailersend_sender_name,
            "email": settings.mailersend_sender_email
        }

        # To address
        recipients = [
            {
                "name": to_name,
                "email": to_email
            }
        ]

        # Subject based on purpose
        if purpose == "password_reset":
            subject = "Reset Your RomaSub.AI Password"
            html_content = get_password_reset_template(to_name, otp)
            text_content = f"Your password reset OTP is: {otp}. This code expires in 15 minutes."
        else:
            subject = "Verify Your RomaSub.AI Email"
            html_content = get_email_verify_template(to_name, otp)
            text_content = f"Your email verification OTP is: {otp}. This code expires in 15 minutes."

        # Build email
        mailer.set_mail_from(mail_from, mail_body)
        mailer.set_mail_to(recipients, mail_body)
        mailer.set_subject(subject, mail_body)
        mailer.set_html_content(html_content, mail_body)
        mailer.set_plaintext_content(text_content, mail_body)

        # Send email
        response = mailer.send(mail_body)

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
