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

# 04 — Mask Mode while still playing (app holds showcase until smoke_mask_ok.txt)
wait_status "mask" 'import os,sys; s=os.environ["STATUS_LINE"]; sys.exit(0 if ("mask=1" in s and "phase=playing" in s) else 1)' 90
sleep 0.45
shot "$OUT_DIR/04-mask-mode.png"
write_flag "smoke_mask_ok.txt"

# 05 — death / retry overlay (app holds failed until smoke_death_ok.txt)
wait_status "death" 'import os,sys; s=os.environ["STATUS_LINE"]; sys.exit(0 if ("died=1" in s and "phase=failed" in s) else 1)' 90
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

# Palette gate: midrun must contain bright magenta + teal neon (not dim gray placeholders).
python3 - "$OUT_DIR/02-midrun.png" "Assets/Generated/backgrounds/mid_buildings.png" "$OUT_DIR/palette-side-by-side.png" <<'PY'
import sys
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pillow"])
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
echo "Smoke passed (phase=$PHASE stomps=$STOMPS mask=$MASK died=$DIED won=$WON)"
