# Changelog

## Unreleased

### Gameplay
- **Art library slots:** `ArtLibrary` + `sprites/library/` drop-in for the shared Higgsfield raccoon (Trash Stack) and NCB packs (MOP variants, bosses, loot, hideout, map, story). District parallax reads `backgrounds/districts/<id>/{far,mid,near}.png` with skyline fallbacks. Placeholders until Nicholas approves the remake.
- **Higgsfield juice (feel loop):** JUMP/POUNCE icons on the face buttons (same big hit pads + press squash); stomp-burst + mop-death on kills; foot-dust on jump/land; pickup-glow loop on shinies. FX are short one-shots, warmed at scene start. Jump buffer tuned to ~120 ms; play toasts sit at the top so they never cover the raccoon. Idle breathe + clearer stick.
- **Feedback-5 fixes (Nicholas iPhone):** JUMP/POUNCE hit boxes now match the drawn buttons (+ pad); move zone no longer steals right-side taps; debug touch overlay via `-ShowTouchZones`. Pounce/drop-through and ledge falls onto MOPs always stomp (land grace + invuln while diving). MASK MODE banner moved to the top, smaller, clear of +N popups.
- **Phone feel (Nicholas):** thumb-sized JUMP/POUNCE (112 pt) + huge invisible hit zones (left ~38% move, right ~40% jump/pounce), multitouch on, press squash + haptic; coyote 100 ms / jump buffer 120 ms; stomp box 2.0× sprite wide with fall magnet + land-frame stomps; easy opening MOP pack + street shinies; combo shows from x1.
- **Feel pass 3 (post-daaed6f):** MOPs no longer stack into one white blob (wider patrol + de-clump + gentle seek); walk/run reads on screen (faster sheets, lean, foot dust); quiet stretches get a “POUNCE A MOP!” nudge.
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
