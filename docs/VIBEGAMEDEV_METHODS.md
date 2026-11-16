# Vibe Game Dev methods — agent brief (Swift / SpriteKit)

Native Swift + SpriteKit + StoreKit 2 only. Do not scaffold Phaser/Three/Capacitor. Imitate this repo's architecture.

**Approvals:** where this brief says “the human” approves (for example the Spriterrific anchor), that human is **Fire Fox**. Report the artifact and wait for Fire Fox’s review. Do **not** block other mission work while waiting.

## Skills and context

- Load relevant skills before coding (repo SpriteKit/project skill if present, plus `spriterrific-api` for character art). A skill is a persistent playbook, not a one-shot prompt.
- Keep a committed asset manifest (atlases, animation names, frame sizes, SFX, BGM). Update it when assets change.

## How to take work

- Write down the one-minute loop first (camera, player verbs, win/lose).
- One system per pass. State the current behavior, the aim, the files touched, and how a human will SEE the difference in the smoke video.
- Each pass must be small enough to throw away. Core feel first, then progression, then come-back hooks.

## Gym, playground, tunability

- Gameplay gym with placeholders until the loop is fun without final art.
- Character gym: idle, run, jump, stomp, Mask, with visible hurt/stomp boxes, each action triggerable in isolation.
- Feel numbers live in JSON/plist (speed, gravity, jump, coyote, stomp, hit-stop, shake). No magic numbers.
- Debug overlay for speeds, hitboxes and audio mute. TestFlight/review builds ship with debug off.
- Measure atlas frame sizes before writing loaders; never guess.

## Art (Spriterrific)

- Check the balance and report expected credits before enqueueing. Anchor first, approved before animations. Stay under the cap. Fix bad timing with the free frame picker, not a re-roll; use variants for outfit/facing; custom moves get a baseline plus `actionContext`.
- Download everything into the repo; the game loads local files only.
- Normalize before wiring in: real alpha, shared scale, shared foot baseline, plus a contact sheet and GIF at game size. Anchors stay neutral (no baked glow or Mask FX). East facing = flip west.

## Juice

- Hit-stop (short on a normal hit, longer on big events), tunable.
- Screen shake from noise or a normal distribution, not raw random.
- Hurt/impact flash is brief, local and on a cooldown. NEVER a full-screen wash.
- Squash/stretch and particles on the beats the player should feel. Graphics without juice are not done.
- Enemies take turns engaging; data-driven encounter config.

## Audio

- Not complete without SFX and music. Offer several BGM candidates switchable in the debug panel. Report the cost before any paid audio credits.

## QA

- After every pass, a continuous deterministic smoke video (seeded RNG, an explicit ready signal instead of sleeps, a meaningful outcome assertion, fail on unexpected logs) plus screenshots. Green CI is not the same as fun.
- Describe bugs by what's visible ("raccoon slides after a stomp"), then fix that.
- No leftover debug strings.

## V2 — Chong-U methods (apply every pass)

- Keep a short GDD and a mobile-aware technical design in `docs/` and update them per pass (`docs/DESIGN.md`, `docs/TECHNICAL_DESIGN.md`).
- Touch controls are placement-insensitive: touch anywhere on the left half and the stick appears there; a slight push walks, a full push runs. Jump / Pounce on the right.
- Fix HUD occlusion: every control stays inside the safe area.
- One gym per system (character, tiles/collision, enemies, background). Stomp/attack hitboxes are live only on the contact frame. Feet sit IN the ground art, not floating.
- Parallax and HUD colors must not compete with the playfield.
- Agent eyes: one pass changes things, then judge the smoke screenshots side by side against the previous build, and iterate until it's clearly better.
- Listen to every SFX; reject harsh or mismatched ones.
- Before release, a short FTUE that teaches move, jump, stomp and Mask in under 30s. Ship a juicy vertical slice; no feature sprawl.

**Spriterrific (this mission):** Fire Fox generates locally. CI spend stays **disabled**. Do not add `Assets/SPRITERRIFIC_REQUEST` or a credit-spend CI job.
