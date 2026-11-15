#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Launch Magpie with -SmokeAutoplay, record gameplay, capture moment screenshots
# driven by smoke_status milestones (not blind sleeps), assert avg FPS >= 55.
set -euo pipefail

DEVICE="${1:?simulator UDID}"
APP_PATH="${2:?path to Magpie.app}"
OUT_DIR="${3:-smoke-artifacts}"
BUNDLE_ID="${BUNDLE_ID:-com.cinderandcrown.magpie}"
DISPLAY_ID="${SIMCTL_DISPLAY:-1}"
MIN_FPS="${SMOKE_MIN_FPS:-55}"

mkdir -p "$OUT_DIR"

shot() {
  local out="$1"
  if xcrun simctl io "$DEVICE" screenshot --display="$DISPLAY_ID" "$out" 2>/tmp/sim-shot.err; then
    return 0
  fi
  if grep -qiE 'unrecognized|unknown option|invalid option' /tmp/sim-shot.err 2>/dev/null; then
    xcrun simctl io "$DEVICE" screenshot "$out"
    return 0
  fi
  cat /tmp/sim-shot.err >&2 || true
  xcrun simctl io "$DEVICE" screenshot --display=3 "$out" 2>/dev/null \
    || xcrun simctl io "$DEVICE" screenshot "$out"
}

data_container() {
  xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null || true
}

read_status() {
  local data
  data="$(data_container)"
  if [[ -n "$data" && -f "$data/Documents/smoke_status.txt" ]]; then
    cat "$data/Documents/smoke_status.txt"
  else
    echo ""
  fi
}

status_field() {
  local key="$1"
  echo "$(read_status)" | sed -n "s/.*${key}=\([^ ]*\).*/\1/p" | head -1
}

app_alive() {
  local data status now mtime age
  data="$(data_container)"
  [[ -n "$data" ]] || return 1
  status="$data/Documents/smoke_status.txt"
  [[ -f "$status" ]] || return 1
  now="$(date +%s)"
  mtime="$(stat -f %m "$status" 2>/dev/null || stat -c %Y "$status" 2>/dev/null || echo 0)"
  age=$((now - mtime))
  (( age <= 8 ))
}

require_app() {
  local label="$1"
  if ! app_alive; then
    echo "FAIL: Magpie not alive at $label" >&2
    shot "$OUT_DIR/fail-$label-homescreen.png" || true
    read_status >&2 || true
    exit 1
  fi
  echo "alive@$label: $(read_status)"
}

# Poll until python predicate on status line prints YES, or timeout.
# Predicate receives the status line as sys.argv[1].
wait_status() {
  local label="$1"
  local pypred="$2"
  local timeout="${3:-90}"
  local start now status
  start="$(date +%s)"
  while true; do
    require_app "$label"
    status="$(read_status)"
    if STATUS_LINE="$status" python3 -c "$pypred"; then
      echo "ready@$label: $status"
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      echo "FAIL: timeout waiting for $label (status=$status)" >&2
      shot "$OUT_DIR/fail-$label-timeout.png" || true
      exit 1
    fi
    sleep 0.35
  done
}

echo "Smoke (autoplay) on $DEVICE (display=$DISPLAY_ID)"
# Never keep stale screenshots from a prior CI step/run in this folder.
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

xcrun simctl bootstatus "$DEVICE" -b || xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP_PATH"

docs_dir() {
  local data
  data="$(data_container)"
  if [[ -n "$data" ]]; then
    mkdir -p "$data/Documents"
    echo "$data/Documents"
  fi
}

write_flag() {
  local name="$1"
  local docs
  docs="$(docs_dir)"
  if [[ -z "$docs" ]]; then
    echo "WARN: no Documents dir for flag $name" >&2
    return 1
  fi
  printf 'ok\n' > "$docs/$name"
  echo "flag@$name"
}

launch_smoke() {
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  local docs
  docs="$(docs_dir)"
  if [[ -n "$docs" ]]; then
    rm -f "$docs/smoke_status.txt" \
      "$docs/smoke_proceed.txt" \
      "$docs/smoke_midrun_ok.txt" \
      "$docs/smoke_mask_ok.txt" \
      "$docs/smoke_death_ok.txt"
  fi
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -SmokeAutoplay
}

