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

    def test_mop_and_boss(self) -> None:
        for action in ("walk", "attack", "hurt", "death"):
            self.assertTrue((READY / "mop_bot" / action / "01.png").is_file())
        for action in ("idle", "walk", "attack", "hurt", "death"):
            self.assertTrue((READY / "mop_9000_boss" / action / "01.png").is_file())

    def test_raw_sheets_present(self) -> None:
        self.assertTrue((RAW / "README.md").is_file())
        self.assertTrue((RAW / "bandit/idle/spritesheet.png").is_file())
        self.assertTrue((RAW / "mop_bot/walk/spritesheet.png").is_file())


if __name__ == "__main__":
    unittest.main()
