#!/usr/bin/env python3
"""Slice Spriterrific sheets into Magpie AssetManifest raccoon frames + update licenses."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from PIL import Image


def find_latest_run(runs: Path) -> Path:
    dirs = sorted([p for p in runs.glob("neon-city-bandit-*") if p.is_dir()], key=lambda p: p.stat().st_mtime)
    if not dirs:
        raise SystemExit(f"No neon-city-bandit-* runs under {runs}")
    return dirs[-1]


def find_sheet(run: Path, action: str) -> Path | None:
    candidates = [
        run / action / "spritesheet.png",
        run / "actions" / action / "spritesheet.png",
        run / f"{action}/spritesheet.png",
    ]
    # Also search recursively
    for p in candidates:
        if p.is_file():
            return p
    hits = list(run.rglob(f"*{action}*spritesheet*.png"))
    return hits[0] if hits else None


def find_manifest(sheet: Path) -> dict:
    man = sheet.with_name("manifest.json")
    if man.is_file():
        return json.loads(man.read_text())
    # sibling
    for p in sheet.parent.glob("*.json"):
        if "manifest" in p.name:
            return json.loads(p.read_text())
    return {}


def slice_sheet(sheet: Path, cell: int = 256) -> list[Image.Image]:
    im = Image.open(sheet).convert("RGBA")
    man = find_manifest(sheet)
    cols = man.get("columns") or max(1, im.width // cell)
    rows = man.get("rows") or max(1, im.height // cell)
    frames_meta = man.get("frames")
    out: list[Image.Image] = []
    if isinstance(frames_meta, list) and frames_meta and isinstance(frames_meta[0], dict):
        for fr in frames_meta:
            x, y = int(fr.get("x", 0)), int(fr.get("y", 0))
            w, h = int(fr.get("w", cell)), int(fr.get("h", cell))
            out.append(im.crop((x, y, x + w, y + h)))
        return out
    count = int(man.get("frames") or cols * rows)
    n = 0
    for r in range(rows):
        for c in range(cols):
            if n >= count:
                break
            box = (c * cell, r * cell, (c + 1) * cell, (r + 1) * cell)
            if box[2] <= im.width and box[3] <= im.height:
                out.append(im.crop(box))
                n += 1
        if n >= count:
            break
    return out


def save_scaled(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    im256 = im.resize((256, 256), Image.Resampling.LANCZOS) if im.size != (256, 256) else im
    im256.save(dest)
    stem = dest.stem
    parent = dest.parent
    im256.resize((128, 128), Image.Resampling.LANCZOS).save(parent / f"{stem}@2x.png")
    im256.resize((192, 192), Image.Resampling.LANCZOS).save(parent / f"{stem}@3x.png")


def pick(frames: list[Image.Image], n: int) -> list[Image.Image]:
    if not frames:
        return []
    if len(frames) <= n:
        return frames
    return [frames[int(round(i * (len(frames) - 1) / (n - 1)))] for i in range(n)]


def update_licenses(ledger: dict, dest_root: Path) -> None:
    lic = Path("Assets/LICENSES.md")
    asl = Path("ASSETS_LICENSES.md")
    block = f"""
## Raccoon / bandit (Spriterrific — primary)