# Capture 01-title when phase=title AND boot=ready (title chrome on screen).
# Early boot=loading status lets us attach during atlas warm; snap only when ready.
# Relaunch once if we somehow attach after autoplay already advanced.
TITLE_SHOT=0
for attempt in 1 2; do
  launch_smoke
  for _ in $(seq 1 900); do
    status="$(read_status)"
    if [[ -z "$status" ]]; then
      sleep 0.2
      continue
    fi
    if [[ "$status" == *"phase=title"* && "$status" == *"boot=ready"* ]]; then
      require_app "launch"
      # One frame for SpriteKit to present title chrome after boot=ready.
      sleep 0.35
      shot "$OUT_DIR/01-title.png"
      TITLE_SHOT=1
      echo "ready@title: $status"
      # Release the title hold only AFTER the shot returns (screenshot can take >10s).
      write_flag "smoke_proceed.txt"
      break 2
    fi
    if [[ "$status" == *"phase=title"* && "$status" == *"boot=loading"* ]]; then
      # Still warming atlases — keep waiting.
      sleep 0.25
      continue
    fi
    # Attached after autoplay already advanced — relaunch for a clean title beat.
    echo "missed title (status=$status) — relaunch attempt=$attempt" >&2
    break
  done
done
if [[ "$TITLE_SHOT" -eq 0 ]]; then
  echo "FAIL: could not capture phase=title boot=ready after relaunch" >&2
  shot "$OUT_DIR/fail-title-timeout.png" || true
  read_status >&2 || true
  exit 1
fi
require_app "launch"

VIDEO_OUT="$OUT_DIR/smoke-gameplay.mp4"
set +e
xcrun simctl io "$DEVICE" recordVideo --display="$DISPLAY_ID" --codec=h264 --force "$VIDEO_OUT" &
REC_PID=$!
sleep 1
if ! kill -0 "$REC_PID" 2>/dev/null; then
  xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$VIDEO_OUT" &
  REC_PID=$!
fi
set -e

# Harness handshakes: app holds each beat until the matching flag is written after the shot.
# 02 — midrun: running/jumping before MOP hunt (holds until smoke_midrun_ok.txt)
wait_status "midrun" 'import os,re,sys; s=os.environ["STATUS_LINE"]; m=re.search(r"elapsed=([0-9.]+)", s); st=re.search(r"stomps=([0-9]+)", s); d=re.search(r"died=([0-9]+)", s); sys.exit(0 if ("phase=playing" in s and m and float(m.group(1))>=3.0 and (not st or int(st.group(1))==0) and (not d or int(d.group(1))==0)) else 1)' 180
shot "$OUT_DIR/02-midrun.png"
write_flag "smoke_midrun_ok.txt"

# 03 — real MOP stomp
wait_status "stomp" 'import os,re,sys; s=os.environ["STATUS_LINE"]; m=re.search(r"stomps=([0-9]+)", s); sys.exit(0 if m and int(m.group(1))>=1 else 1)' 120
shot "$OUT_DIR/03-mop-stomp.png"

# 04 — Mask Mode while still playing (requires live maskOn=1, not sticky mask=).
# Screenshot can take seconds; re-verify after the shot so 04 never captures SPLASHED.
wait_status "mask" 'import os,sys; s=os.environ["STATUS_LINE"]; sys.exit(0 if ("maskOn=1" in s and "phase=playing" in s) else 1)' 120
MASK_SHOT_OK=0
for _try in $(seq 1 50); do
  status="$(read_status)"
  if [[ "$status" != *"maskOn=1"* || "$status" != *"phase=playing"* ]]; then
    sleep 0.3
    continue
  fi
  sleep 0.35
  shot "$OUT_DIR/04-mask-mode.png"
  status="$(read_status)"
  if [[ "$status" == *"maskOn=1"* && "$status" == *"phase=playing"* ]]; then
    echo "ready@mask-shot: $status"
    MASK_SHOT_OK=1
    break
  fi
  echo "mask shot raced (status=$status) — retry $_try" >&2
  rm -f "$OUT_DIR/04-mask-mode.png"
  sleep 0.25
