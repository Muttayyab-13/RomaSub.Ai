#!/usr/bin/env python3
"""
Convert logo.png to app_icon.ico for Windows application
Requires: pip install pillow
"""

from PIL import Image
import os

# Paths
logo_path = "assets/images/logos/logo.png"
ico_output_path = "windows/runner/resources/app_icon.ico"

def convert_png_to_ico(png_path, ico_path):
    """Convert PNG to ICO with multiple sizes"""
    try:
        # Open the PNG image
        img = Image.open(png_path)

        # Convert to RGBA if not already
        if img.mode != 'RGBA':
            img = img.convert('RGBA')

        # Create ICO with multiple sizes (16x16, 32x32, 48x48, 64x64, 128x128, 256x256)
        icon_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

        # Ensure output directory exists
        os.makedirs(os.path.dirname(ico_path), exist_ok=True)

        # Save as ICO
        img.save(ico_path, format='ICO', sizes=icon_sizes)

        print(f"[SUCCESS] Successfully converted {png_path} to {ico_path}")
        print(f"[INFO] Icon created with sizes: {', '.join([f'{w}x{h}' for w, h in icon_sizes])}")
        return True

    except Exception as e:
        print(f"[ERROR] Error converting image: {str(e)}")
        return False

if __name__ == "__main__":
    print("RomaSub.AI Logo to Icon Converter")
    print("=" * 50)

    if not os.path.exists(logo_path):
        print(f"[ERROR] Logo file not found at {logo_path}")
        exit(1)

    if convert_png_to_ico(logo_path, ico_output_path):
        print("\n[SUCCESS] Icon conversion completed successfully!")
        print(f"  The app icon has been updated at: {ico_output_path}")
        print("\nNext steps:")
        print("1. Clean the Flutter build: flutter clean")
        print("2. Rebuild the app: flutter build windows")
    else:
        print("\n[ERROR] Icon conversion failed!")
        print("Make sure you have Pillow installed: pip install pillow")
        exit(1)
