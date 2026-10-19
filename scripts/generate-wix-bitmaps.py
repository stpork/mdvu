#!/usr/bin/env python3
"""Regenerate WiX branding from the application icon (requires Pillow)."""
import argparse
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def dialog_background():
    image = Image.new("RGB", (493, 312), "white")
    pixels = image.load()
    for y in range(image.height):
        fraction = y / image.height
        base = [int(top * (1 - fraction) + bottom * fraction)
                for top, bottom in zip((23, 34, 59), (12, 18, 34))]
        for x in range(164):
            color = base.copy()
            distance = math.hypot(x - 82, y - 116)
            if 64 < distance < 82:
                glow = math.sin((distance - 64) / 18 * math.pi) * 0.15
                color = [min(255, int(channel + glow * accent))
                         for channel, accent in zip(color, (50, 90, 160))]
            if 24 <= x < 140 and 60 <= y < 176:
                color = [int(channel * 0.88) for channel in color]
            pixels[x, y] = tuple(color)
        pixels[164, y] = (218, 224, 233)
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "packaging/windows")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with Image.open(ROOT / "packaging/assets/AppIcon-256.png") as source:
        icon = source.convert("RGBA")

    dialog = dialog_background()
    scaled = icon.resize((108, 108), Image.Resampling.BILINEAR)
    dialog.paste(scaled, (28, 62), scaled)

    banner = Image.new("RGB", (493, 58), "white")
    banner.paste((226, 232, 240), (0, 57, 493, 58))
    scaled = icon.resize((46, 46), Image.Resampling.BILINEAR)
    banner.paste(scaled, (431, 6), scaled)

    for name, image in [("dialog.bmp", dialog), ("banner.bmp", banner)]:
        path = args.output / name
        image.save(path, dpi=(72, 72))
        print(f"{path}: {image.width} x {image.height}, RGB")


if __name__ == "__main__":
    main()
