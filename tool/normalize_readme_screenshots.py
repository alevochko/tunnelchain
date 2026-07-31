#!/usr/bin/env python3
"""Normalize onboarding screenshots: equal canvas, uniform modal padding."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

PADDING = 56
MODAL_COLOR = (22, 27, 34)
COLOR_TOL = 12


def is_modal_surface(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    tr, tg, tb = MODAL_COLOR
    return (
        abs(r - tr) <= COLOR_TOL
        and abs(g - tg) <= COLOR_TOL
        and abs(b - tb) <= COLOR_TOL
    )


def find_modal_bbox(path: Path) -> tuple[int, int, int, int]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            if is_modal_surface(px[x, y]):
                xs.append(x)
                ys.append(y)
    if not xs:
        raise RuntimeError(f"modal not found in {path}")

    xs.sort()
    ys.sort()

    def pct(vals: list[int], p: float) -> int:
        i = int(len(vals) * p / 100)
        return vals[min(i, len(vals) - 1)]

    return pct(xs, 1), pct(ys, 1), pct(xs, 99) + 1, pct(ys, 99) + 1


def background_color(path: Path) -> tuple[int, int, int]:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    samples = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    return tuple(int(sum(c[i] for c in samples) / len(samples)) for i in range(3))  # type: ignore[return-value]


def normalize(inputs: list[tuple[str, Path]], output_dir: Path) -> None:
    boxes = [find_modal_bbox(path) for _, path in inputs]
    modals = [
        Image.open(path).convert("RGB").crop(box)
        for (_, path), box in zip(inputs, boxes)
    ]
    max_w = max(m.width for m in modals)
    max_h = max(m.height for m in modals)
    canvas_w = max_w + 2 * PADDING
    canvas_h = max_h + 2 * PADDING

    output_dir.mkdir(parents=True, exist_ok=True)

    for (name, path), modal in zip(inputs, modals):
        bg = background_color(path)
        canvas = Image.new("RGB", (canvas_w, canvas_h), bg)
        x = PADDING + (max_w - modal.width) // 2
        y = PADDING + (max_h - modal.height) // 2
        canvas.paste(modal, (x, y))
        out = output_dir / f"{name}.png"
        canvas.save(out, optimize=True)
        print(f"Wrote {out} ({canvas_w}x{canvas_h}, modal {modal.width}x{modal.height})")


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: normalize_readme_screenshots.py <output-dir> <input> [name:input ...]")
        sys.exit(1)

    output_dir = Path(sys.argv[1])
    pairs: list[tuple[str, Path]] = []
    for arg in sys.argv[2:]:
        if ":" in arg:
            name, path = arg.split(":", 1)
        else:
            path = arg
            name = Path(path).stem
        pairs.append((name, Path(path)))

    normalize(pairs, output_dir)


if __name__ == "__main__":
    main()
