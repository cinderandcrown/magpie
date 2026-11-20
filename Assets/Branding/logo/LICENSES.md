# The Neon City Bandit, round 2 (B1 / B2 / B3): licensing

All artwork in this folder is **original, code-generated art**. That covers the logos, compact lockups, app icons, mockups and comparison sheet.
- It was built with Python: shapely geometry produces the SVG, resvg renders it, and Pillow composites the mockups, adds film grain and lays out the sheet.
- The build scripts are in `src/`.
- **No AI image generators, stock images, clip art, textures or third-party graphics were used.**
- Glow, noise, scanlines, brushed metal, bricks, rain, the alley, signs and the raccoon emblem are all procedural: SVG `feGaussianBlur` and `feTurbulence`, plus hand-placed polygons.

## Letterforms

- **"BANDIT"** is not set in any font. All six letters (B, A, N, D, I, T) are original polygon letterforms drawn in `src/glyphs.py`. That includes the chamfers, cuts, notches, the speed slit and the blade on the T.
- **Raccoon-bandit emblem:** an original geometric drawing in `src/glyphs.py` (`emblem()`).
- **Secondary text** uses outlines from one SIL OFL font, converted to vector paths:
  - "THE NEON CITY"
  - the "SIGNAL LOST" tape
  - the mockup UI words (TAP TO START, SETTINGS, LEADERBOARD, BAR, HOTEL)
  - the sheet labels

| Font | Used for | Copyright | License | License file |
|---|---|---|---|---|
| Orbitron (variable, instanced at wght 400–900) | Secondary text only, as above | Copyright 2018 The Orbitron Project Authors (github.com/theleagueof/orbitron), Reserved Font Name "Orbitron" | SIL Open Font License 1.1 | `fonts/OFL_orbitron.txt` (also `../fonts/`) |

- The SVGs contain **no `<text>` elements, no font references and no embedded fonts or images**. They are paths, gradients and filters only.
- The SIL OFL 1.1 permits using the font to make commercial artwork such as logos, app icons and store graphics. Its restrictions apply only to redistributing or selling the font software itself.
