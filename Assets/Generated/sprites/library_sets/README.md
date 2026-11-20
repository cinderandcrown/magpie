# Library sets (whole-folder swap)

Drop a complete animated sprite archive here, then activate it.

```
sprites/library_sets/<set_name>/
  bandit/<action>/01.png … NN.png
  mop_bot/<action>/01.png …
  mop_9000_boss/<action>/01.png …
  index.json   # optional foot_y per character
```

Activate without a code change — edit `sprites/active_set.json`:

```json
{ "root": "sprites/library_sets/<set_name>" }
```

Or at runtime: `ArtLibrary.activateSet("sprites/library_sets/<set_name>")`.

Expected actions match `sprites/library/README.md` (idle, walk, run, jump,
pounce, hurt, death, victory, pick_up, expr_*). Frame size: **256×256**.

Nicholas approved the official bandit character sheet (hero / side / pounce /
victory + expression heads). Incoming archives replace this set in one drop.
