#!/usr/bin/env python3
"""Slice Spriterrific sheets into foot-baseline-normalized frames for Magpie.

Reads Assets/Generated/sprites/spriterrific/<char>/<action>/{spritesheet,manifest}
Writes Assets/Generated/sprites/spriterrific_ready/<char>/<action>/01.png… + meta.json
and a character-gym contact sheet under _gym/.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path("Assets/Generated/sprites/spriterrific")
OUT = Path("Assets/Generated/sprites/spriterrific_ready")
GYM = OUT / "_gym"

CHARS: dict[str, list[str]] = {
    "bandit": [
        "idle", "idle_front", "walk", "run", "jump", "attack", "hurt", "death",
        "pick_up", "disco_dance",
    ],
    "mop_bot": ["walk", "attack", "hurt", "death"],
    "mop_9000_boss": ["idle", "walk", "tread_roll", "attack", "hurt", "death"],
}


def slice_sheet(sheet: Path, man: dict) -> list[Image.Image]:
    im = Image.open(sheet).convert("RGBA")
    fw = int(man.get("frameWidth", 256))
    fh = int(man.get("frameHeight", 256))
    cols = int(man.get("columns", max(1, im.width // fw)))
    rows = int(man.get("rows", max(1, im.height // fh)))
    count = int(man.get("frames") or cols * rows)
    out: list[Image.Image] = []
    n = 0
    for r in range(rows):
        for c in range(cols):
            if n >= count:
                break
            box = (c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)
            if box[2] <= im.width and box[3] <= im.height:
                out.append(im.crop(box))
                n += 1
        if n >= count:
            break
    return out


def opaque_bottom(fr: Image.Image, alpha_thresh: int = 12) -> int | None:
    a = fr.split()[-1]
    w, h = fr.size
    for y in range(h - 1, -1, -1):
        row = a.crop((0, y, w, y + 1))
        if max(row.get_flattened_data()) > alpha_thresh:
            return y
    return None


def normalize_frames(frames: list[Image.Image], target_bottom: int) -> list[Image.Image]:
    out: list[Image.Image] = []
    for fr in frames:
        fr = fr.convert("RGBA")
        if fr.size != (256, 256):
            fr = fr.resize((256, 256), Image.Resampling.LANCZOS)
        bottom = opaque_bottom(fr)
        if bottom is None:
            out.append(fr)
            continue
        dy = target_bottom - bottom
        if dy == 0:
            out.append(fr)
            continue
        canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        canvas.paste(fr, (0, dy), fr)
        out.append(canvas)
    return out


def save_cycle(dest: Path, frames: list[Image.Image], man: dict, foot_y: int) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for i, fr in enumerate(frames, 1):
        fr.save(dest / f"{i:02d}.png")
    meta = {
        "frames": len(frames),
        "fps": man.get("fps", 12),
        "frameWidth": 256,
        "frameHeight": 256,
        "anchor": {"x": 128, "y": foot_y},
        "direction": man.get("direction", "w"),
        "action": man.get("action"),
        "source": "spriterrific",
    }
    (dest / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")


def main() -> None:
    char_foot: dict[str, int] = {}
    for char, actions in CHARS.items():
        bottoms: list[int] = []
        for action in actions:
            sheet = ROOT / char / action / "spritesheet.png"
            man_p = ROOT / char / action / "manifest.json"
            if not sheet.is_file():
                continue
            man = json.loads(man_p.read_text())
            frames = slice_sheet(sheet, man)
            for fr in frames[: min(8, len(frames))]:
                b = opaque_bottom(fr)
                if b is not None:
                    bottoms.append(b)
        bottoms.sort()
        char_foot[char] = bottoms[len(bottoms) // 2] if bottoms else 227
        print(f"{char} shared foot_y={char_foot[char]}")

    index: dict = {
        "characters": {},
        "notes": "Side views face WEST; flip xScale for right. Anchor bottom-center at foot_y.",
    }
    for char, actions in CHARS.items():
        foot = char_foot[char]
        index["characters"][char] = {"foot_y": foot, "actions": {}}
        for action in actions:
            sheet = ROOT / char / action / "spritesheet.png"
            man_p = ROOT / char / action / "manifest.json"
            if not sheet.is_file():
                print(f"SKIP missing {char}/{action}")
                continue
            man = json.loads(man_p.read_text())
            frames = normalize_frames(slice_sheet(sheet, man), foot)
            dest = OUT / char / action
            save_cycle(dest, frames, man, foot)
            index["characters"][char]["actions"][action] = {
                "frames": len(frames),
                "fps": man.get("fps"),
                "path": f"sprites/spriterrific_ready/{char}/{action}",
            }
            print(f"  {char}/{action}: {len(frames)} @ {man.get('fps')}fps")

    for src_name, dst_name in [
        ("bandit/anchor-s.png", "bandit/anchor_front.png"),
        ("bandit/anchor-w.png", "bandit/anchor_side.png"),
        ("mop_bot/anchor-w.png", "mop_bot/anchor_side.png"),
        ("mop_9000_boss/anchor-w.png", "mop_9000_boss/anchor_side.png"),
    ]:
        src = ROOT / src_name
        if src.is_file():
            dst = OUT / dst_name
            dst.parent.mkdir(parents=True, exist_ok=True)
            Image.open(src).convert("RGBA").save(dst)

    GYM.mkdir(parents=True, exist_ok=True)
    bandit_actions = [a for a in CHARS["bandit"] if (OUT / "bandit" / a / "01.png").is_file()]
    cell, pad = 128, 8
    cols = min(5, len(bandit_actions))
    rows = (len(bandit_actions) + cols - 1) // cols
    gym = Image.new("RGBA", (cols * (cell + pad) + pad, rows * (cell + 28) + pad), (20, 16, 40, 255))
    draw = ImageDraw.Draw(gym)
    for i, action in enumerate(bandit_actions):
        r, c = divmod(i, cols)
        x0 = pad + c * (cell + pad)
        y0 = pad + r * (cell + 28)
        draw.line([(x0, y0 + cell - 4), (x0 + cell, y0 + cell - 4)], fill=(80, 200, 255, 180), width=2)
        fr = Image.open(OUT / "bandit" / action / "01.png").convert("RGBA").resize((cell, cell), Image.Resampling.LANCZOS)
        gym.paste(fr, (x0, y0), fr)
        draw.text((x0 + 4, y0 + cell + 2), action, fill=(220, 220, 240, 255))
    gym.save(GYM / "bandit_contact.png")

    (OUT / "index.json").write_text(json.dumps(index, indent=2) + "\n")
    (OUT / "README.md").write_text(
        "# Spriterrific ready frames\n\n"
        "Sliced + foot-baseline-normalized from `sprites/spriterrific/`.\n"
        "Side views face WEST — flip xScale for right.\n"
        "`disco_dance` kept for backlog easter egg. `bandit/anchor_front.png` for menu/Hideout.\n"
        "`idle_front` = title/menu/Hideout mascot. Boss movement uses `tread_roll` "
        "(code tread scroll is polish only).\n"
    )
    print("DONE", OUT)


if __name__ == "__main__":
    main()
