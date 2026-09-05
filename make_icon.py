#!/usr/bin/env python3
"""Generates the SignOs icon set: light/dark/tinted app icons, Icon Composer
layers, and the document-type icon. Clean geometric monogram, App Store-grade."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(ROOT, "Feather", "Resources", "Assets.xcassets", "AppIcon.appiconset")
ICON_DIR = os.path.join(ROOT, "Feather", "Resources", "AppIcon.icon", "Assets")
ICONS_DIR = os.path.join(ROOT, "Feather", "Resources", "Icons")

FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

TOP = (18, 108, 255)      # vivid blue
BOTTOM = (0, 62, 200)     # deep blue
DARK_BG_TOP = (22, 24, 34)
DARK_BG_BOTTOM = (10, 11, 16)


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        for x in range(size):
            img.putpixel((x, y), (r, g, b))
    return img


def draw_glyph(img, size, color=(255, 255, 255), scale=0.62, dy=0.0):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_PATH, int(size * scale))
    bbox = d.textbbox((0, 0), "S", font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (size - w) / 2 - bbox[0]
    y = (size - h) / 2 - bbox[1] + size * dy
    d.text((x, y), "S", font=font, fill=color)
    return img


def highlight(img, size):
    """Soft diagonal glass highlight across the upper half."""
    hl = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(hl)
    d.ellipse([-size * 0.45, -size * 0.75, size * 1.25, size * 0.55], fill=52)
    hl = hl.filter(ImageFilter.GaussianBlur(size * 0.045))
    white = Image.new("RGB", (size, size), (255, 255, 255))
    img.paste(white, (0, 0), hl)
    return img


def app_icon(size, dark=False):
    top = DARK_BG_TOP if dark else TOP
    bottom = DARK_BG_BOTTOM if dark else BOTTOM
    img = gradient(size, top, bottom)
    glyph = (240, 244, 255) if dark else (255, 255, 255)
    img = draw_glyph(img, size, color=glyph)
    if not dark:
        img = highlight(img, size)
    return img


def tinted_icon(size):
    """Grayscale art for iOS tinted-icon mode."""
    img = gradient(size, (64, 66, 74), (36, 38, 44))
    img = draw_glyph(img, size, color=(235, 235, 240))
    return img


def glyph_layer(size):
    """Transparent PNG with the white glyph (Icon Composer layer)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img = draw_glyph(img, size, color=(255, 255, 255, 255))
    return img


def glow_layer(size):
    """Subtle radial glow overlay (Icon Composer secondary layer)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([size * 0.18, size * 0.05, size * 0.95, size * 0.8], fill=90)
    mask = mask.filter(ImageFilter.GaussianBlur(size * 0.09))
    white = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    img.paste(white, (0, 0), mask)
    return img


def doc_icon(size):
    img = gradient(size, TOP, BOTTOM).convert("RGBA")
    img = draw_glyph(img, size, color=(255, 255, 255))
    img = highlight(img, size)

    # rounded corners for the document icon
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.18), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(ICONS_DIR, exist_ok=True)

    app_icon(1024).save(os.path.join(ASSETS, "feather.png"))
    app_icon(1024, dark=True).save(os.path.join(ASSETS, "feather_dark.png"))
    tinted_icon(1024).save(os.path.join(ASSETS, "feather_tint.png"))

    glyph_layer(1024).save(os.path.join(ICON_DIR, "feather.png"))
    glow_layer(1024).save(os.path.join(ICON_DIR, "feather 5.png"))

    doc_icon(512).save(os.path.join(ROOT, "Feather", "Resources", "feather_extension.png"))

    for name in ("V0", "V1", "V1Mac", "V2Mac", "Donor", "Wing"):
        for scale in ("@2x", "@3x"):
            size = 120 if scale == "@2x" else 180
            app_icon(size).save(os.path.join(ICONS_DIR, f"{name}{scale}.png"))

    print("icons generated")


if __name__ == "__main__":
    main()
