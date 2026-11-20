# Neon Docks — Route Notes

96×24 exploration layout. File row 0 = world top (`TileMap.parse` reverses rows).

## Routes

- **Street (lower):** Main deck with dense MOP packs and a canal death gap.
- **Rooftop (higher):** Climb / ledge path with more shinies and harder jumps; bypasses the canal.
- **Crossings:** Mid bridge over the canal, climb-cap into the high roof run, post-canal drop/tower return.

## Set pieces

- Vertical climb with twin `L` poles + `-` one-way rungs
- Cascading `-` drop-down into the exit pad
- Secrets: crate cluster, water-tower roof shiny, sewer grate crew cage (`R`)
- Exit reachable from street floor and roof drop-down

## Jump budget

`GameFeel.jumpVelocity = 30` → ~2.3 tile full-hold height / ~5 tile run distance; pounce extends. Stepping stones use 1–2 tile rises; taller climbs use wall-latch assists.

## Other districts

Arcade Row, Rooftops, and Sewer Grid currently share the Neon Docks exploration grammar
(street + rooftop routes, secrets, one-ways, crew cage, canal death) so the CI jump-arc
validator stays green. Flavor text differs in `Assets/Story/Story.json`.
