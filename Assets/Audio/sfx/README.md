# The Neon City Bandit — sound-effect pack

Generated with ElevenLabs on Cinder and Crown's account, Nov 15 2026, owned for use in this game.

These clips are original sound effects and short musical stings for the native iOS game **The Neon City Bandit** (steampunk neon raccoon platformer in a neon cyberpunk city). Enemies are MOP janitor robots and the MOP-9000 tank boss. This pack replaces the earlier placeholder README in this folder.

## Rights

All rights reserved, Cinder & Crown LLC, for use in this game. Subject also to ElevenLabs terms of service. **Not CC0.**

## How they were made

- **SFX** (39 clips): ElevenLabs Sound Effects v2 (`eleven_text_to_sound_v2`), one take each.
- **startup_jingle** and **disco_sting**: ElevenLabs Music v2.5 (`eleven_music_v2_5`), instrumental. The startup jingle was generated a second time after the first take dropped its energy after about half a second.
- Style direction: gritty cyberpunk — distorted synth bass, glitchy digital stutters, neon arpeggios, dark punchy edge, and robotic/electric textures on pickups and UI. A light steampunk brass accent is used only in `startup_jingle`.

## Processing

Each file is 44.1 kHz 16-bit PCM WAV (stereo, as generated). Leading/trailing silence was trimmed on one-shots. Looping clips (`shock_aura`, `glide_loop`, `boss_tread_rumble`) were left at their generated length so the seam stays intact. Loudness was normalized to about **−14 LUFS** (UI clicks around **−18 LUFS**), with true-peak limiting.

QA was done without listening: duration, waveform envelope, spectral centroid, clipping and LUFS were checked against each clip's intended use. Flagged issues that were only processing artifacts were fixed in the bounce; only the first `startup_jingle` was clearly mismatched and regenerated (once).

## Looping clips

Play these as seamless loops while the effect is active, then stop or fade them out:

- `shock_aura.wav` — Shock Goggles aura
- `glide_loop.wav` — Turbo Tail glide
- `boss_tread_rumble.wav` — MOP-9000 tread while the boss moves

## File list

See `sfx_manifest.json` for name, file, duration, intended use, and loop flags.
