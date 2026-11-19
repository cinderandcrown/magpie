# Changelog

## Unreleased

### Gameplay
- **Feel pass 2 (post-76646e9):** snappier accel/turn (less robotic), slightly tighter fall, louder jump/land/stomp, harder stomp hit-stop (~65–80 ms) + white flash + zoom punch, speed-scaled camera follow, post-Mask “NOW → EXIT” toast with amplified beacon, mid-surprise earlier (~26 s / tile 28).
- **Punchy juice (feel pass):** every jump / land / stomp / pickup gets hit-stop, harder screen shake, squash-stretch, dust/sparks/impact rings, and SFX. Jump arcs fall faster (less float); coyote 0.12 s + jump buffer 0.14 s kept.
- **First-minute pacing:** objective banner (“STOMP 3 → MASK / race EXIT”), early Mask win toast inside ~20 s, pulsing EXIT beacon, and a mid-docks neon surge that teases the rooftop route.
- **Results reward loop:** score count-up, bigger star slams, a next-star / beat-your-time hint, “GO FOR 3★” / “PLAY AGAIN” button copy, and confetti on a perfect clear.
- **Mask Mode trigger (Nicholas APPROVED 2026-11-17):** ship default is **3 stomps within a 12 s window** (`maskModeAtCombo = 3`, `comboGroundGrace = 12`). Replaces the old 5 stomps / 4.5 s chain window. Mask duration and other combat numbers are unchanged.
- Camera: longer side-switch hold (~0.9 s) and softer facing blend so quick reverses don’t whip framing.

### Art / presentation
- **Living neon city:** twinkling windows, street steam, a slow skyline transit, sweeping searchlight, and denser rain (original procedural FX — see `Assets/LICENSES.md`).
- Storefront neon hangs above the street with real sign crops + pink/cyan rims (no flat hot-pink plates). Title alley uses the same storefront strips instead of solid neon blades.
- Publisher ident: full-screen charcoal Cinder & Crown splash (scene-level, opaque) before title; smoke holds the card long enough for slow CI screenshots (players still see ~2 s).
- Results card uses the run clock (`sim.elapsed`), with OmniClean PA flavor above the buttons.
