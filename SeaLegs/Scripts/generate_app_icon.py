#!/usr/bin/env python3
"""Generate SeaLegs app and menu bar icon assets."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "SeaLegs" / "Assets.xcassets"
APP_ICON_ROOT = ASSET_ROOT / "AppIcon.appiconset"
MENU_ICON_ROOT = ASSET_ROOT / "MenuBarIcon.imageset"
ACCENT_COLOR_ROOT = ASSET_ROOT / "AccentColor.colorset"


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def render_app_icon(size: int = 1024) -> Image.Image:
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    background = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    pixels = background.load()

    for y in range(size):
        t = y / max(size - 1, 1)
        for x in range(size):
            u = x / max(size - 1, 1)
            radial = math.hypot(u - 0.50, t - 0.42)
            glow = max(0.0, 1.0 - radial * 1.45)
            red = int(8 + 16 * (1 - t) + 18 * glow)
            green = int(42 + 70 * (1 - t) + 36 * glow)
            blue = int(78 + 96 * (1 - t) + 58 * glow)
            pixels[x, y] = (red, green, blue, 255)

    mask = rounded_mask(size, int(214 * scale))
    image.alpha_composite(background)
    image.putalpha(mask)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    inset = int(34 * scale)
    shadow_draw.rounded_rectangle(
        (inset, inset, size - inset, size - inset),
        radius=int(184 * scale),
        outline=(0, 0, 0, 92),
        width=max(1, int(12 * scale)),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=6 * scale))
    image.alpha_composite(shadow)

    draw = ImageDraw.Draw(image)
    horizon_y = int(414 * scale)
    draw.line(
        [(int(168 * scale), horizon_y), (int(856 * scale), horizon_y)],
        fill=(154, 231, 255, 166),
        width=max(2, int(10 * scale)),
    )

    wave_center_points = []
    for index in range(0, 241):
        x = (164 + index * (696 / 240)) * scale
        y = (610 + math.sin(index / 240 * math.tau * 1.35) * 68) * scale
        wave_center_points.append((x, y))
    wave_half_height = 26 * scale
    wave_ribbon = (
        [(x, y - wave_half_height) for x, y in wave_center_points]
        + [(x, y + wave_half_height) for x, y in reversed(wave_center_points)]
    )
    draw.polygon(wave_ribbon, fill=(104, 232, 255, 238))

    foam_points = []
    for index in range(0, 241):
        x = (172 + index * (680 / 240)) * scale
        y = (552 + math.sin(index / 240 * math.tau * 1.35 + 0.7) * 34) * scale
        foam_points.append((x, y))
    draw.line(foam_points, fill=(236, 255, 255, 184), width=max(2, int(12 * scale)), joint="curve")

    center = (int(512 * scale), int(486 * scale))
    ring_radius = int(142 * scale)
    draw.ellipse(
        (
            center[0] - ring_radius,
            center[1] - ring_radius,
            center[0] + ring_radius,
            center[1] + ring_radius,
        ),
        outline=(239, 255, 248, 192),
        width=max(2, int(14 * scale)),
    )
    draw.line(
        [(center[0] - int(204 * scale), center[1]), (center[0] + int(204 * scale), center[1])],
        fill=(239, 255, 248, 144),
        width=max(2, int(8 * scale)),
    )
    draw.line(
        [(center[0], center[1] - int(204 * scale)), (center[0], center[1] + int(204 * scale))],
        fill=(239, 255, 248, 144),
        width=max(2, int(8 * scale)),
    )
    dot_radius = int(24 * scale)
    draw.ellipse(
        (center[0] - dot_radius, center[1] - dot_radius, center[0] + dot_radius, center[1] + dot_radius),
        fill=(255, 255, 255, 238),
    )

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.arc(
        (int(86 * scale), int(66 * scale), int(938 * scale), int(918 * scale)),
        start=204,
        end=334,
        fill=(255, 255, 255, 72),
        width=max(2, int(18 * scale)),
    )
    image.alpha_composite(highlight)
    return image


def render_menu_icon(size: int) -> Image.Image:
    scale = size / 18
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    stroke = max(1, round(1.8 * scale))

    draw.ellipse(
        (2.5 * scale, 2.5 * scale, 15.5 * scale, 15.5 * scale),
        outline=(0, 0, 0, 255),
        width=stroke,
    )
    draw.line(
        [(4 * scale, 8 * scale), (14 * scale, 8 * scale)],
        fill=(0, 0, 0, 255),
        width=stroke,
    )

    points = []
    for index in range(0, 48):
        x = (3.4 + index * (11.2 / 47)) * scale
        y = (11.2 + math.sin(index / 47 * math.tau * 1.08) * 1.6) * scale
        points.append((x, y))
    draw.line(points, fill=(0, 0, 0, 255), width=stroke, joint="curve")
    draw.ellipse((7.15 * scale, 7.15 * scale, 10.85 * scale, 10.85 * scale), fill=(0, 0, 0, 255))
    return image


def write_app_icons() -> None:
    APP_ICON_ROOT.mkdir(parents=True, exist_ok=True)
    base = render_app_icon(2048)
    variants = [
        ("16x16", "1x", 16),
        ("16x16", "2x", 32),
        ("32x32", "1x", 32),
        ("32x32", "2x", 64),
        ("128x128", "1x", 128),
        ("128x128", "2x", 256),
        ("256x256", "1x", 256),
        ("256x256", "2x", 512),
        ("512x512", "1x", 512),
        ("512x512", "2x", 1024),
    ]
    images = []
    for logical_size, scale, pixels in variants:
        filename = f"sealegs-{logical_size.replace('x', '')}@{scale}.png"
        resized = base.resize((pixels, pixels), Image.Resampling.LANCZOS)
        resized.save(APP_ICON_ROOT / filename)
        images.append(
            {
                "filename": filename,
                "idiom": "mac",
                "scale": scale,
                "size": logical_size,
            }
        )

    write_json(
        APP_ICON_ROOT / "Contents.json",
        {
            "images": images,
            "info": {"author": "xcode", "version": 1},
        },
    )


def write_menu_icons() -> None:
    MENU_ICON_ROOT.mkdir(parents=True, exist_ok=True)
    images = []
    for scale, pixels in [("1x", 18), ("2x", 36), ("3x", 54)]:
        filename = f"menubar-icon@{scale}.png"
        render_menu_icon(pixels).save(MENU_ICON_ROOT / filename)
        images.append(
            {
                "filename": filename,
                "idiom": "universal",
                "scale": scale,
            }
        )

    write_json(
        MENU_ICON_ROOT / "Contents.json",
        {
            "images": images,
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        },
    )


def write_accent_color() -> None:
    write_json(
        ACCENT_COLOR_ROOT / "Contents.json",
        {
            "colors": [
                {
                    "color": {
                        "color-space": "srgb",
                        "components": {
                            "alpha": "1.000",
                            "blue": "0xFF",
                            "green": "0xD6",
                            "red": "0x52",
                        },
                    },
                    "idiom": "universal",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )


def main() -> None:
    write_json(ASSET_ROOT / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    write_app_icons()
    write_menu_icons()
    write_accent_color()
    print(f"Generated app icon assets in {APP_ICON_ROOT}")
    print(f"Generated menu bar icon assets in {MENU_ICON_ROOT}")
    print(f"Generated accent color asset in {ACCENT_COLOR_ROOT}")


if __name__ == "__main__":
    main()
