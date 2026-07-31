#!/usr/bin/env python3
"""Generate TunnelChain app icons from the sidebar logo geometry."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
STATUS_BAR_DIR = ROOT / "macos/Runner/Assets.xcassets/StatusBarIcon.imageset"
ASSETS_ICON_DIR = ROOT / "assets/icons"

BG = (0x16, 0x1B, 0x22, 255)
GREEN = (0x3F, 0xB9, 0x50, 255)
BLUE = (0x38, 0x8B, 0xFD, 255)


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _cubic(p0, p1, p2, p3, steps: int = 24) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = (
            u**3 * p0[0]
            + 3 * u**2 * t * p1[0]
            + 3 * u * t**2 * p2[0]
            + t**3 * p3[0]
        )
        y = (
            u**3 * p0[1]
            + 3 * u**2 * t * p1[1]
            + 3 * u * t**2 * p2[1]
            + t**3 * p3[1]
        )
        pts.append((x, y))
    return pts


def logo_points() -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    pts.append((3.0, 6.5))
    pts.append((8.5, 6.5))
    pts.extend(_cubic((8.5, 6.5), (10.0, 6.5), (11.5, 8.0), (11.5, 9.5)))
    pts.append((11.5, 10.5))
    pts.extend(_cubic((11.5, 10.5), (11.5, 12.0), (13.0, 13.5), (14.5, 13.5)))
    pts.append((17.0, 13.5))
    return pts


def draw_logo(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    *,
    stroke_scale: float = 1.0,
    stroke: tuple[int, int, int, int] = BLUE,
    start_dot: tuple[int, int, int, int] = GREEN,
    end_dot: tuple[int, int, int, int] = BLUE,
) -> None:
    x0, y0, x1, y1 = box
    size = min(x1 - x0, y1 - y0)
    scale = size / 20.0
    ox = x0 + (x1 - x0 - 20 * scale) / 2
    oy = y0 + (y1 - y0 - 20 * scale) / 2

    def tx(x: float, y: float) -> tuple[float, float]:
        return (ox + x * scale, oy + y * scale)

    path = [tx(x, y) for x, y in logo_points()]
    stroke_w = max(1.0, 1.7 * scale * stroke_scale)
    draw.line(path, fill=stroke, width=int(round(stroke_w)), joint="curve")

    r = 2.0 * scale
    gx, gy = tx(3.0, 6.5)
    bx, by = tx(17.0, 13.5)
    draw.ellipse((gx - r, gy - r, gx + r, gy + r), fill=start_dot)
    draw.ellipse((bx - r, by - r, bx + r, by + r), fill=end_dot)


def rounded_mask(size: int, radius: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def render_app_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    base = Image.new("RGBA", (size, size), BG)
    radius = size * 0.2237  # macOS squircle approximation
    mask = rounded_mask(size, radius)
    img = Image.composite(base, img, mask)

    draw = ImageDraw.Draw(img)
    pad = size * 0.18
    draw_logo(draw, (pad, pad, size - pad, size - pad))
    return img


def render_status_bar_icon(size: int) -> Image.Image:
    """Monochrome chain for menu-bar tinting (black on transparent)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pad = size * 0.08
    mono = (0, 0, 0, 255)
    draw_logo(
        draw,
        (pad, pad, size - pad, size - pad),
        stroke_scale=1.15,
        stroke=mono,
        start_dot=mono,
        end_dot=mono,
    )
    return img


def save_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)
    print(f"wrote {path}")


def main() -> None:
    app_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for name, size in app_sizes.items():
        save_png(APP_ICON_DIR / name, render_app_icon(size))

    status_sizes = {
        "status_bar_18.png": 18,
        "status_bar_36.png": 36,
    }
    contents = """{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "18x18",
      "filename" : "status_bar_18.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "18x18",
      "filename" : "status_bar_36.png"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
    STATUS_BAR_DIR.mkdir(parents=True, exist_ok=True)
    (STATUS_BAR_DIR / "Contents.json").write_text(contents, encoding="utf-8")
    for name, size in status_sizes.items():
        save_png(STATUS_BAR_DIR / name, render_status_bar_icon(size))

    for size in (32, 64, 128, 256):
        save_png(ASSETS_ICON_DIR / f"tray_icon_{size}.png", render_status_bar_icon(size))
    save_png(ASSETS_ICON_DIR / "tray_icon.png", render_status_bar_icon(32))
    save_png(ASSETS_ICON_DIR / "app_icon.png", render_app_icon(256))


if __name__ == "__main__":
    main()
