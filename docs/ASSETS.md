# Asset contract (Mission 1)

Fire Fox lands production art/audio on branch `assets/mission-1` under `Assets/Generated/` with this doc.

Until that branch is merged into PR #3, the game uses **placeholders** (procedural SpriteKit art + synthesized SFX/music) resolved through `AssetManifest` / `AssetKey`.

## Swap rule

1. Merge `assets/mission-1` into the Mission 1 PR branch.
2. Ensure files live at `Assets/Generated/<key>.<ext>` (or are copied into the app bundle under `Generated/`).
3. No gameplay code changes required if keys match.

## Keys

### Bandit frames
| Key | File hint |
| --- | --- |
| `raccoon_idle_0` | idle |
| `raccoon_run_0`, `raccoon_run_1` | run cycle |
| `raccoon_jump_0` | jump |
| `raccoon_fall_0` | fall |
| `raccoon_pounce_0` | pounce / flop |

### Enemies / pickups
| Key | File hint |
| --- | --- |
| `mop_idle_0`, `mop_patrol_0` | MOP robot |
| `shiny_0` | Shinies |

### World / UI
| Key | File hint |
| --- | --- |
| `parallax_sky`, `parallax_skyline`, `parallax_signs`, `rain` | layers |
| `tile_ground`, `tile_wall` | tiles |
| `logo` | title mark |

### SFX (wav/m4a/mp3)
`jump` · `land` · `collect_shiny` · `pounce` · `hit` · `win` · `fail` · `mask_mode`

### Music
`heist_loop` (looping)

## Code entry points

- `AssetKey` / `AssetManifest` — `Packages/GameRender/.../AssetManifest.swift`
- Textures — `ArtCatalog.texture(for:)`
- Audio — `JuiceSound.play(_:)` / `startMusic()`