done
if [[ "$MASK_SHOT_OK" -ne 1 ]]; then
  echo "FAIL: could not capture Mask Mode while phase=playing maskOn=1" >&2
  shot "$OUT_DIR/fail-mask-timeout.png" || true
  read_status >&2 || true
  exit 1
fi
write_flag "smoke_mask_ok.txt"

# 05 — death / retry overlay (app holds failed until smoke_death_ok.txt)
wait_status "death" 'import os,sys; s=os.environ["STATUS_LINE"]; sys.exit(0 if ("died=1" in s and "phase=failed" in s) else 1)' 120
sleep 0.35
shot "$OUT_DIR/05-death-retry.png"
write_flag "smoke_death_ok.txt"

# 06 — RESULTS (win after retry)
wait_status "results" 'import os,sys; s=os.environ["STATUS_LINE"]; sys.exit(0 if ("won=1" in s or "phase=won" in s) else 1)' 120
shot "$OUT_DIR/06-results.png"

kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
sleep 2
require_app "end"

STATUS="$(read_status)"
echo "smoke_status: $STATUS"
FPS="$(echo "$STATUS" | sed -n 's/.*fps=\([0-9.][0-9.]*\).*/\1/p' | head -1)"
if [[ -z "$FPS" ]]; then
  echo "FAIL: missing fps in smoke_status.txt" >&2
  exit 1
fi
python3 - "$FPS" "$MIN_FPS" <<'PY'
import sys
fps=float(sys.argv[1]); need=float(sys.argv[2])
if fps < need:
    raise SystemExit(f"FAIL: average FPS {fps:.1f} < {need:.0f}")
print(f"OK FPS {fps:.1f} >= {need:.0f}")
PY

# simctl recordVideo is video-only — mux level music + hero SFX from the smoke audio timeline.
AUDIO_DIR="Assets/Generated/audio"
EVENTS_SRC="$(data_container)/Documents/smoke_audio_events.txt"
EVENTS_COPY="$OUT_DIR/smoke_audio_events.txt"
if [[ -f "$EVENTS_SRC" ]]; then
  cp "$EVENTS_SRC" "$EVENTS_COPY"
else
  echo "WARN: missing smoke_audio_events.txt — muxing music bed only" >&2
  : > "$EVENTS_COPY"
fi
python3 - "$VIDEO_OUT" "$AUDIO_DIR" "$EVENTS_COPY" <<'PY'
import os, subprocess, sys, tempfile

video, audio_dir, events_path = sys.argv[1:4]
probe = subprocess.check_output(
    ["ffprobe", "-v", "error", "-show_entries", "format=duration",
     "-of", "default=noprint_wrappers=1:nokey=1", video],
    text=True,
).strip()
dur = float(probe)
if dur < 1:
    raise SystemExit(f"FAIL: video duration {dur} too short for audio mux")

def find_clip(stem: str):
    for ext in (".wav", ".caf", ".m4a", ".mp3"):
        p = os.path.join(audio_dir, stem + ext)
        if os.path.isfile(p):
            return p
    return None

music = find_clip("level_loop")
if not music:
    raise SystemExit("FAIL: missing Assets/Generated/audio/level_loop.* for mux")