| Asset | Source | License / ownership |
| --- | --- | --- |
| `sprites/raccoon/*.png` + `sprites/raccoon/spriterrific/**` | Spriterrific AI sprite generator ([spriterrific.com](https://spriterrific.com)); reference = project raccoon idle | Owned by **Cinder and Crown LLC** (Spriterrific commercial ownership of outputs) |

Generation ledger:
- Anchor brief: {ledger.get('anchorBrief')}
- Preset: `{ledger.get('candidatePromptPreset')}`
- Reference: `{ledger.get('referenceImage')}`
- Character job id: `{ledger.get('characterJobId')}`
- Idle job id: `{ledger.get('idleJobId')}`
- Action job id: `{ledger.get('actionJobId')}`
- Credits debited: {ledger.get('creditsDebited')} (refunded {ledger.get('creditsRefunded')}; net {ledger.get('creditsNet')})
- Actions: {', '.join(ledger.get('actions') or [])}
- Hurt / MOP robots remain free CC0 / procedural (not Spriterrific).
"""
    if lic.exists():
        text = lic.read_text()
        # Replace prior raccoon primary section if present, else prepend after header
        if "## Raccoon / bandit (Spriterrific" in text:
            text = re.sub(
                r"## Raccoon / bandit \(Spriterrific.*?(?=\n## |\Z)",
                block.strip() + "\n\n",
                text,
                flags=re.S,
            )
        elif "## Raccoon / bandit" in text:
            text = text.replace("## Raccoon / bandit", block.strip() + "\n\n## Raccoon / bandit (legacy)", 1)
        else:
            text = text.rstrip() + "\n" + block
        lic.write_text(text)
    row = (
        f"| `Assets/Generated/sprites/raccoon/**` (Spriterrific idle/run/jump/attack) | "
        f"Spriterrific jobs `{ledger.get('characterJobId')}` / `{ledger.get('actionJobId')}` "
        f"(net {ledger.get('creditsNet')} credits). | Owned by Cinder & Crown LLC | 2026-11-16 |\n"
    )
    if asl.exists():
        t = asl.read_text()
        if "Spriterrific" not in t:
            t = t.rstrip() + "\n" + row
            asl.write_text(t)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=Path, default=Path("spriterrific-runs"))
    ap.add_argument("--dest", type=Path, default=Path("Assets/Generated/sprites/raccoon"))
    args = ap.parse_args()

    run = find_latest_run(args.runs)
    print(f"Importing from {run}")
    ledger_path = run / "LEDGER.json"
    ledger = json.loads(ledger_path.read_text()) if ledger_path.is_file() else {}

    mapping = {
        "idle": ("idle", 1),
        "run": ("run", 6),
        "jump": ("jump", 1),
        "attack": ("pounce", 1),  # stomp/attack → pounce/belly visual
    }
    spit = args.dest / "spriterrific"
    spit.mkdir(parents=True, exist_ok=True)

    for action, (out_name, count) in mapping.items():
        sheet = find_sheet(run, action)
        if not sheet:
            print(f"WARN: missing sheet for {action}")
            continue
        frames = slice_sheet(sheet)
        print(f"{action}: {len(frames)} frames from {sheet}")
        # Copy full cycle
        cdir = spit / action
        cdir.mkdir(parents=True, exist_ok=True)
        for i, fr in enumerate(frames, 1):
            fr.resize((256, 256), Image.Resampling.LANCZOS).save(cdir / f"{i:02d}.png")
        chosen = pick(frames, count)
        if action == "run":
            for i, fr in enumerate(chosen, 1):
                save_scaled(fr, args.dest / f"run_{i:02d}.png")
        elif action == "jump":
            save_scaled(chosen[0], args.dest / "jump.png")
            # fall ≈ last third of jump sheet
            fall = frames[max(0, (len(frames) * 2) // 3)] if frames else chosen[0]
            save_scaled(fall, args.dest / "fall.png")
        elif action == "idle":
            save_scaled(chosen[0], args.dest / "idle.png")
            # mask_mode = idle with cyan push done in-engine
        elif action == "attack":
            save_scaled(chosen[0], args.dest / "pounce.png")
            save_scaled(frames[-1] if frames else chosen[0], args.dest / "belly_flop.png")

    # Prefer spriterrific cycles for BanditVisual loader (same path as licensed_ccby).
    # Mirror into licensed_ccby-compatible folder name used by ArtCatalog.
    for action in ("idle", "run", "jump"):
        src = spit / action
        if not src.is_dir():
            continue
        dst = args.dest / "licensed_ccby" / action
        dst.mkdir(parents=True, exist_ok=True)
        for f in sorted(src.glob("*.png")):
            Image.open(f).save(dst / f.name)

    update_licenses(ledger, args.dest)
    print("Import complete")


if __name__ == "__main__":
    main()
