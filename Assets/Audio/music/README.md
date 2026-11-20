# The Neon City Bandit — soundtrack pack

Generated with ElevenLabs Music v2.5 (`eleven_music_v2_5`) on Cinder & Crown's account, Sunday November 15, 2026 (America/Chicago, UTC-6). Instrumental only. Original music; not an imitation of any existing song or artist. **Not pushed to the repo** — Nicholas picks the main theme first.

All rights reserved, Cinder & Crown LLC, for use in this game. Also subject to ElevenLabs terms of service. **Not CC0.**

## Plan (from the live design)

Districts come from `docs/DESIGN.md` on branch `cursor/mission-1-raccoon-toy-0c7d`:

> District map — Neon City: districts Docks, Arcade Row, Rooftops, Sewer Grid. Each ~8 short levels + a boss MOP.

Plus a Hideout / Den menu theme and a shared boss theme. Older Glow Market / Spotless Tower names are superseded.

Every track uses the same written signature motif so the pack reads as one soundtrack:

- Key: E minor
- Hook: a rising four-note analog-synth-lead question answered by a sly, syncopated descending four-note smirk
- Family tempo: 120 BPM for the main theme and district loops; 140 BPM for the boss; 90 BPM for the menu
- Production: instrumental synthwave / darksynth, punchy kick, distorted bass, neon arpeggios, light glitchy stutters, occasional muted-brass color (to sit next to the 5.5 s startup jingle)

## Files

Previews are 44.1 kHz MP3 (192 kbps). Game versions are 44.1 kHz AAC `.m4a` (192 kbps), loop-crossfaded and loudness-normalized to about **−16 LUFS** integrated (quieter than the −14 LUFS SFX pack), true-peak limited, no clipping.

| Preview (listen) | Game loop | Role | One-line description | Processed length | LUFS |
| --- | --- | --- | --- | --- | --- |
| `preview/main_theme_v1.mp3` | `game/main_theme_v1.m4a` | Signature theme, take A | Badass, hummable synth-lead hook over a driving 120 BPM cyberpunk groove, with mischievous swagger | 101.0 s | −15.9 |
| `preview/main_theme_v2.mp3` | `game/main_theme_v2.m4a` | Signature theme, take B | Same brief as v1, second generation so Nicholas can pick | 101.0 s | −15.9 |
| `preview/docks_theme.mp3` | `game/docks_theme.m4a` | Neon Docks district | Same motif as a wide industrial waterfront groove: heavier low end, wet delays, muted brass | 92.5 s | −15.9 |
| `preview/arcade_row_theme.mp3` | `game/arcade_row_theme.m4a` | Arcade Row district | Same motif, brighter and more playful: sparkling arpeggios, digital blips, downtown neon swing | 108.5 s | −15.9 |
| `preview/rooftops_theme.mp3` | `game/rooftops_theme.m4a` | Rooftops district | Same motif, open and windswept: airier drums, soaring higher lead, more space | 92.0 s | −15.9 |
| `preview/sewer_grid_theme.mp3` | `game/sewer_grid_theme.m4a` | Sewer Grid district | Same motif, darker and subterranean: muffled kick, growling bass, tense and close | 100.5 s | −15.9 |
| `preview/boss_theme.mp3` | `game/boss_theme.m4a` | MOP-9000 / district boss | Same motif, heavier and faster (140 BPM), stacked leads and industrial hits | 70.0 s | −15.9 |
| `preview/menu_theme.mp3` | `game/menu_theme.m4a` | Hideout / Den / map / menus | Calm 90 BPM lounge arrangement of the same hook: warm pads, mellow lead, soft electric piano | 56.0 s | −15.8 |

Raw ElevenLabs MP3s are in `raw/*_raw.mp3`. Per-track QA numbers are in `qa/*.json`. The processing script is `process_tracks.py`.

## Processing

1. Decode the generated MP3.
2. Trim a trailing fade-out if the tail falls toward silence (rooftops, docks, and shorter fades on arcade / sewer / boss).
3. 4-second circular crossfade so the end flows into the start (output length = trimmed length − 4 s).
4. Two-pass `ffmpeg` `loudnorm` to −16 LUFS, TP −1.5 dBTP, LRA 11.
5. Bounce 44.1 kHz AAC `.m4a` and MP3 preview.

QA was done without listening: duration, waveform energy, mid-track silence, clipping, LUFS, and loop-join sample jump. All eight processed files passed: no clipping, no mid-track silence gaps, LUFS within 0.2 of −16. I cannot confirm by ear that the hook is identical across tracks or that the music is musically great — that is for Nicholas.

## Generations and credits

Eight music generations total (under the ~12 cap). Model: `eleven_music_v2_5`. Flow id: `P2s6HOaaqB7wY49AADAE` (ElevenLabs Creative Studio, “The Neon City Bandit — Soundtrack”). `account_get_usage` could not be checked (needs a `user_read` re-grant); credit amounts below are the per-generation charges returned by the run.