# Parse timeline: "<sec> sfx <key>" / "<sec> music <name>"
sfx_map = {
    "mop_hit": "mop_hit",
    "mask_mode_on": "mask_mode_on",
    "player_hit": "player_hit",
    "fail": "fail",
    "win": "win",
    "ui_tap": "ui_tap",
}
events = []
with open(events_path, encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 3 and parts[1] == "sfx":
            t = float(parts[0])
            key = parts[2]
            stem = sfx_map.get(key, key)
            clip = find_clip(stem)
            if clip and 0 <= t < dur:
                events.append((t, clip))

# Cap overlays so filter graphs stay small on CI.
events = events[:24]

inputs = ["-y", "-i", video, "-stream_loop", "-1", "-i", music]
filter_parts = [
    f"[1:a]volume=0.45,atrim=0:{dur:.3f},asetpts=PTS-STARTPTS,aformat=sample_fmts=fltp:channel_layouts=stereo[bed]"
]
amix_inputs = ["[bed]"]
idx = 2
for t, clip in events:
    inputs += ["-i", clip]
    # adelay wants milliseconds per channel
    ms = int(t * 1000)
    filter_parts.append(
        f"[{idx}:a]volume=0.85,aformat=sample_fmts=fltp:channel_layouts=stereo,"
        f"adelay={ms}|{ms},apad=whole_dur={dur:.3f},atrim=0:{dur:.3f},asetpts=PTS-STARTPTS[s{idx}]"
    )
    amix_inputs.append(f"[s{idx}]")
    idx += 1

n = len(amix_inputs)
filter_parts.append(
    f"{''.join(amix_inputs)}amix=inputs={n}:duration=first:dropout_transition=0:normalize=0[aout]"
)
fc = ";".join(filter_parts)

muxed = video + ".mux.mp4"
cmd = [
    "ffmpeg", *inputs,
    "-filter_complex", fc,
    "-map", "0:v:0", "-map", "[aout]",
    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
    "-shortest", "-movflags", "+faststart",
    muxed,
]
print("mux audio:", " ".join(cmd[:8]), "…", f"sfx={len(events)} dur={dur:.1f}s")
subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
os.replace(muxed, video)

# Assert an audible audio stream exists.
streams = subprocess.check_output(
    ["ffprobe", "-v", "error", "-select_streams", "a",
     "-show_entries", "stream=codec_type", "-of", "csv=p=0", video],
    text=True,
).strip()
if "audio" not in streams:
    raise SystemExit("FAIL: smoke-gameplay.mp4 missing audio stream after mux")

# Spot-check energy over the first 40s.
wav = tempfile.mktemp(suffix=".wav")
subprocess.check_call(
    ["ffmpeg", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "16000", "-t", "40", wav],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
)
import wave, struct
with wave.open(wav, "rb") as w:
    raw = w.readframes(w.getnframes())
    samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
os.unlink(wav)
if not samples:
    raise SystemExit("FAIL: muxed audio decoded empty")
rms = (sum(x * x for x in samples) / len(samples)) ** 0.5
print(f"OK audio mux rms={rms:.1f} sfx_events={len(events)}")
if rms < 40:
    raise SystemExit(f"FAIL: muxed audio too quiet (rms={rms:.1f})")
PY

# Palette gate: midrun must contain bright magenta + teal neon (not dim gray placeholders).
# Homebrew Python is PEP 668 externally-managed — prefer a throwaway venv for Pillow.
PALETTE_PY=""
PALETTE_VENV="${TMPDIR:-/tmp}/magpie-smoke-palette-venv"
if python3 -c 'import PIL' 2>/dev/null; then
  PALETTE_PY="$(command -v python3)"
elif [[ -x "$PALETTE_VENV/bin/python" ]] && "$PALETTE_VENV/bin/python" -c 'import PIL' 2>/dev/null; then
  PALETTE_PY="$PALETTE_VENV/bin/python"
else
  if python3 -m venv "$PALETTE_VENV" 2>/tmp/magpie-venv.err; then
    "$PALETTE_VENV/bin/pip" install -q pillow
    PALETTE_PY="$PALETTE_VENV/bin/python"
  else
    # Last resort on locked-down runners.
    python3 -m pip install -q --user --break-system-packages pillow
    PALETTE_PY="$(command -v python3)"
  fi
fi
"$PALETTE_PY" - "$OUT_DIR/02-midrun.png" "Assets/Generated/backgrounds/mid_buildings.png" "$OUT_DIR/palette-side-by-side.png" <<'PY'
import sys
from PIL import Image

midrun = Image.open(sys.argv[1]).convert("RGB")
ref = Image.open(sys.argv[2]).convert("RGB")
# Sample center crop of gameplay (skip HUD/controls)
w, h = midrun.size
crop = midrun.crop((int(w*0.1), int(h*0.18), int(w*0.9), int(h*0.62)))
pixels = list(crop.getdata())
n = len(pixels)
# Magenta-ish and teal-ish counts (bright neon, not dim)
mag = sum(1 for r,g,b in pixels if r > 160 and b > 100 and r > g + 30)
teal = sum(1 for r,g,b in pixels if b > 140 and g > 120 and b > r + 20)
bright = sum(1 for r,g,b in pixels if (r+g+b)/3 > 70)
print(f"palette midrun magenta={mag/n:.3%} teal={teal/n:.3%} bright={bright/n:.3%}")
if mag / n < 0.004 and teal / n < 0.004:
    raise SystemExit("FAIL: midrun lacks bright magenta/teal neon (looks like flat placeholders)")
if bright / n < 0.08:
    raise SystemExit("FAIL: midrun too dim vs Game Plan bright-neon-on-dark")

# Side-by-side vs mid_buildings reference strip
rw, rh = 480, 270
left = crop.resize((rw, rh))
right = ref.resize((rw, rh))
board = Image.new("RGB", (rw * 2 + 16, rh + 40), (12, 8, 28))
board.paste(left, (0, 32))
board.paste(right, (rw + 16, 32))
board.save(sys.argv[3])
print(f"OK wrote {sys.argv[3]}")
PY

rm -f "$OUT_DIR/smoke-30s.mp4"
cp -f "$OUT_DIR/01-title.png" "$OUT_DIR/01-launch.png"
cp -f "$OUT_DIR/02-midrun.png" "$OUT_DIR/02-mid.png"
cp -f "$OUT_DIR/06-results.png" "$OUT_DIR/03-end.png"

REQUIRED=(
  01-title.png
  02-midrun.png
  03-mop-stomp.png
  04-mask-mode.png
  05-death-retry.png
  06-results.png
  smoke-gameplay.mp4
  palette-side-by-side.png
  01-launch.png
  02-mid.png
  03-end.png
)
for f in "${REQUIRED[@]}"; do
  path="$OUT_DIR/$f"
  if [[ ! -s "$path" ]]; then
    echo "Missing or empty smoke artifact: $path" >&2
    ls -la "$OUT_DIR" >&2 || true
    exit 1
  fi
  echo "OK $path ($(wc -c < "$path") bytes)"
done

PHASE="$(status_field phase)"
STOMPS="$(status_field stomps)"; STOMPS="${STOMPS:-0}"
MASK="$(status_field mask)"; MASK="${MASK:-0}"
DIED="$(status_field died)"; DIED="${DIED:-0}"
WON="$(status_field won)"; WON="${WON:-0}"
if [[ "$PHASE" == "title" ]]; then
  echo "FAIL: still on title" >&2
  exit 1
fi
if (( STOMPS < 1 || MASK < 1 || DIED < 1 || WON < 1 )); then
  echo "FAIL: milestones stomps=$STOMPS mask=$MASK died=$DIED won=$WON" >&2
  exit 1
fi

# 04 must be Mask Mode gameplay, not the death/results card — assert it differs from 05.
"$PALETTE_PY" - "$OUT_DIR/04-mask-mode.png" "$OUT_DIR/05-death-retry.png" <<'PY'
import sys
from PIL import Image, ImageChops

a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    b = b.resize(a.size)
# Center crop (ignore tiny HUD jitter)
w, h = a.size
box = (int(w * 0.12), int(h * 0.18), int(w * 0.88), int(h * 0.82))
a, b = a.crop(box), b.crop(box)
diff = ImageChops.difference(a, b)
pixels = list(diff.getdata())
n = max(1, len(pixels))
avg = sum(sum(p) for p in pixels) / (n * 3 * 255.0)
print(f"mask-vs-death diff={avg:.4f}")
if avg < 0.035:
    raise SystemExit("FAIL: 04-mask-mode too similar to 05-death-retry (Mask beat captured death card?)")
# Death card is typically much darker / more UI plate — Mask should still have bright neon playfield.
bright = sum(1 for r, g, b in a.getdata() if (r + g + b) / 3 > 55) / n
print(f"mask-shot bright={bright:.3%}")
if bright < 0.05:
    raise SystemExit("FAIL: 04-mask-mode too dim (looks like dimmed death overlay)")
print("OK 04 differs from 05")
PY

echo "Smoke passed (phase=$PHASE stomps=$STOMPS mask=$MASK died=$DIED won=$WON)"
