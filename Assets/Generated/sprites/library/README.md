# Shared sprite library (Higgsfield drop-in)

The playable mascot is the **cyberpunk raccoon bandit** already shipping
(goggles, cyan cables, hoodie with magenta trim). When Nicholas approves the
Higgsfield remake (shared with Trash Stack), drop frames here — no gameplay
rewire needed. Until then, `SpriteCycles` / `ArtLibrary` fall back to
`sprites/spriterrific_ready/`.

## Bandit (shared with Trash Stack)

```
sprites/library/bandit/<action>/01.png … NN.png
sprites/library/bandit/<action>/meta.json   # optional { "fps": 12, "anchor": { "y": 227 } }
```

Required / planned actions:

| Folder | Use |
| --- | --- |
| `idle` | Side idle |
| `idle_front` | Title / menu / hideout |
| `walk` / `run` | Locomotion |
| `jump` | Jump / apex / fall |
| `pounce` (or `attack`) | Pounce / belly-flop commit |
| `hurt` / `death` | Damage |
| `victory` | Clear / results |
| `pick_up` | Loot grab |
| `expr_happy` / `expr_worried` / `expr_smug` | UI / story expressions |

Frame names accepted: `01.png`, `frame_01.png`, or `1.png`.

## NCB-only packs (placeholders until remade)

```
sprites/library/mop_bot/          # basic MOP (falls back to spriterrific)
sprites/library/mop_brute/        # heavy variant
sprites/library/mop_flyer/        # aerial variant
sprites/library/mop_mini_boss/    # level-5 mini-boss
sprites/library/mop_9000_boss/    # finale stub
sprites/library/loot/             # coins / gears / shinies (optional)
sprites/library/hideout/          # upgrade bench props
sprites/library/map/              # city map tiles / pins
sprites/library/story/            # comic panel stills
```

## District parallax

```
backgrounds/districts/<district_id>/{far,mid,near}.png
```

Examples: `neon_docks`, `arcade_row`, … Missing files use the classic
`backgrounds/far_skyline.png` (etc.) pack.
