#!/usr/bin/env python3
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
"""Composite comic-style intro panels from Spriterrific sprites + Story.json captions."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORY = ROOT / "Assets/Story/Story.json"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "smoke-artifacts"
BG = ROOT / "Assets/Generated/backgrounds/far_skyline.png"
MID = ROOT / "Assets/Generated/backgrounds/mid_buildings.png"
BANDIT = ROOT / "Assets/Generated/sprites/spriterrific_ready/bandit/idle_front/01.png"
MOP = ROOT / "Assets/Generated/sprites/spriterrific_ready/mop_bot/walk/01.png"


def load_rgba(path: Path, size: tuple[int, int] | None = None) -> Image.Image | None:
    if not path.exists():
        return None
    im = Image.open(path).convert("RGBA")
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    story = json.loads(STORY.read_text())
    panels = story.get("introPanels", [])
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
        small = font

    for i, panel in enumerate(panels):
        W, H = 720, 1280
        canvas = Image.new("RGBA", (W, H), (12, 8, 36, 255))
        draw = ImageDraw.Draw(canvas)
        # Night wash
        for y in range(H):
            c = int(12 + (y / H) * 28)
            draw.line([(0, y), (W, y)], fill=(c, 8, 40 + c // 2, 255))

        frame = (48, 160, W - 48, H - 280)
        draw.rounded_rectangle(frame, radius=24, fill=(18, 14, 42, 255), outline=(64, 240, 255, 255), width=4)

        if bg := load_rgba(BG, (600, 320)):
            canvas.alpha_composite(bg, (60, 200))
        if mid := load_rgba(MID, (600, 280)):
            canvas.alpha_composite(mid, (60, 320))

        pid = panel.get("id", "")
        if pid in ("raid", "bagged") and (mop := load_rgba(MOP, (220, 220))):
            canvas.alpha_composite(mop, (400, 420))
        if bandit := load_rgba(BANDIT, (240, 240)):
            bx = 120 if pid in ("raid", "bagged") else 240
            canvas.alpha_composite(bandit, (bx, 440))

        caption = panel.get("caption", "")
        # Caption plate
        draw.rounded_rectangle((64, H - 250, W - 64, H - 140), radius=12, fill=(10, 8, 28, 230), outline=(255, 70, 180, 255), width=2)
        # wrap caption
        words = caption.split()
        lines, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if len(trial) > 42:
                lines.append(cur)
                cur = w
            else:
                cur = trial
        if cur:
            lines.append(cur)
        ty = H - 230
        for line in lines[:3]:
            draw.text((80, ty), line, fill=(255, 255, 255, 255), font=font)
            ty += 28

        draw.text((W // 2 - 30, H - 100), f"{i + 1} / {len(panels)}", fill=(64, 240, 255, 255), font=small)
        out = OUT / f"00-intro-{i + 1:02d}.png"
        canvas.convert("RGB").save(out, "PNG")
        print("wrote", out)


if __name__ == "__main__":
    main()