| Track | Generation ID | Song ID | Session ID | Credits | USD |
| --- | --- | --- | --- | --- | --- |
| main_theme_v1 | `krySVJX0wqKBjB35rPuk` | `l1xy0ZCda31sIXI1JCxm` | `VAmL9zlpaYC9kvfqMSUd` | 1,574.65 | $0.29 |
| main_theme_v2 | `92mWgO6XaQF2PYN2QNmW` | `kHijG30x6P9zaRl13TqS` | `B8K5cBIPrESL1HOg0qLk` | 1,574.65 | $0.29 |
| docks_theme | `M7XHbLvT1kJWAshyTaQb` | `JdmTEmfZkcdi0V4gHUmY` | `sdNL9HCYPko8HBiKSkkA` | 1,574.65 | $0.29 |
| arcade_row_theme | `v5uwHgpw75XiNzsc97F5` | `B8s719v0YlGyLNwJgdj0` | `7q1KxlgJYwOEIvWhfuN2` | 1,574.65 | $0.29 |
| rooftops_theme | `2qkl5mswbRlyKub9nxln` | `3QQx2T5p2YHXwu8mcsvS` | `nloWK3AAeyhqXD7m1hla` | 1,574.65 | $0.29 |
| sewer_grid_theme | `7VZ2xRJWc5QGW7ZAi6gO` | `spc7EYZ5dFxnt8Lt12my` | `X5mATnDtwUAAfelUShqt` | 1,574.65 | $0.29 |
| boss_theme | `l1iTL4u4gPfG3iK4H67A` | `GzzavvafexstTEXXM9JL` | `5ZpnGyDp59dQgmAMJ1Ua` | 1,124.75 | $0.20 |
| menu_theme | `mVpvTVeJDZ8A5PjgsaZA` | `yaUxSpymz77qcKXYKH4Y` | `NbNriT2PT5N7Mg9a1yzx` | 899.80 | $0.16 |
| **Total** | 8 generations |  |  | **11,472.45** | **$2.09** |

Requested durations: main and districts 105 s (arcade's model output came back at 114 s; others 105 s). Boss 75 s. Menu 60 s. Processed lengths are shorter because of the 4 s loop crossfade and fade-tail trims.

## Prompts

Shared constraints on every prompt: instrumental, no vocals, original melody only, no fade-out, no silence gaps, end on the same downbeat as the start so the track can loop.

**main_theme (v1 and v2, same prompt, two takes):**
Instrumental synthwave cyberpunk game theme, no vocals. A short, instantly hummable analog-synth lead hook in E minor: a rising four-note question answered by a sly, syncopated descending four-note smirk, repeated until it is a signature motif. Driving mid-tempo groove at 120 BPM with a punchy kick, tight snare, distorted synth bass, glittering sixteenth-note arpeggios, light glitchy digital stutters, and occasional playful muted-brass stabs. Mood is badass with mischievous swagger. Structure: eight-bar intro of bass and arpeggios, hook enters, a verse variation, the hook returns bigger, a short breakdown, final hook, ending on the same downbeat as the start so the track can loop cleanly. Crisp modern production, no fade-out, no silence gaps, original melody only.

**docks_theme:**
Instrumental synthwave cyberpunk game loop, no vocals, in E minor at 120 BPM. Keep the same signature analog-synth lead hook: a rising four-note question answered by a sly, syncopated descending four-note smirk. Arrange it as a wide industrial waterfront groove: heavier low-end, warehouse-like room on the drums, wet delayed synths, a slightly maritime muted-brass color, and rolling toms. Mood is gritty and open, still mischievous. Structure builds and returns to the hook, ending on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

**arcade_row_theme:**
Instrumental synthwave cyberpunk game loop, no vocals, in E minor at 120 BPM. Keep the same signature analog-synth lead hook: a rising four-note question answered by a sly, syncopated descending four-note smirk. Arrange it brighter and more playful: sparkling arpeggios, stuttering digital blips, tight electronic drums, bell-like synth stabs, slightly more swing. Mood is downtown neon nightlife, cocky and fun. Structure builds and returns to the hook, ending on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

**rooftops_theme:**
Instrumental synthwave cyberpunk game loop, no vocals, in E minor at 120 BPM. Keep the same signature analog-synth lead hook: a rising four-note question answered by a sly, syncopated descending four-note smirk. Arrange it open and windswept: airier drums, a soaring higher lead octave, long reverb tails, filter-sweep pads, more space between hits. Mood is high and nocturnal, still badass. Structure builds and returns to the hook, ending on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

**sewer_grid_theme:**
Instrumental synthwave cyberpunk game loop, no vocals, in E minor at 120 BPM. Keep the same signature analog-synth lead hook: a rising four-note question answered by a sly, syncopated descending four-note smirk. Arrange it darker and subterranean: muffled punchy kick, growling distorted bass, closer dry drums, low drones, tense syncopated hats, occasional metallic percussion. Mood is claustrophobic and stealthy, still with mischievous swagger. Structure builds and returns to the hook, ending on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

**boss_theme:**
Instrumental darksynth cyberpunk boss theme, no vocals, in E minor at 140 BPM. Use the same signature analog-synth lead hook, but heavier, faster, and more tense: a rising four-note question answered by a sly, syncopated descending four-note smirk, now played more aggressively with stacked leads and bigger drums. Distorted bass, pounding double-time hats, industrial hits, rising tension risers, short breakdown, then the hook slams back. Mood is dangerous and relentless. End on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

**menu_theme:**
Instrumental calm cyberpunk lounge theme, no vocals, in E minor at 90 BPM. A spacious, gentle arrangement of the same signature analog-synth lead hook: a rising four-note question answered by a sly, syncopated descending four-note smirk, played softly on a warm pad and a clean mellow lead. Slow heartbeat kick, soft electric-piano chords, quiet arpeggios, no aggression. Mood is late-night hideout, relaxed and stylish. End on the same downbeat as the start for a clean loop. No fade-out, no silence gaps, original melody only.

## Track assignment (Nicholas, Nov 15 2026)
- main_theme.m4a (was take v2/B): primary gameplay theme.
- main_theme_alt.m4a (was take v1/A): alternate gameplay track, rotate in so music does not get repetitive.
- docks/arcade_row/rooftops/sewer_grid: per-district tracks. boss_theme: MOP-9000. menu_theme: title/hideout/menus.
