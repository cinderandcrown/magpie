# District parallax (Higgsfield drop-in)

Place three plates per district:

```
backgrounds/districts/<district_id>/far.png
backgrounds/districts/<district_id>/mid.png
backgrounds/districts/<district_id>/near.png
```

`district_id` matches `DistrictID.rawValue` (e.g. `neon_docks`, `arcade_row`).

Until files exist, `ArtLibrary.districtLayer` uses the classic
`far_skyline` / `mid_buildings` / `near_rooftops` pack so the city still reads.
