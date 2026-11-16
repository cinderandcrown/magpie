# Spriterrific sprite sheets (The Neon City Bandit)

Generated Nov 15 2026 on Cinder and Crown's Spriterrific account (cinderandcrown@gmail.com) from original text prompts.
No third-party character art was used as input. Owned by Cinder and Crown LLC for use in this game.

Each `<character>/<action>/` holds `spritesheet.png` (256x256 frames, grid per `manifest.json`: columns, rows, frames, fps, anchor at bottom-center x128,y255) and `frames-index.json`. All side-view sheets face WEST (left); flip xScale for right.

| Character | Actions | Notes |
|---|---|---|
| bandit (steampunk neon raccoon) | run, walk, jump, attack (= stomp/pounce), idle, hurt, death (= knocked out), pick_up (grab loot), disco_dance (easter egg) | `anchor-s.png` + `idle_front/` = front-facing view and idle for menus/Hideout |
| mop_bot (enemy) | walk, attack, hurt, death (= broken) | |
| mop_9000_boss | idle, walk, attack, hurt, death | `tread_roll/` replaces `walk` for movement (treads churn); keep the code tread scroll as polish if it helps |

Spriterrific job ids: bandit anchor kh7a9s8ajz6z449kpd1f0g67kd8ja53s, front anchor kh79w9y4hdx8v276ssh4ap2tmh8jbd6j, mop_bot kh7feaba60taq5mxyby324vb1d8jbn7g, boss kh7bhpgdh7xmesrm223krqc0658ja9k6.
