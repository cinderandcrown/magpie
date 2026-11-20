#!/usr/bin/env python3
"""Assert Spriterrific ready frames ship for bandit / mop_bot / boss."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READY = ROOT / "Assets/Generated/sprites/spriterrific_ready"
RAW = ROOT / "Assets/Generated/sprites/spriterrific"


class SpriterrificReadyTests(unittest.TestCase):
    def test_index_and_bandit_core(self) -> None:
        index = json.loads((READY / "index.json").read_text())
        bandit = index["characters"]["bandit"]["actions"]
        for action in ("idle", "walk", "run", "jump", "attack", "hurt", "death", "pick_up"):
            self.assertIn(action, bandit)
            frame = READY / "bandit" / action / "01.png"
            self.assertTrue(frame.is_file(), msg=str(frame))
            meta = json.loads((READY / "bandit" / action / "meta.json").read_text())
            self.assertGreaterEqual(meta["frames"], 2)
            self.assertEqual(meta["direction"], "w")

    def test_disco_kept_for_backlog(self) -> None:
        self.assertTrue((READY / "bandit/disco_dance/01.png").is_file())
        self.assertTrue((READY / "bandit/anchor_front.png").is_file())

    def test_idle_front_and_tread_roll(self) -> None:
        self.assertTrue((READY / "bandit/idle_front/01.png").is_file())
        meta = json.loads((READY / "bandit/idle_front/meta.json").read_text())
        self.assertEqual(meta.get("direction"), "s")
        self.assertTrue((READY / "mop_9000_boss/tread_roll/01.png").is_file())
        tread = json.loads((READY / "mop_9000_boss/tread_roll/meta.json").read_text())
        self.assertGreaterEqual(tread["frames"], 2)

    def test_mop_and_boss(self) -> None:
        for action in ("walk", "attack", "hurt", "death"):
            self.assertTrue((READY / "mop_bot" / action / "01.png").is_file())
        for action in ("idle", "walk", "tread_roll", "attack", "hurt", "death"):
            self.assertTrue((READY / "mop_9000_boss" / action / "01.png").is_file())

    def test_raw_sheets_present(self) -> None:
        self.assertTrue((RAW / "README.md").is_file())
        self.assertTrue((RAW / "bandit/idle/spritesheet.png").is_file())
        self.assertTrue((RAW / "mop_bot/walk/spritesheet.png").is_file())

    def test_juice_sfx_pack(self) -> None:
        sfx = ROOT / "Assets/Audio/sfx"
        man = json.loads((sfx / "sfx_manifest.json").read_text())
        sounds = man["sounds"]
        self.assertEqual(len(sounds), 42)  # + publisher_ident_whoosh
        for entry in sounds:
            self.assertTrue((sfx / entry["file"]).is_file(), msg=entry["file"])
        for required in (
            "startup_jingle",
            "jump",
            "land",
            "stomp_crunch",
            "pounce_whoosh",
            "coin_pickup",
            "loot_pickup",
            "raccoon_hurt",
            "raccoon_ko",
            "mop_bot_alert",
            "mop_bot_hit",
            "mop_bot_break",
            "boss_tread_rumble",
            "ui_tap",
            "ui_back",
            "publisher_ident_whoosh",
        ):
            self.assertTrue(
                any(s["name"] == required for s in sounds),
                msg=required,
            )


if __name__ == "__main__":
    unittest.main()
