# Shared sprite library (Higgsfield drop-in)

**Official bandit approved** (Nicholas) — cyberpunk raccoon: goggles with cyan
lenses, magenta-trim hoodie, cyan cable backpack. Shared with Trash Stack.

Animated 256×256 sets (bandit, MOP bot, MOP-9000) and 5 story panels ship as
archives. Until they land, `SpriteCycles` / `ArtLibrary` fall back to
`sprites/spriterrific_ready/`.

## Whole-set swap

Prefer dropping a complete set into `sprites/library_sets/<name>/` and pointing
`sprites/active_set.json` at it (see `library_sets/README.md`). Replacing files
in-place under `sprites/library/` also works — call `ArtLibrary.reload()` after.

## Bandit layout

```
<libraryRoot>/bandit/<action>/01.png … NN.png
<libraryRoot>/bandit/<action>/meta.json   # optional { "fps": 12, "anchor": { "y": 227 } }
```

| Folder | Use |
| --- | --- |
| `idle` | Side idle (character-sheet “Side”) |
| `idle_front` | Title / menu / hideout (“Hero Front”) |
| `walk` / `run` | Locomotion |
| `jump` | Jump / apex / fall |
| `pounce` (or `attack`) | Pounce / belly-flop |
| `hurt` / `death` | Damage |
| `victory` | Clear / results |
| `pick_up` | Loot grab |
| `expr_happy` / `expr_cheer` | Grin / cheer |
| `expr_smug` | Smug |
| `expr_determined` | Determined |
| `expr_worried` / `expr_panic` | Worried / panic |
| `expr_game_over` | Game over |

Frame names accepted: `01.png`, `frame_01.png`, or `1.png`.

## NCB packs

```
mop_bot/ mop_brute/ mop_flyer/ mop_mini_boss/ mop_9000_boss/
loot/ hideout/ map/ story/
```

## District parallax / tiles

See `backgrounds/districts/README.md` and `sprites/tiles_district/README.md`.
Heist 1 → downtown, heists 2–3 → docks, finale → factory.
