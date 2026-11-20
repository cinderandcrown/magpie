# District parallax (Higgsfield drop-in)

Place three plates per art folder:

```
backgrounds/districts/<art_folder>/far.png
backgrounds/districts/<art_folder>/mid.png
backgrounds/districts/<art_folder>/near.png
```

## Art folder → heist mapping (`ArtLibrary.artFolder`)

| Heist / district        | `DistrictID`   | Art folder  |
|-------------------------|----------------|-------------|
| Heist 1 (Neon Docks)    | `neon_docks`   | `downtown`  |
| Heists 2–3              | `arcade_row`, `rooftops` | `docks` |
| MOP-9000 finale         | `sewer_grid`   | `factory`   |

Canonical art folders shipped: `downtown/`, `docks/`, `factory/`.

You may also drop plates under `backgrounds/districts/<district_id>/` —
`ArtLibrary.districtLayer` tries the art folder first, then the raw id.

Far plates are **mirror-tiled** in `HeistScene.buildParallax` so panoramic
seams read clean. Mid/near use a slight overlap.

Until files exist, classic `far_skyline` / `mid_buildings` / `near_rooftops`
are used so the city still reads.

## Matching tiles

```
sprites/tiles_district/<art_folder>/platform.png
sprites/tiles_district/<art_folder>/{crate,ledge,vent,ladder,rooftop}.png
```

`makePlatformTileSet(district:)` prefers `platform.png` for solid fills;
decor props prefer the district pack over Kenney fallbacks.
