# Spriterrific sheets (Fire Fox — local)

CI does **not** spend Spriterrific credits. Do not add `Assets/SPRITERRIFIC_REQUEST`.

Sheets live at `Assets/Generated/sprites/spriterrific/` (see README there). Normalized frames:
`Assets/Generated/sprites/spriterrific_ready/` via `scripts/normalize_spriterrific_sheets.py`.
Wired through `SpriteCycles` → `BanditVisual` / `MopVisual` / `BossVisual`. Side views face WEST (flip for right). Foot baseline shared per character. Boss tread scrolls in code until `tread_roll` arrives.

| Field | Value |
| --- | --- |
| Bandit variant | `kh7a9s8ajz6z449kpd1f0g67kd8ja53s` (steampunk-neon) |
| Bandit front anchor | `kh79w9y4hdx8v276ssh4ap2tmh8jbd6j` (`anchor-s.png` for menu/Hideout) |
| MOP bot | `kh7feaba60taq5mxyby324vb1d8jbn7g` |
| MOP-9000 boss | `kh7bhpgdh7xmesrm223krqc0658ja9k6` |
| Earlier text anchor | `kh73s9m80tz14zdr7n3gp16d358jakpv` |
| Status | Sheets handed off; wired in-game. `idle_front` → title/menu; boss move = `tread_roll`. `disco_dance` kept for backlog easter egg. |
